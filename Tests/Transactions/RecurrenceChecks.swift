import Foundation

extension TransactionTests {
    static func recurrenceChecks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        func repeated(_ summary: String, every days: Int, from offset: Int = 0, amounts: [Decimal]) -> [Transaction] {
            amounts.enumerated().map { index, amount in
                Transaction(id: UUID(), description: "\(summary) \(index)", date: calendar.date(byAdding: .day, value: offset + index * days, to: start)!,
                            amount: amount, accountID: self.accountID, customSummary: summary)
            }
        }
        // Descriptions differ on every row, as bank references do; the summaries agree.
        let rent = repeated("Rent", every: 7, amounts: [-500, -500, -500, -500])
        let pay = repeated("Acme pay", every: 14, amounts: [2100, 2480, 1950, 2300])
        let transfersOut = repeated("Transfer", every: 7, amounts: [-100, -100, -100])
        let transfersIn = repeated("Transfer", every: 7, from: 3, amounts: [60, 60, 60])
        let shop = repeated("Corner shop", every: 7, amounts: [-12, -40, -25])
        let found = RecurrenceDetector(calendar: calendar).detect(in: rent + pay + transfersOut + transfersIn + shop)

        try self.expect(found.contains { $0.merchant == "Rent" && $0.amount == -500 && $0.cadence == .everyDays(7) },
                        "Repeats are grouped by summary, not the description")
        try self.expect(found.contains { $0.merchant == "Acme pay" && $0.isIncome && $0.cadence == .everyDays(14) },
                        "Regular money in is found even when its amount varies")
        try self.expect(found.contains { $0.merchant == "Transfer" && $0.isIncome } && found.contains { $0.merchant == "Transfer" && !$0.isIncome },
                        "Money in and out under one name are found separately")
        try self.expect(!found.contains { $0.merchant == "Corner shop" }, "Charges of varying amounts are not a repeat")

        // An account's forecast lands repeating money in on its dates, as it does
        // repeating money out, unless a pay cycle already counts it.
        let today = calendar.date(byAdding: .day, value: 43, to: start)!
        let forecaster = BalanceForecaster(calendar: calendar)
        let projected = forecaster.forecast(startingBalance: 1000, transactions: pay, payCycles: [], over: .threeMonths,
                                            historyMonths: 1, from: today)
        let fortnights = Decimal(projected.projectedPoints.dropFirst().filter {
            calendar.dateComponents([.day], from: start, to: $0.date).day! % 14 == 0
        }.count)
        try self.expect(fortnights > 0 && projected.expectedIncome == 2300 * fortnights,
                        "Repeating money in is projected at its usual amount on each date it falls")
        try self.expect(projected.projectedBalance == 1000 + projected.expectedIncome, "Repeating money in raises the projected balance")
        let cycle = PayCycle(name: "Acme pay", amount: 0, frequency: .weekly)
        let covered = forecaster.forecast(startingBalance: 1000, transactions: pay, payCycles: [cycle], over: .threeMonths,
                                          historyMonths: 1, from: today)
        try self.expect(covered.expectedIncome == 0, "Money in a pay cycle already covers isn't counted twice")

        let pattern = SpendingPattern.make(from: rent + shop, asOf: calendar.date(byAdding: .day, value: 21, to: start)!, calendar: calendar)
        try self.expect(pattern.irregularDailyOutflow * Decimal(pattern.observedDays) == 77, "Repeats leave the irregular average; the rest stays in it")
    }
}
