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
    ///
    /// A year of it, shaped the way a real account is: pay and bills repeating on
    /// their own cadences, and irregular day-to-day spending around them. The
    /// forecast reads those repeats back out of this, so a flat fortnight of
    /// placeholder rows would leave it with nothing to find.
    static let sample: [Transaction] = SampleTransactions.make()
}

/// Builds the sample year. Deterministic — the same seed every launch — so a
/// pay cycle linked to a sample transaction still points at the same one, and two
/// runs of the app show the same balances.
private enum SampleTransactions {
    /// How far back the sample history runs.
    private static let days = 365

    private struct Recurring {
        let merchant: String
        let cents: Int
        let cadence: Cadence
        let account: AccountPreview

        enum Cadence {
            /// A steady gap, counted back from the most recent occurrence.
            case everyDays(Int, mostRecentDaysAgo: Int)
            case monthly(day: Int)
        }
    }

    private struct Irregular {
        let merchant: String
        let minimumCents: Int
        let maximumCents: Int
        let account: AccountPreview
        /// Rough share of the irregular spending this merchant takes.
        let weight: Int
    }

    private static let recurring: [Recurring] = [
        .init(merchant: "Salary", cents: 412_388, cadence: .everyDays(14, mostRecentDaysAgo: 4), account: .everydayAccess),
        .init(merchant: "Home Loan Repayment", cents: -245_000, cadence: .monthly(day: 15), account: .everydayAccess),
        .init(merchant: "Origin Energy", cents: -17_615, cadence: .monthly(day: 12), account: .bills),
        .init(merchant: "Telstra", cents: -6_500, cadence: .monthly(day: 18), account: .bills),
        .init(merchant: "Netflix", cents: -2_599, cadence: .monthly(day: 7), account: .bills),
        .init(merchant: "Spotify", cents: -1_399, cadence: .monthly(day: 22), account: .bills),
        .init(merchant: "Fitness First", cents: -2_995, cadence: .everyDays(14, mostRecentDaysAgo: 9), account: .bills),
        // Both halves of every transfer, under their own names on each side, so each
        // one nets to nothing across the whole position while still moving the two
        // accounts it touches.
        .init(merchant: "Transfer to Savings", cents: -50_000, cadence: .monthly(day: 16), account: .everydayAccess),
        .init(merchant: "Transfer from Everyday", cents: 50_000, cadence: .monthly(day: 16), account: .savingsMaximiser),
        .init(merchant: "Transfer to Spending", cents: -240_000, cadence: .monthly(day: 16), account: .everydayAccess),
        .init(merchant: "Spending Top Up", cents: 240_000, cadence: .monthly(day: 16), account: .spending),
        .init(merchant: "Card Payment", cents: -130_000, cadence: .monthly(day: 24), account: .everydayAccess),
        .init(merchant: "Card Payment Received", cents: 130_000, cadence: .monthly(day: 24), account: .platinumCard),
    ]

    private static let irregular: [Irregular] = [
        .init(merchant: "Woolworths", minimumCents: 3_200, maximumCents: 14_500, account: .spending, weight: 5),
        .init(merchant: "Coles", minimumCents: 2_800, maximumCents: 11_900, account: .spending, weight: 4),
        .init(merchant: "Aldi", minimumCents: 2_100, maximumCents: 8_600, account: .spending, weight: 3),
        .init(merchant: "Single Origin Roasters", minimumCents: 450, maximumCents: 1_250, account: .spending, weight: 6),
        .init(merchant: "Guzman y Gomez", minimumCents: 1_400, maximumCents: 3_600, account: .spending, weight: 3),
        .init(merchant: "Uber Eats", minimumCents: 2_600, maximumCents: 7_400, account: .spending, weight: 3),
        .init(merchant: "Uber", minimumCents: 1_200, maximumCents: 4_800, account: .spending, weight: 2),
        .init(merchant: "Opal Top Up", minimumCents: 2_000, maximumCents: 4_000, account: .spending, weight: 2),
        .init(merchant: "Ampol", minimumCents: 5_500, maximumCents: 11_200, account: .spending, weight: 2),
        .init(merchant: "Chemist Warehouse", minimumCents: 1_100, maximumCents: 6_400, account: .spending, weight: 1),
        .init(merchant: "Dan Murphy's", minimumCents: 3_200, maximumCents: 9_800, account: .platinumCard, weight: 2),
        .init(merchant: "Kmart", minimumCents: 1_900, maximumCents: 12_400, account: .platinumCard, weight: 2),
        .init(merchant: "Bunnings", minimumCents: 2_400, maximumCents: 21_000, account: .platinumCard, weight: 1),
        .init(merchant: "Mecca", minimumCents: 4_500, maximumCents: 16_000, account: .platinumCard, weight: 1),
        .init(merchant: "JB Hi-Fi", minimumCents: 3_900, maximumCents: 34_000, account: .platinumCard, weight: 1),
        .init(merchant: "Officeworks", minimumCents: 1_800, maximumCents: 11_500, account: .platinumCard, weight: 1),
        .init(merchant: "Apple", minimumCents: 1_499, maximumCents: 4_499, account: .platinumCard, weight: 1),
    ]

    /// Weekends carry more of the day-to-day spending than a Tuesday does, which is
    /// the shape the forecast picks back up.
    private static let dailyCountsByWeekday: [Int: [Int]] = [
        1: [1, 2, 2, 3], // Sunday
        2: [0, 1, 1, 2],
        3: [0, 1, 1, 2],
        4: [0, 1, 1, 2],
        5: [1, 1, 2, 2],
        6: [1, 2, 2, 3],
        7: [1, 2, 3, 3], // Saturday
    ]

    static func make(
        asOf date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Transaction] {
        let today = calendar.startOfDay(for: date)
        var random = SeededRandom(seed: 0x4F70_6573)
        var transactions: [Transaction] = []

        guard let earliest = calendar.date(byAdding: .day, value: -self.days, to: today) else {
            return []
        }

        for item in self.recurring {
            transactions.append(
                contentsOf: self.occurrences(of: item, from: earliest, to: today, calendar: calendar)
            )
        }

        let weightedIrregular = self.irregular.flatMap { item in
            Array(repeating: item, count: item.weight)
        }

        for dayOffset in 0...self.days {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)
            let counts = self.dailyCountsByWeekday[weekday] ?? [1]
            let count = counts[random.next(upperBound: counts.count)]

            for purchase in 0..<count {
                let item = weightedIrregular[random.next(upperBound: weightedIrregular.count)]
                let spread = max(item.maximumCents - item.minimumCents, 1)
                let cents = item.minimumCents + random.next(upperBound: spread)
                // Spread through the day so the list reads as a sequence rather than
                // a stack of identical timestamps.
                let hour = 7 + random.next(upperBound: 13)

                transactions.append(
                    self.make(
                        merchant: item.merchant,
                        cents: -cents,
                        on: day,
                        hour: hour,
                        minute: purchase * 7 % 60,
                        account: item.account,
                        calendar: calendar
                    )
                )
            }
        }

        // Sorted newest first and given their identifiers last, so an identifier
        // stays with the same transaction across launches.
        return transactions
            .sorted { $0.date > $1.date }
            .enumerated()
            .map { index, transaction in
                Transaction(
                    id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", index))!,
                    merchant: transaction.merchant,
                    date: transaction.date,
                    amount: transaction.amount,
                    accountID: transaction.accountID
                )
            }
    }

    private static func occurrences(
        of item: Recurring,
        from earliest: Date,
        to today: Date,
        calendar: Calendar
    ) -> [Transaction] {
        var dates: [Date] = []

        switch item.cadence {
        case .everyDays(let interval, let mostRecentDaysAgo):
            var cursor = calendar.date(byAdding: .day, value: -mostRecentDaysAgo, to: today)
            while let date = cursor, date >= earliest {
                dates.append(date)
                cursor = calendar.date(byAdding: .day, value: -interval, to: date)
            }

        case .monthly(let day):
            // A fixed run of months rather than a walk, so the month the window
            // opens in is still considered once its own occurrence has passed.
            for monthsAgo in 0...13 {
                guard
                    let cursor = calendar.date(byAdding: .month, value: -monthsAgo, to: today),
                    let length = calendar.range(of: .day, in: .month, for: cursor)?.count
                else {
                    continue
                }

                var components = calendar.dateComponents([.year, .month], from: cursor)
                components.day = min(day, length)

                guard
                    let occurrence = calendar.date(from: components),
                    occurrence >= earliest,
                    occurrence <= today
                else {
                    continue
                }

                dates.append(calendar.startOfDay(for: occurrence))
            }
        }

        return dates.map { date in
            self.make(
                merchant: item.merchant,
                cents: item.cents,
                on: date,
                hour: 9,
                minute: 15,
                account: item.account,
                calendar: calendar
            )
        }
    }

    /// The identifier is filled in once the whole set is ordered.
    private static func make(
        merchant: String,
        cents: Int,
        on day: Date,
        hour: Int,
        minute: Int,
        account: AccountPreview,
        calendar: Calendar
    ) -> Transaction {
        let date = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        ) ?? day

        return Transaction(
            id: UUID(),
            merchant: merchant,
            date: date,
            // Built from whole cents so the sample amounts stay exact.
            amount: Decimal(cents) / 100,
            accountID: account.id
        )
    }
}

/// A tiny xorshift generator, so the sample data is the same on every launch
/// without depending on `SystemRandomNumberGenerator`.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        // Zero is the one state xorshift can't leave.
        self.state = seed == 0 ? 0x9E37_79B9 : seed
    }

    mutating func next(upperBound: Int) -> Int {
        guard upperBound > 1 else {
            return 0
        }

        self.state ^= self.state << 13
        self.state ^= self.state >> 7
        self.state ^= self.state << 17

        return Int(self.state % UInt64(upperBound))
    }
}
