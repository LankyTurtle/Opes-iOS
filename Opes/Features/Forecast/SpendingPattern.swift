import Foundation

/// What recent transactions say about money going out, so a forecast can carry
/// that rate forward.
///
/// Only outflows count. Income is projected from pay cycles instead, and counting
/// deposits here as well would credit the same money twice. The cost of that is
/// transfers: money moved out of one of the user's own accounts reads as spending,
/// which is right for that account's own forecast but overstates it across the
/// whole net worth. Categorised transfers can net themselves out once transactions
/// carry a category.
struct SpendingPattern: Hashable {
    /// Average money out per day across the observed window, as a positive amount.
    let dailyOutflow: Decimal
    /// How many days of history the average was taken over.
    let observedDays: Int
    /// Total money out across those days, as a positive amount.
    let observedOutflow: Decimal

    /// Nothing observed, so a forecast built on this moves on income alone.
    static let none = SpendingPattern(dailyOutflow: 0, observedDays: 0, observedOutflow: 0)

    /// An average calendar month rather than a flat 30 days, so this lines up with
    /// a monthly budget over a year.
    private static let daysPerMonth = Decimal(36_525) / Decimal(1_200)

    var monthlyOutflow: Decimal {
        self.dailyOutflow * Self.daysPerMonth
    }

    var hasHistory: Bool {
        self.observedDays > 0 && self.observedOutflow > 0
    }

    /// Averages over the window the transactions themselves cover — from the oldest
    /// one to today — rather than a fixed number of days, so a short history isn't
    /// diluted by days that were never observed.
    static func make(
        from transactions: [Transaction],
        asOf date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> SpendingPattern {
        let today = calendar.startOfDay(for: date)
        let outflows = transactions.filter { $0.amount < 0 && $0.date <= date }

        guard let earliest = outflows.map(\.date).min() else {
            return .none
        }

        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: earliest),
            to: today
        ).day ?? 0
        // The oldest day is one observed day, not zero.
        let days = max(elapsed + 1, 1)
        let total = outflows.reduce(Decimal.zero) { $0 - $1.amount }

        return SpendingPattern(
            dailyOutflow: total / Decimal(days),
            observedDays: days,
            observedOutflow: total
        )
    }

    /// The pattern for one account, from the transactions that moved through it.
    static func make(
        from transactions: [Transaction],
        for accountID: AccountPreview.ID,
        asOf date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> SpendingPattern {
        self.make(
            from: transactions.filter { $0.accountID == accountID },
            asOf: date,
            calendar: calendar
        )
    }
}
