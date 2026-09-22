import Foundation

@main
enum TransactionTests {
    struct Failure: Error { let message: String }
    static var checks = 0
    static let accountID = UUID()

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
        try TransactionCSVParser.parse(Data(csv.utf8), accountID: self.accountID, institution: "Test Bank")
    }

    static func accountFilterChecks() throws {
        var filter = AccountFilter()
        try self.expect(!filter.isActive && filter.matches(type: .homeLoan, institution: "Any"), "Empty filter shows every account")
        filter.toggle(.transaction)
        try self.expect(filter.matches(type: .transaction, institution: "ANZ") && !filter.matches(type: .savings, institution: "ANZ"), "Filter by type")
        filter.toggle(.savings)
        try self.expect(filter.matches(type: .savings, institution: "ANZ") && !filter.matches(type: .creditCard, institution: "ANZ"), "Types within the filter widen the match")
        filter.toggle(institution: "Macquarie")
        try self.expect(filter.matches(type: .transaction, institution: " macquarie "), "Institutions match regardless of case and spacing")
        try self.expect(!filter.matches(type: .transaction, institution: "ANZ"), "Type and institution narrow together")
        try self.expect(!filter.matches(type: .creditCard, institution: "Macquarie"), "Institution alone is not enough when a type is chosen")
        filter.toggle(institution: "ANZ")
        try self.expect(filter.matches(type: .savings, institution: "ANZ") && filter.contains(institution: "anz"), "Institutions within the filter widen the match")
        filter.toggle(institution: "MACQUARIE")
        try self.expect(!filter.contains(institution: "Macquarie") && filter.isActive, "Toggling a chosen institution removes it")
        filter.removeUnavailable(types: [.transaction], institutions: ["Westpac"])
        try self.expect(filter.types == [.transaction] && filter.institutions.isEmpty, "Choices no account has are dropped")
        filter.toggle(.transaction)
        try self.expect(!filter.isActive, "Toggling every choice off clears the filter")
    }

    static func bsbInputChecks() throws {
        func edit(_ text: String, _ location: Int, _ length: Int, _ replacement: String) -> (text: String, cursor: Int) {
            BSBInput.edit(text, range: NSRange(location: location, length: length), replacement: replacement)
        }
        var typed = ""
        var steps: [String] = []
        for digit in "062000" {
            typed = edit(typed, (typed as NSString).length, 0, String(digit)).text
            steps.append(typed)
        }
        try self.expect(steps == ["0", "06", "062", "062-0", "062-00", "062-000"], "Hyphen appears with the fourth digit")
        try self.expect(edit("062-000", 7, 0, "1") == ("062-000", 7), "Stop at six digits")
        try self.expect(edit("06", 2, 0, "a") == ("06", 2), "Ignore non-digits")
        try self.expect(edit("062-0", 4, 1, "") == ("062", 3), "Deleting the fourth digit removes the hyphen")
        try self.expect(edit("062-000", 3, 1, "") == ("060-00", 2), "Backspacing the hyphen deletes the digit before it")
        try self.expect(edit("", 0, 0, "062 000") == ("062-000", 7), "Pasted BSB is reformatted")
        try self.expect(edit("062-000", 1, 0, "9") == ("096-200", 2), "Caret stays after a digit inserted mid-way")
        try self.expect(edit("062-000", 3, 0, "9") == ("062-900", 5), "Caret moves past the hyphen after the fourth digit")
    }

    static func summaryChecks() throws {
        let original = Transaction(id: UUID(), description: "WOOLWORTHS 1234 SYDNEY", date: .now, amount: -5, accountID: UUID(), reference: "R1")
        try self.expect(original.summary == "WOOLWORTHS 1234 SYDNEY", "Summary defaults to the description")
        let summarised = original.withSummary("  Groceries ")
        try self.expect(summarised.summary == "Groceries" && summarised.description == original.description, "Summarising keeps the description")
        try self.expect(summarised.withSummary(" ").customSummary == nil, "A blank summary goes back to the description")
        try self.expect(summarised.withSummary(original.description).customSummary == nil, "Repeating the description stores no summary")
        let decoded = try JSONDecoder().decode(Transaction.self, from: JSONEncoder().encode(summarised))
        try self.expect(decoded == summarised, "Summary, reference, and time flag persist")
        try self.rejects("Reject v1 history without the renamed fields") {
            _ = try JSONDecoder().decode(Transaction.self, from: Data(#"{"id":"\#(UUID())","merchant":"Shop","date":0,"amount":-1}"#.utf8))
        }

        let referenced = try self.parse("Date,Description,Reference,Amount\n20/09/2026,Shop, REF123 ,-1\n20/09/2026,Pay,,100")
        try self.expect(referenced.map(\.reference) == ["REF123", nil], "CSV reference is trimmed and optional per row")
        try self.expect(try self.parse("Date,Description,Amount\n20/09/2026,Shop,-1")[0].reference == nil, "CSV without a reference column")
        try self.rejects("Reject ambiguous reference columns") { _ = try self.parse("Date,Description,Ref,Reference,Amount\n20/09/2026,Shop,1,2,-1") }
    }

    static func occurrenceChecks() throws {
        let au = Locale(identifier: "en_AU")
        let sydney = TimeZone(identifier: "Australia/Sydney")!
        let imported = try self.parse("Date,Description,Amount\n20/09/2026,Shop,-1")[0]
        try self.expect(!imported.hasTime, "CSV dates carry no time")
        try self.expect(imported.formattedOccurrence(locale: au) == "Sun 20 Sep 2026", "Date-only transactions show just the day")
        try self.expect(imported.directionDescription == "Debit", "Money out is a debit")
        var components = DateComponents(year: 2026, month: 9, day: 5, hour: 15, minute: 45)
        components.timeZone = sydney
        let manual = Transaction(id: UUID(), description: "Pay", date: Calendar(identifier: .gregorian).date(from: components)!, amount: 10, accountID: UUID())
        let occurrence = manual.formattedOccurrence(locale: au, timeZone: sydney)
        try self.expect(manual.hasTime && occurrence.hasPrefix("Sat 05 Sep 2026, 3:45"), "Manual transactions show the day and time: \(occurrence)")
        try self.expect(manual.directionDescription == "Credit", "Money in is a credit")
    }

    static func main() throws {
        try self.bsbInputChecks()
        try self.accountFilterChecks()
        try self.summaryChecks()
        try self.occurrenceChecks()
        try self.accountDeletionChecks()
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
        try self.expect(signed.allSatisfy { $0.sourceInstitution == "Test Bank" && $0.accountID == self.accountID }, "Every imported row belongs to the selected account")
        let quoted = try self.parse("Date,Description,Amount\n20/09/2026,\"Cafe, \"\"Main\"\"\nStreet\",\"-1,234.56\"")
        try self.expect(quoted[0].description == "Cafe, \"Main\"\nStreet", "Quoted comma, escaped quotes, embedded newline")
        try self.expect(quoted[0].amount == Decimal(string: "-1234.56"), "Grouped amounts")
        let separate = try self.parse("Transaction Date,Details,Debit,Credit\n20/09/2026,Shop,12.34,\n20/09/2026,Pay,,100\n")
        try self.expect(separate.map(\.amount) == [Decimal(string: "-12.34")!, 100], "Debit and credit direction")
        let currency = try self.parse("Date,Merchant,Amount\n20/09/2026,Refund,$20.00\n20/09/2026,Shop,(12.34)")
        try self.expect(currency.map(\.amount) == [20, Decimal(string: "-12.34")!], "Currency and accounting negative")
        let utf16 = "Date,Description,Amount\n20/09/2026,Shop,-1".data(using: .utf16)!
        try self.expect(try TransactionCSVParser.parse(utf16, accountID: self.accountID, institution: "Bank").count == 1, "UTF-16 BOM")
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
            _ = try TransactionCSVParser.parse(Data(repeating: 65, count: TransactionCSVAttachment.maximumFileSize + 1), accountID: self.accountID, institution: "Bank")
        }
        try self.rejects("Reject too many rows") {
            _ = try self.parse("Date,Description,Amount\n" + String(repeating: "20/09/2026,Shop,-1\n", count: 20_001))
        }
        try self.rejects("Reject invalid encoding") {
            _ = try TransactionCSVParser.parse(Data([0xFF, 0x00, 0xFF]), accountID: self.accountID, institution: "Bank")
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
        let store = TransactionStore(defaults: defaults)
        let accounts = AccountStore(defaults: defaults)
        try self.expect(store.transactions().isEmpty, "Fresh install starts without transactions")
        try self.expect(try accounts.load().isEmpty, "Fresh install starts without accounts")
        let created = try accounts.create(name: " Everyday ", type: .transaction, number: "1234 5678", bsb: "062-000", institution: " Test Bank ")
        let second = try accounts.create(name: "Savings", type: .savings, number: "87654321", bsb: "123 456", institution: "Test Bank")
        try self.expect(created.name == "Everyday" && created.institution == "Test Bank", "Trim account details")
        try self.expect(created.type == .transaction && created.number == "12345678" && created.bsb == "062000", "Normalise number and BSB")
        try self.expect(second.type == .savings && second.bsb == "123456", "Savings accounts keep a BSB")
        for type in AccountType.allCases where type.hasBSB {
            try self.rejects("Require a BSB for \(type.title)") { _ = try accounts.create(name: "Everyday", type: type, number: "1", bsb: nil, institution: "Bank") }
            try self.rejects("Reject a blank BSB for \(type.title)") { _ = try accounts.create(name: "Everyday", type: type, number: "1", bsb: " - ", institution: "Bank") }
        }
        let cardWithoutBSB = try accounts.create(name: "Charge", type: .chargeCard, number: "1234", bsb: nil, institution: "Bank")
        try self.expect(cardWithoutBSB.bsb == nil, "Card accounts need no BSB")
        try accounts.delete(id: cardWithoutBSB.id, transactionStore: store)
        let card = try accounts.create(name: "Card", type: .creditCard, number: "4111-1111-1111-1111", bsb: "062000", institution: "Bank")
        try self.expect(card.number == "4111111111111111" && card.bsb == nil, "Card accounts never keep a BSB")
        try self.rejects("Reject an empty account number") { _ = try accounts.create(name: "Everyday", type: .transaction, number: " - ", bsb: "062000", institution: "Bank") }
        try self.rejects("Reject a non-numeric account number") { _ = try accounts.create(name: "Everyday", type: .homeLoan, number: "12AB", bsb: "062000", institution: "Bank") }
        try self.rejects("Reject an over-long account number") { _ = try accounts.create(name: "Everyday", type: .transaction, number: String(repeating: "1", count: 21), bsb: "062000", institution: "Bank") }
        try self.rejects("Reject a short BSB") { _ = try accounts.create(name: "Everyday", type: .personalLoan, number: "1", bsb: "06200", institution: "Bank") }
        try self.rejects("Reject a non-numeric BSB") { _ = try accounts.create(name: "Everyday", type: .investmentLoan, number: "1", bsb: "06200X", institution: "Bank") }
        try accounts.delete(id: card.id, transactionStore: store)
        let storedCard = try JSONDecoder().decode(Account.self, from: Data(#"{"id":"\#(UUID())","name":"Card","type":"creditCard","number":"4111","bsb":"062000","institution":"Bank","balance":0}"#.utf8))
        try self.expect(storedCard.bsb == nil, "A stored card account never decodes with a BSB")
        try self.rejects("Reject stored accounts without type and number") {
            _ = try JSONDecoder().decode(Account.self, from: Data(#"{"id":"\#(UUID())","name":"Old","institution":"Bank","balance":5}"#.utf8))
        }
        try self.expect(try AccountStore(defaults: defaults).load() == [created, second], "Accounts and stable IDs survive reload")
        try self.expect(created.id != second.id, "Accounts at the same institution remain distinct")
        try self.rejects("Reject an empty account name") { _ = try accounts.create(name: "  ", type: .transaction, number: "12345678", bsb: "062000", institution: "Bank") }
        try self.rejects("Reject an empty institution") { _ = try accounts.create(name: "Everyday", type: .transaction, number: "12345678", bsb: "062000", institution: "  ") }
        let firstAccountRows = try TransactionCSVParser.parse(bytes, accountID: created.id, institution: created.institution)
        let secondAccountRows = try TransactionCSVParser.parse(bytes, accountID: second.id, institution: second.institution)
        try self.expect(firstAccountRows.allSatisfy { $0.accountID == created.id }, "Import links to newly created account")
        try self.expect(secondAccountRows.allSatisfy { $0.accountID == second.id }, "Reparsing for a different account changes every link")
        try store.save(signed)
        let reloaded = TransactionStore(defaults: defaults)
        try self.expect(reloaded.transactions() == signed.sorted { $0.date > $1.date }, "Transactions persist with institution and decimal amounts")
        try store.save(signed[0])
        try self.expect(store.transactions().count == 2, "Saving same transaction is an upsert")
        try store.save(firstAccountRows)
        try self.expect(reloaded.transactions().contains { $0.accountID == created.id }, "Account link survives transaction reload")
        let beforeDeletion = store.transactions()
        try store.delete(id: signed[0].id)
        try self.expect(reloaded.transactions() == beforeDeletion.filter { $0.id != signed[0].id }, "Delete exact transaction and preserve others across reload")
        let storedAfterDeletion = try JSONDecoder().decode([Transaction].self, from: defaults.data(forKey: "transactions")!)
        try self.expect(!storedAfterDeletion.contains { $0.id == signed[0].id }, "Manual and imported transactions are removed from storage")
        try store.delete(id: signed[0].id)
        try store.delete(id: UUID())
        try self.expect(reloaded.transactions().count == beforeDeletion.count - 1, "Repeated or unknown deletion leaves other rows intact")
        let duplicateRows = try self.parse("Date,Description,Amount\n20/09/2026,Same merchant,-1\n20/09/2026,Same merchant,-1")
        try store.save(duplicateRows)
        try store.delete(id: duplicateRows[1].id)
        try self.expect(!reloaded.transactions().contains { $0.id == duplicateRows[1].id }, "Deleted transaction stays deleted after recreation of store")
        try self.expect(reloaded.transactions().contains { $0.id == duplicateRows[0].id }, "Identical-looking transaction with different ID remains")
        try self.expect(reloaded.transactions().filter { $0.description == "Same merchant" }.count == 1, "Search results exclude deleted transaction")
        try store.delete(id: duplicateRows[0].id)
        for transaction in store.transactions() { try store.delete(id: transaction.id) }
        try self.expect(reloaded.transactions().isEmpty, "Deleting all transactions produces empty history")
        defaults.set(Data("broken".utf8), forKey: "accounts")
        try self.rejects("Do not overwrite corrupt account storage") { _ = try accounts.create(name: "Account", type: .transaction, number: "12345678", bsb: "062000", institution: "Bank") }
        try self.expect(defaults.data(forKey: "accounts") == Data("broken".utf8), "Corrupt account data retained for recovery")
        defaults.set(Data("broken".utf8), forKey: "transactions")
        try self.rejects("Do not overwrite corrupted history") { try store.save(signed[0]) }
        try self.rejects("Do not delete with corrupted transaction history") { try store.delete(id: signed[0].id) }
        try self.expect(defaults.data(forKey: "transactions") == Data("broken".utf8), "Corrupt history remains available for recovery")
        print("Passed \(self.checks) transaction checks.")
    }

    static func accountDeletionChecks() throws {
        let suite = "AccountDeletionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let accounts = AccountStore(defaults: defaults)
        let target = try accounts.create(name: "Everyday", type: .transaction, number: "12345678", bsb: "062000", institution: "Bank")
        let other = try accounts.create(name: "Everyday", type: .transaction, number: "12345678", bsb: "062000", institution: "Bank")
        func transaction(_ accountID: UUID) -> Transaction {
            Transaction(id: UUID(), description: "Shop", date: .now, amount: -10, accountID: accountID)
        }
        let transactions = TransactionStore(defaults: defaults)
        let savedTarget = transaction(target.id)
        let savedOther = transaction(other.id)
        try transactions.save([savedTarget, savedOther])
        try accounts.delete(id: target.id, transactionStore: transactions)
        let reopenedAccounts = AccountStore(defaults: defaults)
        let reopenedTransactions = TransactionStore(defaults: defaults)
        try self.expect(try reopenedAccounts.load() == [other], "Account deletion persists and preserves same-name accounts")
        try self.expect(reopenedTransactions.transactions() == [savedOther], "Cascade removes transactions for only the deleted account")
        let savedRows = try JSONDecoder().decode([Transaction].self, from: defaults.data(forKey: "transactions")!)
        try self.expect(savedRows == [savedOther], "Cascade physically removes saved linked history")
        try accounts.delete(id: target.id, transactionStore: transactions)
        try self.expect(reopenedTransactions.transactions().count == 1, "Repeated account deletion is harmless")
        let emptyAccount = try accounts.create(name: "Empty", type: .transaction, number: "12345678", bsb: "062000", institution: "Bank")
        try accounts.delete(id: emptyAccount.id, transactionStore: transactions)
        try self.expect(try accounts.load() == [other], "Delete account with no linked transactions")

        // Decode failures must not leave the account and its history half-deleted.
        let goodAccounts = defaults.data(forKey: "accounts")!
        let goodTransactions = defaults.data(forKey: "transactions")!
        defaults.set(Data("broken".utf8), forKey: "accounts")
        try self.rejects("Reject cascade with corrupt accounts") { try accounts.delete(id: other.id, transactionStore: transactions) }
        try self.expect(defaults.data(forKey: "transactions") == goodTransactions, "Account read failure preserves linked history")
        defaults.set(goodAccounts, forKey: "accounts")
        defaults.set(Data("broken".utf8), forKey: "transactions")
        try self.rejects("Reject cascade with corrupt transactions") { try accounts.delete(id: other.id, transactionStore: transactions) }
        try self.expect(defaults.data(forKey: "accounts") == goodAccounts, "Transaction read failure preserves account")
        defaults.set(goodTransactions, forKey: "transactions")
    }
}
