import Foundation

/// A header-based CSV format, independent of bank export versions. Unsupported or
/// invalid rows fail the whole file so a partial import never silently loses money.
enum TransactionCSVParser {
    struct ImportError: LocalizedError {
        let message: String
        var errorDescription: String? { self.message }
    }

    static func parse(_ data: Data, accountID: UUID, institution: String) throws -> [Transaction] {
        guard data.count <= TransactionCSVAttachment.maximumFileSize else {
            throw TransactionCSVAttachment.AttachmentError.tooLarge
        }
        let text: String?
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            text = String(data: data, encoding: .utf16)
        } else {
            text = String(data: data, encoding: .utf8)
        }
        guard let text else {
            throw ImportError(message: "Save the CSV with UTF-8 encoding and try again.")
        }
        let rows = try self.rows(in: text)
        guard let header = rows.first, rows.count > 1 else {
            throw ImportError(message: "The CSV needs a header row and at least one transaction.")
        }
        let names = header.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        func column(_ aliases: [String]) throws -> Int? {
            let matches = names.indices.filter { aliases.contains(names[$0]) }
            guard matches.count <= 1 else {
                throw ImportError(message: "The CSV has ambiguous columns for \(aliases[0]). Keep one column with that name.")
            }
            return matches.first
        }
        guard let dateColumn = try column(["date", "transaction date"]),
              let merchantColumn = try column(["description", "merchant", "transaction description", "details"]) else {
            throw ImportError(message: "The CSV needs Date and Description (or Merchant) columns.")
        }
        let referenceColumn = try column(["reference", "ref", "transaction reference", "receipt number"])
        let amountColumn = try column(["amount", "transaction amount"])
        let debitColumn = try column(["debit", "debit amount", "withdrawal", "withdrawals"])
        let creditColumn = try column(["credit", "credit amount", "deposit", "deposits"])
        guard amountColumn != nil || (debitColumn != nil && creditColumn != nil) else {
            throw ImportError(message: "Include an Amount column, or separate Debit and Credit columns.")
        }
        guard amountColumn == nil || (debitColumn == nil && creditColumn == nil) else {
            throw ImportError(message: "Use either Amount or Debit and Credit columns so the transaction direction is unambiguous.")
        }
        let formatters = ["dd/MM/yyyy", "yyyy-MM-dd", "dd-MM-yyyy", "dd MMM yyyy"].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_AU")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = format
            formatter.isLenient = false
            return formatter
        }
        return try rows.dropFirst().enumerated().map { offset, row in
            let number = offset + 2
            func invalid(_ detail: String) -> ImportError {
                ImportError(message: "Row \(number): \(detail) No transactions have been imported.")
            }
            guard row.count == header.count else {
                throw invalid("The number of columns doesn’t match the header.")
            }
            let dateText = row[dateColumn].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let date = formatters.lazy.compactMap({ formatter -> Date? in
                guard let date = formatter.date(from: dateText), formatter.string(from: date) == dateText else { return nil }
                return date
            }).first else {
                throw invalid("Use a date such as 20/09/2026 or 2026-09-20.")
            }
            let merchant = row[merchantColumn].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !merchant.isEmpty else { throw invalid("A description is required.") }
            let amount: Decimal
            if let amountColumn {
                guard let value = self.amount(row[amountColumn]) else {
                    throw invalid("Enter a signed amount with up to two decimal places.")
                }
                amount = value
            } else if let debitColumn, let creditColumn {
                let debitText = row[debitColumn].trimmingCharacters(in: .whitespacesAndNewlines)
                let creditText = row[creditColumn].trimmingCharacters(in: .whitespacesAndNewlines)
                guard let debit = debitText.isEmpty ? Decimal.zero : self.amount(debitText),
                      let credit = creditText.isEmpty ? Decimal.zero : self.amount(creditText),
                      debit >= 0, credit >= 0, !(debit > 0 && credit > 0) else {
                    throw invalid("Use a positive value in either Debit or Credit for each transaction.")
                }
                amount = credit - debit
            } else {
                throw invalid("An amount is required.")
            }
            guard amount != 0 else { throw invalid("The amount must be greater or less than zero.") }
            let reference = referenceColumn
                .map { row[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.isEmpty ? nil : $0 }
            return Transaction(
                id: UUID(), merchant: merchant, date: date, amount: amount,
                accountID: accountID, sourceInstitution: institution,
                reference: reference, hasTime: false
            )
        }
    }

    private static func amount(_ input: String) -> Decimal? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("("), text.hasSuffix(")") {
            text = "-" + text.dropFirst().dropLast()
        }
        // AUD exports only. Require whole-string matching, including correct grouping.
        let pattern = #"^[+-]?\$?(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]{1,2})?$"#
        guard text.range(of: pattern, options: .regularExpression) != nil else { return nil }
        text = text.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard text.filter(\.isNumber).count <= 28 else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_AU"))
    }

    private static func rows(in input: String) throws -> [[String]] {
        var text = input
        if text.first == "\u{FEFF}" { text.removeFirst() }
        // Normalise line endings before scanning; quoted newlines remain field content.
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var closedQuote = false
        var iterator = text.makeIterator()
        var current = iterator.next()
        func appendRow() throws {
            row.append(field)
            if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                rows.append(row)
            }
            guard rows.count <= 20_001 else {
                throw ImportError(message: "Choose a CSV with no more than 20,000 transactions.")
            }
            row = []
            field = ""
            closedQuote = false
        }
        while let character = current {
            let next = iterator.next()
            if quoted {
                if character == "\"" {
                    if next == "\"" {
                        field.append("\"")
                        current = iterator.next()
                        continue
                    }
                    quoted = false
                    closedQuote = true
                } else {
                    field.append(character)
                }
            } else if character == "," {
                row.append(field)
                field = ""
                closedQuote = false
            } else if character == "\n" {
                try appendRow()
            } else if character == "\"", field.isEmpty, !closedQuote {
                quoted = true
            } else {
                guard !closedQuote, character != "\"" else {
                    throw ImportError(message: "The CSV has invalid quotation marks. Export it again and retry.")
                }
                field.append(character)
            }
            current = next
        }
        guard !quoted else { throw ImportError(message: "The CSV ends inside a quoted field.") }
        if !row.isEmpty || !field.isEmpty || closedQuote { try appendRow() }
        return rows
    }
}
