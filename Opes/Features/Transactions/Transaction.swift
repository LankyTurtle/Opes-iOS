import Foundation

struct Transaction: Hashable, Identifiable {
    let id: UUID
    let merchant: String
    let date: Date
    /// Negative for money out, positive for money in.
    let amount: Decimal
    /// The account the money moved through. Optional because an imported or
    /// manually entered transaction may not name one.
    let accountID: AccountPreview.ID?

    var formattedAmount: String {
        self.amount.formatted(.currency(code: "AUD"))
    }

    var formattedDate: String {
        self.date.formatted(date: .abbreviated, time: .shortened)
    }
}

/// Pay cycles depend on this small read interface instead of a particular local
/// store. A backend implementation can replace the sample provider later.
protocol TransactionProviding {
    func transactions() -> [Transaction]
}

struct SampleTransactionProvider: TransactionProviding {
    func transactions() -> [Transaction] {
        Transaction.sample
    }
}

extension Transaction {
    /// Local sample data, until transactions come from a real store.
    static let sample: [Transaction] = [
        .makeSample(merchant: "Woolworths", cents: -8_420, hoursAgo: 3, account: .spending),
        .makeSample(merchant: "Opal Top Up", cents: -2_000, hoursAgo: 9, account: .spending),
        .makeSample(merchant: "Single Origin Roasters", cents: -650, hoursAgo: 27, account: .spending),
        .makeSample(merchant: "Salary", cents: 412_388, hoursAgo: 30, account: .everydayAccess),
        .makeSample(merchant: "Origin Energy", cents: -17_615, hoursAgo: 52, account: .bills),
        .makeSample(merchant: "Kmart", cents: -4_900, hoursAgo: 74, account: .spending),
        .makeSample(merchant: "Netflix", cents: -2_599, hoursAgo: 99, account: .bills),
        .makeSample(merchant: "Bunnings", cents: -13_245, hoursAgo: 121, account: .platinumCard),
        .makeSample(merchant: "Coles", cents: -6_738, hoursAgo: 138, account: .spending),
        .makeSample(merchant: "Uber", cents: -2_340, hoursAgo: 145, account: .spending),
        .makeSample(merchant: "Chemist Warehouse", cents: -3_195, hoursAgo: 160, account: .spending),
        .makeSample(merchant: "Spotify", cents: -1_399, hoursAgo: 172, account: .bills),
        .makeSample(merchant: "Dan Murphy's", cents: -5_480, hoursAgo: 188, account: .platinumCard),
        .makeSample(merchant: "Telstra", cents: -6_500, hoursAgo: 199, account: .bills),
        .makeSample(merchant: "Guzman y Gomez", cents: -1_850, hoursAgo: 210, account: .spending),
        .makeSample(merchant: "JB Hi-Fi", cents: -24_900, hoursAgo: 232, account: .platinumCard),
        .makeSample(merchant: "Rent", cents: -95_000, hoursAgo: 250, account: .everydayAccess),
        .makeSample(merchant: "Aldi", cents: -5_215, hoursAgo: 266, account: .spending),
        .makeSample(merchant: "Officeworks", cents: -8_930, hoursAgo: 279, account: .platinumCard),
        .makeSample(merchant: "Transfer from Savings", cents: 50_000, hoursAgo: 288, account: .everydayAccess),
        .makeSample(merchant: "Mecca", cents: -7_200, hoursAgo: 301, account: .platinumCard),
        .makeSample(merchant: "Fitness First", cents: -2_995, hoursAgo: 318, account: .bills),
        .makeSample(merchant: "Ampol", cents: -8_712, hoursAgo: 330, account: .spending),
        .makeSample(merchant: "Uber Eats", cents: -4_265, hoursAgo: 349, account: .spending),
        .makeSample(merchant: "Apple", cents: -1_499, hoursAgo: 366, account: .platinumCard),
    ]

    private static func makeSample(
        merchant: String,
        cents: Int,
        hoursAgo: Int,
        account: AccountPreview
    ) -> Transaction {
        Transaction(
            // Stable sample IDs keep a locally saved pay-cycle link valid across
            // app launches until a backend supplies real transaction IDs.
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", hoursAgo))!,
            merchant: merchant,
            date: Date(timeIntervalSinceNow: -Double(hoursAgo) * 3_600),
            // Built from whole cents so the sample amounts stay exact.
            amount: Decimal(cents) / 100,
            accountID: account.id
        )
    }
}
