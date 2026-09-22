import Foundation

struct Transaction: Codable, Hashable, Identifiable {
    let id: UUID
    /// The description as the bank or the user first recorded it. Stored under
    /// its original key so history saved before display names still decodes.
    let merchant: String
    let date: Date
    /// Negative for money out, positive for money in.
    let amount: Decimal
    /// Required for newly saved transactions. Optional for decoding older local
    /// history that was saved before account selection was mandatory.
    let accountID: AccountPreview.ID?
    let sourceInstitution: String?
    /// The bank's reference for the transaction, when the import carried one.
    let reference: String?
    /// The user's own name for the transaction. Nil shows the description.
    private(set) var displayDescription: String?
    /// Whether `date` carries a time of day; CSV exports only give the day. Nil
    /// for history saved before this was recorded.
    private let timeRecorded: Bool?

    init(
        id: UUID, merchant: String, date: Date, amount: Decimal,
        accountID: AccountPreview.ID?, sourceInstitution: String? = nil,
        reference: String? = nil, displayDescription: String? = nil, hasTime: Bool = true
    ) {
        self.id = id
        self.merchant = merchant
        self.date = date
        self.amount = amount
        self.accountID = accountID
        self.sourceInstitution = sourceInstitution
        self.reference = reference
        self.displayDescription = displayDescription
        self.timeRecorded = hasTime
    }

    /// Older history didn't record this. Imports landed on local midnight and
    /// manual entries almost never do, so midnight reads as no time.
    var hasTime: Bool {
        self.timeRecorded ?? (Calendar.current.startOfDay(for: self.date) != self.date)
    }

    /// What the transaction is shown as everywhere: the user's name for it, or
    /// the description until they give it one.
    var displayName: String {
        self.displayDescription ?? self.merchant
    }

    /// A copy shown as `name`. A blank name, or one that only repeats the
    /// description, goes back to showing the description.
    func renamed(to name: String) -> Transaction {
        var copy = self
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.displayDescription = trimmed.isEmpty || trimmed == self.merchant ? nil : trimmed
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
