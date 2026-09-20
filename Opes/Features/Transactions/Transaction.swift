import Foundation

struct Transaction: Codable, Hashable, Identifiable {
    let id: UUID
    let merchant: String
    let date: Date
    /// Negative for money out, positive for money in.
    let amount: Decimal
    /// Required for newly saved transactions. Optional for decoding older local
    /// history that was saved before account selection was mandatory.
    let accountID: AccountPreview.ID?
    let sourceInstitution: String?

    init(
        id: UUID, merchant: String, date: Date, amount: Decimal,
        accountID: AccountPreview.ID?, sourceInstitution: String? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.date = date
        self.amount = amount
        self.accountID = accountID
        self.sourceInstitution = sourceInstitution
    }

    var formattedAmount: String {
        self.amount.formatted(.currency(code: "AUD"))
    }

    var formattedDate: String {
        self.date.formatted(date: .abbreviated, time: .shortened)
    }

    /// The date spelled out, for a screen with room for it.
    var formattedFullDate: String {
        self.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    var formattedTime: String {
        self.date.formatted(date: .omitted, time: .shortened)
    }

    /// A transaction of exactly zero moves nothing, so it reads as money out
    /// alongside the rest of the spending.
    var isMoneyIn: Bool {
        self.amount > 0
    }

    var directionDescription: String {
        self.isMoneyIn ? "Money in" : "Money out"
    }
}

/// Pay cycles depend on this small read interface instead of a particular local
/// store. A backend implementation can replace local persistence later.
protocol TransactionProviding {
    func transactions() -> [Transaction]
}
