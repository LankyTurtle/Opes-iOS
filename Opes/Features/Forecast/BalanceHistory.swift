import Foundation

/// Rebuilds where a balance has been, so a forecast has something to grow out of.
///
/// Accounts report what they hold now, not what they held in March, so the past is
/// reconstructed backwards: yesterday's closing balance is today's less whatever
/// moved today. That makes the line exact wherever transactions are complete and
/// flat wherever they aren't, which is the honest failure — it can't invent a day
/// it has no record of.
enum BalanceHistory {
    /// Daily closing balances up to and including today, oldest first.
    ///
    /// The window runs back `months` from today but stops at the oldest transaction
    /// on record: drawing a flat line across months nothing is known about would
    /// squeeze the part that is known into the last inch of the chart.
    static func points(
        endingAt balance: Decimal,
        transactions: [Transaction],
        over months: Int = 12,
        asOf date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [ForecastPoint] {
        let today = calendar.startOfDay(for: date)
        let past = transactions.filter { $0.date <= date }

        guard
            let earliest = past.map(\.date).min(),
            let window = calendar.date(byAdding: .month, value: -months, to: today)
        else {
            return [ForecastPoint(date: today, balance: balance)]
        }

        let start = max(calendar.startOfDay(for: earliest), window)

        guard start < today else {
            return [ForecastPoint(date: today, balance: balance)]
        }

        var movements: [Date: Decimal] = [:]
        for transaction in past {
            movements[calendar.startOfDay(for: transaction.date), default: 0] += transaction.amount
        }

        var points = [ForecastPoint(date: today, balance: balance)]
        var closing = balance
        var cursor = today

        while cursor > start {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }

            // Yesterday closed at today's balance less everything that moved today.
            closing -= movements[cursor] ?? 0
            cursor = calendar.startOfDay(for: previous)
            points.append(ForecastPoint(date: cursor, balance: closing))
        }

        return points.reversed()
    }
}
