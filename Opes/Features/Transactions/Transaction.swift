import Foundation

struct Transaction: Codable, Hashable, Identifiable {
    let id: UUID
    /// The description as the bank or the user first recorded it. Never edited.
    let description: String
    let date: Date
    /// Whether `date` carries a time of day; CSV exports only give the day.
    let hasTime: Bool
    /// Negative for money out, positive for money in.
    let amount: Decimal
    let accountID: AccountPreview.ID
    let sourceInstitution: String?
    /// The bank's reference for the transaction, when the import carried one.
    let reference: String?
    /// The user's own summary. Nil until they write one, so the summary follows
    /// the description.
    private(set) var customSummary: String?

    init(
        id: UUID, description: String, date: Date, hasTime: Bool = true, amount: Decimal,
        accountID: AccountPreview.ID, sourceInstitution: String? = nil,
        reference: String? = nil, customSummary: String? = nil
    ) {
        self.id = id
        self.description = description
        self.date = date
        self.hasTime = hasTime
        self.amount = amount
        self.accountID = accountID
        self.sourceInstitution = sourceInstitution
        self.reference = reference
        self.customSummary = customSummary
    }

    /// What the transaction is shown as everywhere: the user's summary, or the
    /// description until they write one.
    var summary: String {
        self.customSummary ?? self.description
    }

    /// A copy summarised as `text`. A blank summary, or one that only repeats
    /// the description, goes back to following the description.
    func withSummary(_ text: String) -> Transaction {
        var copy = self
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.customSummary = trimmed.isEmpty || trimmed == self.description ? nil : trimmed
        return copy
    }

    var formattedAmount: String {
        self.amount.formatted(.currency(code: "AUD"))
    }

    var formattedDate: String {
        self.date.formatted(date: .abbreviated, time: self.hasTime ? .shortened : .omitted)
    }

    /// When the transaction happened, as `Tue 22 Sep 2026`, with the time after
    /// it only when one was recorded.
    func formattedOccurrence(locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE dd MMM yyyy"
        let day = formatter.string(from: self.date)
        guard self.hasTime else { return day }
        formatter.dateFormat = nil
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(day), \(formatter.string(from: self.date))"
    }

    /// A transaction of exactly zero moves nothing, so it reads as money out
    /// alongside the rest of the spending.
    var isMoneyIn: Bool {
        self.amount > 0
    }

    var directionDescription: String {
        self.isMoneyIn ? "Credit" : "Debit"
    }
}

/// Pay cycles depend on this small read interface instead of a particular local
/// store. A backend implementation can replace local persistence later.
protocol TransactionProviding {
    func transactions() -> [Transaction]
}
