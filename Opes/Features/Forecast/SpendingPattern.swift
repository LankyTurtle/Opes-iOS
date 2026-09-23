import Foundation

/// What the past year says about how money actually moves, so a forecast can
/// replay it rather than draw a straight line at the average.
///
/// Two parts, because spending has two shapes. Bills and pay repeat on a date and
/// are projected onto those dates. Everything else — groceries, coffee, a tank of
/// fuel — is irregular, and is carried forward as a daily average that keeps the
/// weekday shape it was observed with, so weekends stay heavier than Tuesdays.
///
/// Transfers are the known gap: money moved out of one of the user's own accounts
/// reads as spending, which is right for that account's own forecast but overstates
/// it across the whole net worth. Categorised transfers can net themselves out once
/// transactions carry a category.
struct SpendingPattern: Hashable {
    /// Detected repeats, income and outgoing alike.
    let recurring: [RecurringTransaction]
    /// Average money out per day for everything that isn't recurring, by weekday.
    let irregularOutflowByWeekday: [Int: Decimal]
    /// The same, flattened across all days.
    let irregularDailyOutflow: Decimal
    let observedDays: Int
    let observedOutflow: Decimal

    static let none = SpendingPattern(
        recurring: [],
        irregularOutflowByWeekday: [:],
        irregularDailyOutflow: 0,
        observedDays: 0,
        observedOutflow: 0
    )

    var hasHistory: Bool {
        self.observedDays > 0 && self.observedOutflow > 0
    }

    /// What to take out on a given weekday, which is what makes the projected line
    /// move day to day instead of sloping.
    func irregularOutflow(onWeekday weekday: Int) -> Decimal {
        self.irregularOutflowByWeekday[weekday] ?? self.irregularDailyOutflow
    }

    /// Drops repeats that a pay cycle already accounts for, so pay isn't counted
    /// once from the schedule the user entered and again from the deposit it left
    /// behind.
    ///
    /// Matched on the linked transaction's summary where the user set one, and on
    /// the cycle's own name otherwise — which is what someone naming a cycle
    /// "Salary" would expect.
    func withoutIncome(coveredBy payCycles: [PayCycle], in transactions: [Transaction]) -> SpendingPattern {
        let covered = Set(
            payCycles.lazy
                .filter(\.isEnabled)
                .flatMap { cycle -> [String] in
                    let linked = transactions.first { $0.id == cycle.linkedTransactionID }
                    return [linked?.summary, cycle.name]
                        .compactMap { $0?.lowercased() }
                }
        )

        guard !covered.isEmpty else {
            return self
        }

        return SpendingPattern(
            recurring: self.recurring.filter { !$0.isIncome || !covered.contains($0.merchant.lowercased()) },
            irregularOutflowByWeekday: self.irregularOutflowByWeekday,
            irregularDailyOutflow: self.irregularDailyOutflow,
            observedDays: self.observedDays,
            observedOutflow: self.observedOutflow
        )
    }

    /// Averages over the window the transactions themselves cover — from the oldest
    /// one to today — rather than a fixed number of days, so a short history isn't
    /// diluted by days that were never observed.
    static func make(
        from transactions: [Transaction],
        rules: [RecurrenceRule] = [],
        asOf date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> SpendingPattern {
        let today = calendar.startOfDay(for: date)
        let observed = transactions.filter { $0.date <= date }

        guard let earliest = observed.map(\.date).min() else {
            return .none
        }

        let firstDay = calendar.startOfDay(for: earliest)
        let elapsed = calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0
        // The oldest day is one observed day, not zero.
        let days = max(elapsed + 1, 1)

        let recurring = RecurrenceFinder(calendar: calendar).find(in: observed, rules: rules)
        let recurringIDs = Set(recurring.flatMap(\.transactionIDs))

        let irregularOutflows = observed.filter {
            $0.amount < 0 && !recurringIDs.contains($0.id)
        }
        let totalOutflow = observed.reduce(Decimal.zero) { $0 - min($1.amount, 0) }
        let irregularTotal = irregularOutflows.reduce(Decimal.zero) { $0 - $1.amount }

        return SpendingPattern(
            recurring: recurring,
            irregularOutflowByWeekday: self.outflowByWeekday(
                irregularOutflows,
                from: firstDay,
                to: today,
                calendar: calendar
            ),
            irregularDailyOutflow: irregularTotal / Decimal(days),
            observedDays: days,
            observedOutflow: totalOutflow
        )
    }

    /// Divides each weekday's total by how many of that weekday the window actually
    /// held, so a window that ends mid-week doesn't understate its last few days.
    private static func outflowByWeekday(
        _ outflows: [Transaction],
        from first: Date,
        to last: Date,
        calendar: Calendar
    ) -> [Int: Decimal] {
        var totals: [Int: Decimal] = [:]
        var counts: [Int: Int] = [:]

        for outflow in outflows {
            let weekday = calendar.component(.weekday, from: outflow.date)
            totals[weekday, default: 0] -= outflow.amount
        }

        var cursor = first
        while cursor <= last {
            counts[calendar.component(.weekday, from: cursor), default: 0] += 1

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }

            cursor = calendar.startOfDay(for: next)
        }

        return totals.reduce(into: [Int: Decimal]()) { result, entry in
            let observed = counts[entry.key] ?? 0
            result[entry.key] = observed > 0 ? entry.value / Decimal(observed) : 0
        }
    }
}

/// Finds merchants whose transactions arrive at a steady interval.
///
/// Money in and money out are looked at separately, even under the same name, so a
/// transfer that goes both ways doesn't hide either direction.
///
/// Deliberately conservative: three occurrences at a consistent gap before
/// anything is called recurring, so a fortnight of groceries at the same shop
/// isn't projected forward as a subscription. Whatever it misses still counts
/// towards the irregular daily average, so nothing is lost — it just moves as a
/// trend rather than as a dated charge.
struct RecurrenceDetector {
    private let calendar: Calendar

    /// The gaps a bill or a pay run realistically falls on. Anything longer is left
    /// to the average, because a year of history can't confirm it.
    private static let intervalRange = 5...45
    private static let minimumOccurrences = 3

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func detect(in transactions: [Transaction]) -> [RecurringTransaction] {
        Dictionary(grouping: transactions.filter { $0.amount != 0 }, by: RecurrenceKey.init)
            .compactMap { key, group in
                self.recurrence(for: key, in: group)
            }
            .sorted { abs($0.monthlyAmount) > abs($1.monthlyAmount) }
    }

    /// The terms a set of transactions points to, without asking whether they're
    /// regular enough to be called a repeat: the typical gap and amount, stepping
    /// from the most recent. For a repeat the user has shaped, where they've
    /// already said which transactions belong.
    func fit(_ group: [Transaction]) -> RecurrenceSchedule? {
        let days = group.map { self.calendar.startOfDay(for: $0.date) }.sorted()
        let gaps = zip(days, days.dropFirst()).map { earlier, later in
            self.calendar.dateComponents([.day], from: earlier, to: later).day ?? 0
        }
        guard let interval = Self.median(of: gaps), interval > 0,
              let amount = Self.median(of: group.map(\.amount)), let last = days.last else {
            return nil
        }
        return RecurrenceSchedule(amount: amount, cadence: .fitting(days: interval), anchor: last)
    }

    private func recurrence(
        for key: RecurrenceKey,
        in group: [Transaction]
    ) -> RecurringTransaction? {
        guard group.count >= Self.minimumOccurrences else {
            return nil
        }

        let days = group
            .map { self.calendar.startOfDay(for: $0.date) }
            .sorted()
        let gaps = zip(days, days.dropFirst()).map { earlier, later in
            self.calendar.dateComponents([.day], from: earlier, to: later).day ?? 0
        }

        guard
            let interval = Self.median(of: gaps),
            Self.intervalRange.contains(interval)
        else {
            return nil
        }

        // Every gap has to sit near the median. A month is the wide case: 28 to 31
        // days is regular, and a bill paid a couple of days late still is.
        let tolerance = max(3, interval / 4)
        guard gaps.allSatisfy({ abs($0 - interval) <= tolerance }) else {
            return nil
        }

        let amounts = group.map(\.amount)
        guard let typical = Self.median(of: amounts) else {
            return nil
        }

        // Charges have to be recognisably the same amount, or this is just a shop
        // the user visits on a rhythm. Money in arriving on a schedule is already
        // regular — pay with overtime, interest — so only its timing has to hold.
        let drift = amounts.map { abs($0 - typical) }.max() ?? 0
        guard key.isIncome || drift <= abs(typical) / 5 else {
            return nil
        }

        guard let last = days.last else {
            return nil
        }

        let members = group.sorted { $0.date < $1.date }
        return RecurringTransaction(
            key: key,
            plan: RecurrencePlan(schedule: RecurrenceSchedule(
                amount: typical, cadence: .fitting(days: interval), anchor: last
            )),
            transactionIDs: members.map(\.id),
            evidence: RecurrenceEvidence(members, calendar: self.calendar),
            isEdited: false,
            followsTransactions: true
        )
    }

    private static func median<Value: Comparable>(of values: [Value]) -> Value? {
        guard !values.isEmpty else {
            return nil
        }

        // The middle value rather than the mean, so one unusual month doesn't drag
        // the interval or the amount off the figure every other occurrence agrees on.
        return values.sorted()[values.count / 2]
    }
}
