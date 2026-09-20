import Foundation

enum TransactionAmount {
    /// Decimal(string:) accepts numeric prefixes, so validate the entire input first.
    static func parse(_ input: String, locale: Locale = .autoupdatingCurrent) -> Decimal? {
        let separator = locale.decimalSeparator ?? "."
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.components(separatedBy: separator)
        guard (1...2).contains(parts.count),
              parts.contains(where: { !$0.isEmpty }),
              parts.allSatisfy({ $0.allSatisfy { $0 >= "0" && $0 <= "9" } }),
              parts.joined().count <= 28,
              parts.count == 1 || parts[1].count <= 2,
              let amount = Decimal(string: text, locale: locale),
              amount > 0 else {
            return nil
        }
        return amount
    }
}
