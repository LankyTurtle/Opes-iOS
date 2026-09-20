import Foundation

@main
enum TransactionTests {
    struct Failure: Error { let message: String }
    static var checks = 0

    static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw Failure(message: message) }
        self.checks += 1
    }

    static func rejects(_ message: String, _ operation: () throws -> Void) throws {
        do {
            try operation()
        } catch {
            self.checks += 1
            return
        }
        throw Failure(message: message)
    }

    static func parse(_ csv: String) throws -> [Transaction] {
        try TransactionCSVParser.parse(Data(csv.utf8), institution: "Test Bank")
    }

    static func main() throws {
        let au = Locale(identifier: "en_AU")
        try self.expect(TransactionAmount.parse("12.34", locale: au) == Decimal(string: "12.34"), "Manual cents remain exact")
        try self.expect(TransactionAmount.parse(" 12.34 ", locale: au) != nil, "Manual whitespace")
        try self.expect(TransactionAmount.parse("12,34", locale: Locale(identifier: "de_DE")) == Decimal(string: "12.34"), "Locale decimal separator")
        for text in ["", "0", "-1", "12abc", "1.234", "1,23", "1e3", "NaN", String(repeating: "9", count: 40)] {
            try self.expect(TransactionAmount.parse(text, locale: au) == nil, "Reject manual amount: \(text)")
        }

        let signed = try self.parse("\u{FEFF}Date,Description,Amount\r\n20/09/2026,Groceries,-12.34\r\n2026-09-19,Salary,100.00\r\n")
        try self.expect(signed.count == 2 && signed[0].amount == Decimal(string: "-12.34"), "BOM, CRLF, signed amounts")
        try self.expect(signed[1].isMoneyIn, "Positive amount direction")
        try self.expect(signed[0].sourceInstitution == "Test Bank" && signed[0].accountID == nil, "Institution retained without guessing an account")
        let quoted = try self.parse("Date,Description,Amount\n20/09/2026,\"Cafe, \"\"Main\"\"\nStreet\",\"-1,234.56\"")
        try self.expect(quoted[0].merchant == "Cafe, \"Main\"\nStreet", "Quoted comma, escaped quotes, embedded newline")
        try self.expect(quoted[0].amount == Decimal(string: "-1234.56"), "Grouped amounts")
        let separate = try self.parse("Transaction Date,Details,Debit,Credit\n20/09/2026,Shop,12.34,\n20/09/2026,Pay,,100\n")
        try self.expect(separate.map(\.amount) == [Decimal(string: "-12.34")!, 100], "Debit and credit direction")
        let currency = try self.parse("Date,Merchant,Amount\n20/09/2026,Refund,$20.00\n20/09/2026,Shop,(12.34)")
        try self.expect(currency.map(\.amount) == [20, Decimal(string: "-12.34")!], "Currency and accounting negative")
        let utf16 = "Date,Description,Amount\n20/09/2026,Shop,-1".data(using: .utf16)!
        try self.expect(try TransactionCSVParser.parse(utf16, institution: "Bank").count == 1, "UTF-16 BOM")
        try self.expect(try self.parse("\nDate,Description,Amount\n\n20/09/2026,Shop,-1\n\n").count == 1, "Blank lines")

        for csv in [
            "", "Date,Description,Amount", "Date,Amount\n20/09/2026,1",
            "Date,Description,Amount\n31/02/2026,Shop,-1",
            "Date,Description,Amount\n09/20/2026,Shop,-1",
            "Date,Description,Amount\n20/09/2026,Shop,-1abc",
            "Date,Description,Amount\n20/09/2026,Shop,\"1,23\"",
            "Date,Description,Amount\n20/09/2026,Shop,1.234",
            "Date,Description,Amount\n20/09/2026,Shop,0",
            "Date,Description,Amount\n20/09/2026,,-1",
            "Date,Description,Amount\n20/09/2026,Shop,-1,extra",
            "Date,Description,Amount\n20/09/2026,\"Shop,-1",
            "Date,Description,Amount\n20/09/2026,\"Shop\"oops,-1",
            "Date,Description,Amount\n20/09/2026,Sh\"op,-1",
            "Date,Description,Debit,Credit\n20/09/2026,Shop,1,2",
            "Date,Description,Debit,Credit\n20/09/2026,Shop,-1,",
            "Date,Description,Amount,Debit,Credit\n20/09/2026,Shop,1,,1",
            "Date,Description,Merchant,Amount\n20/09/2026,Shop,Shop,1",
            "Date,Description,Amount\n20/09/2026,Shop,1\ninvalid,row,here",
        ] {
            try self.rejects("Reject malformed/ambiguous CSV") { _ = try self.parse(csv) }
        }
        try self.rejects("Reject oversized data") {
            _ = try TransactionCSVParser.parse(Data(repeating: 65, count: TransactionCSVAttachment.maximumFileSize + 1), institution: "Bank")
        }
        try self.rejects("Reject too many rows") {
            _ = try self.parse("Date,Description,Amount\n" + String(repeating: "20/09/2026,Shop,-1\n", count: 20_001))
        }
        try self.rejects("Reject invalid encoding") {
            _ = try TransactionCSVParser.parse(Data([0xFF, 0x00, 0xFF]), institution: "Bank")
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("statement.CSV")
        let bytes = Data("Date,Description,Amount\n20/09/2026,Shop,-1".utf8)
        try bytes.write(to: file)
        try self.expect(try TransactionCSVAttachment.readFile(at: file) == bytes, "Read uppercase extension")
        let empty = directory.appendingPathComponent("empty.csv")
        try Data().write(to: empty)
        try self.rejects("Reject empty file") { _ = try TransactionCSVAttachment.readFile(at: empty) }
        try self.rejects("Reject other file type") { _ = try TransactionCSVAttachment.readFile(at: directory.appendingPathComponent("file.txt")) }
        let huge = directory.appendingPathComponent("large.csv")
        try Data(repeating: 65, count: TransactionCSVAttachment.maximumFileSize + 1).write(to: huge)
        try self.rejects("Bound file reads") { _ = try TransactionCSVAttachment.readFile(at: huge) }

        let suite = "TransactionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        struct EmptyProvider: TransactionProviding {
            func transactions() -> [Transaction] { [] }
        }
        let store = TransactionStore(defaults: defaults, sampleProvider: EmptyProvider())
        try store.save(signed)
        let reloaded = TransactionStore(defaults: defaults, sampleProvider: EmptyProvider())
        try self.expect(reloaded.transactions() == signed.sorted { $0.date > $1.date }, "Transactions persist with institution and decimal amounts")
        try store.save(signed[0])
        try self.expect(store.transactions().count == 2, "Saving same transaction is an upsert")
        defaults.set(Data("broken".utf8), forKey: "manualTransactions.v1")
        try self.rejects("Do not overwrite corrupted history") { try store.save(signed[0]) }
        try self.expect(defaults.data(forKey: "manualTransactions.v1") == Data("broken".utf8), "Corrupt history remains available for recovery")
        print("Passed \(self.checks) transaction checks.")
    }
}
