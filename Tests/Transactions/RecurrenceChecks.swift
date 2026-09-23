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
        func forecast(_ transactions: [Transaction], _ cycles: [PayCycle]) -> Forecast {
            forecaster.forecast(startingBalance: 1000, transactions: transactions, payCycles: cycles, over: .threeMonths,
                                historyMonths: 1, from: today)
        }
        let payKey = RecurrenceKey(pay[0])
        let cycle = PayCycle(name: "Acme pay", amount: 2300, accountID: self.accountID, frequency: .weekly)
        let covered = forecast(pay, [cycle])
        try self.expect(covered.expectedIncome == forecast([], [cycle]).expectedIncome,
                        "Money in a pay cycle already covers isn't counted twice")
        try self.expect(covered.spending.recurring.contains { $0.key == payKey } && covered.spending.payCycleNames[payKey] == "Acme pay",
                        "Money in a pay cycle covers is still listed, naming the cycle")
        let unpaid = PayCycle(name: "Acme pay", amount: 0, frequency: .weekly)
        try self.expect(forecast(pay, [unpaid]).expectedIncome == projected.expectedIncome,
                        "A pay cycle with no amount projects nothing, so it doesn't stand in for the deposits")
        let elsewhere = PayCycle(name: "Acme pay", amount: 2300, accountID: UUID(), frequency: .weekly)
        try self.expect(forecast(pay, [elsewhere]).spending.payCycleNames.isEmpty,
                        "A pay cycle paid into another account doesn't stand in for this account's deposits")

        // Sturdier rhythms: a late pay, a pay split in two on one day, and a move from
        // fortnightly to monthly pay are all still found.
        func deposits(_ summary: String, _ offsets: [Int], _ amount: Decimal = 2000) -> [Transaction] {
            offsets.map { Transaction(id: UUID(), description: "\(summary) \($0)", date: calendar.date(byAdding: .day, value: $0, to: start)!,
                                      amount: amount, accountID: self.accountID, customSummary: summary) }
        }
        let late = deposits("Late pay", [0, 14, 28, 47, 56, 70, 84, 98])
        let split = deposits("Split pay", [0, 14, 28, 42], 1000) + deposits("Split pay", [0, 14, 28, 42], 1500)
        let moved = deposits("Moved pay", [0, 14, 28, 42, 56, 70]) + deposits("Moved pay", [260, 290, 321, 351, 382, 412, 443])
        let sturdy = RecurrenceDetector(calendar: calendar).detect(in: late + split + moved)
        try self.expect(sturdy.contains { $0.merchant == "Late pay" && $0.cadence == .everyDays(14) },
                        "One late pay among many doesn't hide a fortnightly rhythm")
        try self.expect(sturdy.contains { $0.merchant == "Split pay" && $0.cadence == .everyDays(14) && $0.amount == 2500 },
                        "Pay split into two deposits on one day reads as one payday for their total")
        try self.expect(sturdy.contains { $0.merchant == "Moved pay" && $0.cadence == .everyMonths(1) },
                        "The latest months decide the rhythm after pay moves from fortnightly to monthly")

        // Years of history, but a 3-month chart looks back 3 months, so today falls
        // in the middle rather than near the end; longer horizons look back a year.
        let old = Transaction(id: UUID(), description: "Old", date: calendar.date(byAdding: .year, value: -3, to: today)!,
                              amount: -1, accountID: self.accountID)
        for (horizon, months) in [(ForecastHorizon.threeMonths, 3), (.sixMonths, 6), (.oneYear, 12), (.twoYears, 12)] {
            let chart = forecaster.forecast(startingBalance: 0, transactions: [old], payCycles: [], over: horizon, from: today)
            let back = calendar.date(byAdding: .month, value: -months, to: calendar.startOfDay(for: today))!
            try self.expect(chart.startDate == back && chart.points[chart.todayIndex].date == calendar.startOfDay(for: today),
                            "A \(horizon.title) chart's history runs back \(months) months to today")
        }

        let pattern = SpendingPattern.make(from: rent + shop, asOf: calendar.date(byAdding: .day, value: 21, to: start)!, calendar: calendar)
        try self.expect(pattern.irregularDailyOutflow * Decimal(pattern.observedDays) == 77, "Repeats leave the irregular average; the rest stays in it")
    }

    static func recurrenceRuleChecks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }
        func days(_ offset: Int, from date: Date) -> Date { calendar.date(byAdding: .day, value: offset, to: date)! }

        let monthly = RecurrenceSchedule(amount: -90, cadence: .everyMonths(1), anchor: day(2026, 1, 31))
        try self.expect(monthly.dates(after: day(2026, 1, 31), through: day(2026, 5, 1), calendar: calendar)
                            == [day(2026, 2, 28), day(2026, 3, 31), day(2026, 4, 30)],
                        "Monthly repeats land on the anchor's day, or a short month's last day")
        try self.expect(monthly.dates(after: day(2025, 10, 1), through: day(2025, 12, 1), calendar: calendar)
                            == [day(2025, 10, 31), day(2025, 11, 30)],
                        "A schedule steps back from its anchor as well as forward")

        // Rent of $1,700 a fortnight becomes $1,800 a week from 27 April, then stops on 25 May.
        let start = day(2026, 3, 2)
        let rise = RecurrenceChange(id: UUID(), date: days(56, from: start),
                                    terms: RecurrenceChange.Terms(amount: -1800, cadence: .everyDays(7)))
        let stop = RecurrenceChange(id: UUID(), date: days(84, from: start), terms: nil)
        let plan = RecurrencePlan(schedule: RecurrenceSchedule(amount: -1700, cadence: .everyDays(14), anchor: start),
                                  changes: [stop, rise])
        let planned = plan.occurrences(after: start, through: days(120, from: start), calendar: calendar)
        try self.expect(planned.map(\.date) == [14, 28, 42, 56, 63, 70, 77].map { days($0, from: start) },
                        "A change takes over from its first payment and a stop ends the repeat")
        try self.expect(planned.map(\.amount) == [-1700, -1700, -1700, -1800, -1800, -1800, -1800],
                        "Each payment carries the amount in force on its day")
        try self.expect(plan.next(after: days(50, from: start), calendar: calendar)?.date == days(56, from: start)
                            && plan.next(after: days(80, from: start), calendar: calendar) == nil,
                        "The next payment follows the changes, and there is none once stopped")
        try self.expect(plan.terms(on: days(60, from: start), calendar: calendar)?.cadence == .everyDays(7)
                            && plan.terms(on: days(90, from: start), calendar: calendar) == nil,
                        "The terms in force follow the changes")

        let accountID = UUID()
        func transaction(_ summary: String, _ offset: Int, _ amount: Decimal) -> Transaction {
            Transaction(id: UUID(), description: "\(summary) ref \(offset)", date: days(offset, from: start),
                        amount: amount, accountID: accountID, customSummary: summary)
        }
        let rent = [0, 14, 28, 42].map { transaction("Rent", $0, -1700) }
        let bond = transaction("Rent", 30, -3400)
        let cash = transaction("Cash to landlord", 56, -1700)
        let key = RecurrenceKey(rent[0])
        let finder = RecurrenceFinder(calendar: calendar)
        let found = finder.find(in: rent, rules: [])
        try self.expect(found.first?.key == key && found.first?.isEdited == false, "Untouched repeats are found from the history")

        var rule = RecurrenceRule(key: key, schedule: found[0].plan.schedule)
            .removing(bond).adding([cash.id])
        try rule = rule.settingChange(rise, calendar: calendar)
        try self.rejects("Two changes can't share a day") {
            _ = try rule.settingChange(RecurrenceChange(id: UUID(), date: rise.date, terms: nil), calendar: calendar)
        }
        let later = transaction("Rent", 70, -1700)
        let shaped = finder.find(in: rent + [bond, cash, later], rules: [rule])
        try self.expect(shaped.count == 1 && Set(shaped[0].transactionIDs) == Set((rent + [cash, later]).map(\.id)),
                        "A rule keeps what the user added, leaves out what they removed, and takes in new matches")
        try self.expect(shaped[0].isEdited && shaped[0].plan.schedule.anchor == days(70, from: start)
                            && shaped[0].plan.changes == [rise],
                        "A rule that follows its transactions steps from the newest, with the user's changes")
        let pattern = SpendingPattern.make(from: rent + [bond, cash], rules: [rule], asOf: days(60, from: start), calendar: calendar)
        try self.expect(abs(pattern.irregularDailyOutflow * Decimal(pattern.observedDays) - 3400) < 0.01,
                        "A transaction taken out of a repeat counts as everyday spending again")

        var fixed = rule
        fixed.followsTransactions = false
        fixed.schedule = RecurrenceSchedule(amount: -1650, cadence: .everyMonths(1), anchor: days(90, from: start))
        try self.expect(finder.find(in: rent, rules: [fixed]).first?.plan.schedule == fixed.schedule,
                        "Terms the user set stay as they set them")

        var dismissed = rule
        dismissed.isDismissed = true
        let quiet = SpendingPattern.make(from: rent, rules: [dismissed], asOf: days(60, from: start), calendar: calendar)
        try self.expect(quiet.recurring.isEmpty && abs(quiet.irregularDailyOutflow * Decimal(quiet.observedDays) - 6800) < 0.01,
                        "A repeat the user says isn't one is neither projected nor found again")

        let forecast = BalanceForecaster(calendar: calendar).forecast(
            startingBalance: 10_000, transactions: rent, payCycles: [], recurrenceRules: [rule],
            over: .threeMonths, historyMonths: 1, from: days(43, from: start)
        )
        // From 14 April to 14 July: the change's weekly $1,800 from 27 April, 12 times.
        try self.expect(forecast.expectedOutflow == 1800 * 12, "The forecast projects a rule's changes: \(forecast.expectedOutflow)")

        let suite = "recurrence-store-checks-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RecurrenceStore(defaults: defaults)
        try self.expect(store.rule(for: found[0]) == RecurrenceRule(key: key, schedule: found[0].plan.schedule),
                        "An untouched repeat starts a rule from what was found")
        store.save(rule)
        store.save(fixed)
        try self.expect(store.rules() == [fixed] && store.rule(for: found[0]) == fixed, "One rule is saved per repeat")
        try self.expect(store.rules(forAccounts: [UUID()]).isEmpty, "Rules for other accounts are left out")
        store.delete(key)
        try self.expect(store.rules().isEmpty, "Forgetting a rule finds the repeat afresh")
    }
}
