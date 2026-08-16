import Foundation

struct Transaction: Hashable, Identifiable {
    let id: UUID
    let merchant: String
    let date: Date
    /// Negative for money out, positive for money in.
    let amount: Decimal

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
        .makeSample(merchant: "Woolworths", cents: -8_420, hoursAgo: 3),
        .makeSample(merchant: "Opal Top Up", cents: -2_000, hoursAgo: 9),
        .makeSample(merchant: "Single Origin Roasters", cents: -650, hoursAgo: 27),
        .makeSample(merchant: "Salary", cents: 412_388, hoursAgo: 30),
        .makeSample(merchant: "Origin Energy", cents: -17_615, hoursAgo: 52),
        .makeSample(merchant: "Kmart", cents: -4_900, hoursAgo: 74),
        .makeSample(merchant: "Netflix", cents: -2_599, hoursAgo: 99),
        .makeSample(merchant: "Bunnings", cents: -13_245, hoursAgo: 121),
        .makeSample(merchant: "Coles", cents: -6_738, hoursAgo: 138),
        .makeSample(merchant: "Uber", cents: -2_340, hoursAgo: 145),
        .makeSample(merchant: "Chemist Warehouse", cents: -3_195, hoursAgo: 160),
        .makeSample(merchant: "Spotify", cents: -1_399, hoursAgo: 172),
        .makeSample(merchant: "Dan Murphy's", cents: -5_480, hoursAgo: 188),
        .makeSample(merchant: "Telstra", cents: -6_500, hoursAgo: 199),
        .makeSample(merchant: "Guzman y Gomez", cents: -1_850, hoursAgo: 210),
        .makeSample(merchant: "JB Hi-Fi", cents: -24_900, hoursAgo: 232),
        .makeSample(merchant: "Rent", cents: -95_000, hoursAgo: 250),
        .makeSample(merchant: "Aldi", cents: -5_215, hoursAgo: 266),
        .makeSample(merchant: "Officeworks", cents: -8_930, hoursAgo: 279),
        .makeSample(merchant: "Transfer from Savings", cents: 50_000, hoursAgo: 288),
        .makeSample(merchant: "Mecca", cents: -7_200, hoursAgo: 301),
        .makeSample(merchant: "Fitness First", cents: -2_995, hoursAgo: 318),
        .makeSample(merchant: "Ampol", cents: -8_712, hoursAgo: 330),
        .makeSample(merchant: "Uber Eats", cents: -4_265, hoursAgo: 349),
        .makeSample(merchant: "Apple", cents: -1_499, hoursAgo: 366),
    ]

    private static func makeSample(merchant: String, cents: Int, hoursAgo: Int) -> Transaction {
        Transaction(
            // Stable sample IDs keep a locally saved pay-cycle link valid across
            // app launches until a backend supplies real transaction IDs.
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", hoursAgo))!,
            merchant: merchant,
            date: Date(timeIntervalSinceNow: -Double(hoursAgo) * 3_600),
            // Built from whole cents so the sample amounts stay exact.
            amount: Decimal(cents) / 100
        )
    }
}
