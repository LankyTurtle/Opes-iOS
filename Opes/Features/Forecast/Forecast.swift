import Foundation

/// How far ahead a forecast runs. The user picks one.
enum ForecastHorizon: String, CaseIterable, Hashable {
    case threeMonths
    case sixMonths
    case oneYear
    case twoYears

    /// Short enough for a segmented control.
    var title: String {
        switch self {
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .oneYear: "1Y"
        case .twoYears: "2Y"
        }
    }

    /// Reads as a period in a sentence: "in 6 months".
    var description: String {
        switch self {
        case .threeMonths: "3 months"
        case .sixMonths: "6 months"
        case .oneYear: "1 year"
        case .twoYears: "2 years"
        }
    }

    var months: Int {
        switch self {
        case .threeMonths: 3
        case .sixMonths: 6
        case .oneYear: 12
        case .twoYears: 24
        }
    }

    static let `default` = ForecastHorizon.oneYear
}

/// One day on the line.
struct ForecastPoint: Hashable {
    let date: Date
    let balance: Decimal
}

/// Where a balance has been and where today's patterns take it, along with the
/// assumptions behind the projection so a screen can show its workings rather than
/// an unexplained line.
struct Forecast {
    /// One point per day, oldest first: reconstructed history up to today, then the
    /// projection. `todayIndex` is where one becomes the other.
    let points: [ForecastPoint]
    let todayIndex: Int
    let horizon: ForecastHorizon
    let startingBalance: Decimal
    /// Everything expected to land across the whole horizon.
    let expectedIncome: Decimal
    /// Everything expected to go out across it, as a positive amount.
    let expectedOutflow: Decimal
    let spending: SpendingPattern

    var projectedBalance: Decimal {
        self.points.last?.balance ?? self.startingBalance
    }

    var change: Decimal {
        self.projectedBalance - self.startingBalance
    }

    var startDate: Date? {
        self.points.first?.date
    }

    var endDate: Date? {
        self.points.last?.date
    }

    /// The points ahead of today, which the chart draws as an estimate rather than
    /// as the fact behind them.
    var projectedPoints: ArraySlice<ForecastPoint> {
        self.points.isEmpty ? [] : self.points[self.todayIndex...]
    }

    /// Averaged across the horizon rather than taken from the pattern directly, so
    /// the figures on screen are the ones the line was actually drawn from.
    var monthlyIncome: Decimal {
        self.expectedIncome / Decimal(self.horizon.months)
    }

    var monthlySpending: Decimal {
        self.expectedOutflow / Decimal(self.horizon.months)
    }

    /// What the balance moves by in an average month, which is the trend under the
    /// week-to-week movement the chart shows.
    var monthlyNet: Decimal {
        self.monthlyIncome - self.monthlySpending
    }

    /// The first day ahead that the balance is projected to cross below zero.
    /// Worth surfacing: it's the part of a forecast a user acts on.
    ///
    /// A position that starts in the negative — a card, or a net worth carrying a
    /// mortgage — has nothing to cross, so it reports none rather than flagging
    /// today.
    var shortfallDate: Date? {
        guard self.startingBalance >= 0 else {
            return nil
        }

        return self.projectedPoints.first { $0.balance < 0 }?.date
    }

    /// A forecast with nothing to project, used before any data is available.
    static func empty(horizon: ForecastHorizon, startingBalance: Decimal = 0) -> Forecast {
        Forecast(
            points: [],
            todayIndex: 0,
            horizon: horizon,
            startingBalance: startingBalance,
            expectedIncome: 0,
            expectedOutflow: 0,
            spending: .none
        )
    }
}

/// Replays the way money has actually moved, forward.
///
/// Repeats found in the history — pay, rent, subscriptions — are placed on the
/// dates they'll next fall on, and the pay cycles the user entered are credited on
/// theirs. What's left over, the irregular day-to-day spending, is carried forward
/// as a daily average that keeps its weekday shape. So the line steps and dips the
/// way a statement does instead of sloping at one rate.
///
/// What it deliberately doesn't do: interest, growth, inflation, or any change in
/// behaviour, and a loan balance doesn't amortise — only cash moves. It answers
/// "where does the way I live now take me?", and every number on screen traces back
/// to something the user entered or spent.
struct BalanceForecaster {
    private let calendar: Calendar
    private let calculator: NextPayDateCalculator

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        self.calculator = NextPayDateCalculator(calendar: calendar)
    }

    /// Builds the whole line — history then projection — for one position.
    ///
    /// `transactions` and `payCycles` are expected to be narrowed to the position
    /// already: one account's, or every account's for a net worth.
    func forecast(
        startingBalance: Decimal,
        transactions: [Transaction],
        payCycles: [PayCycle],
        over horizon: ForecastHorizon,
        historyMonths: Int = 12,
        from date: Date = .now
    ) -> Forecast {
        let start = self.calendar.startOfDay(for: date)

        guard let end = self.calendar.date(byAdding: .month, value: horizon.months, to: start) else {
            return .empty(horizon: horizon, startingBalance: startingBalance)
        }

        let spending = SpendingPattern
            .make(from: transactions, asOf: date, calendar: self.calendar)
            .withoutIncome(coveredBy: payCycles, in: transactions)

        let history = BalanceHistory.points(
            endingAt: startingBalance,
            transactions: transactions,
            over: historyMonths,
            asOf: date,
            calendar: self.calendar
        )

        let projection = self.project(
            from: start,
            to: end,
            startingBalance: startingBalance,
            payCycles: payCycles,
            spending: spending
        )

        // History ends on today and the projection starts there, so the shared point
        // is dropped from one of them.
        return Forecast(
            points: history + projection.points.dropFirst(),
            todayIndex: max(history.count - 1, 0),
            horizon: horizon,
            startingBalance: startingBalance,
            expectedIncome: projection.income,
            expectedOutflow: projection.outflow,
            spending: spending
        )
    }

    private func project(
        from start: Date,
        to end: Date,
        startingBalance: Decimal,
        payCycles: [PayCycle],
        spending: SpendingPattern
    ) -> (points: [ForecastPoint], income: Decimal, outflow: Decimal) {
        let scheduled = self.scheduledMovements(
            payCycles: payCycles,
            recurring: spending.recurring,
            from: start,
            to: end
        )

        var points = [ForecastPoint(date: start, balance: startingBalance)]
        var balance = startingBalance
        var income = Decimal.zero
        var outflow = Decimal.zero
        var cursor = start

        // Starts crediting tomorrow: today's balance is what the accounts already
        // report, so anything landing today is in it either way.
        while cursor < end {
            guard let next = self.calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }

            cursor = self.calendar.startOfDay(for: next)

            let dated = scheduled[cursor] ?? []
            let irregular = spending.irregularOutflow(
                onWeekday: self.calendar.component(.weekday, from: cursor)
            )

            for movement in dated where movement > 0 {
                income += movement
            }

            // The irregular average, plus the outgoing half of anything dated.
            outflow += dated.reduce(irregular) { $0 - min($1, 0) }
            balance += dated.reduce(Decimal.zero) { $0 + $1 } - irregular

            points.append(ForecastPoint(date: cursor, balance: balance))
        }

        return (points, income, outflow)
    }

    /// Everything with a date of its own — pay cycles and detected repeats — landed
    /// on the days it falls, signed the way it moves the balance.
    private func scheduledMovements(
        payCycles: [PayCycle],
        recurring: [RecurringTransaction],
        from start: Date,
        to end: Date
    ) -> [Date: [Decimal]] {
        var movements: [Date: [Decimal]] = [:]

        for cycle in payCycles where cycle.isEnabled && cycle.amount != 0 {
            for payDate in self.calculator.payDates(for: cycle, from: start, to: end) {
                movements[payDate, default: []].append(cycle.amount)
            }
        }

        for item in recurring {
            for date in self.occurrences(of: item, after: start, through: end) {
                movements[date, default: []].append(item.amount)
            }
        }

        return movements
    }

    /// When a detected repeat next lands, projected from where it last did.
    private func occurrences(
        of item: RecurringTransaction,
        after start: Date,
        through end: Date
    ) -> [Date] {
        var dates: [Date] = []

        switch item.cadence {
        case .everyDays(let interval):
            var cursor = self.calendar.startOfDay(for: item.lastOccurrence)

            // A repeat last seen months ago still steps forward on its own interval
            // rather than restarting today.
            while cursor <= end {
                if cursor > start {
                    dates.append(cursor)
                }

                guard
                    let next = self.calendar.date(byAdding: .day, value: interval, to: cursor)
                else {
                    break
                }

                cursor = self.calendar.startOfDay(for: next)
            }

        case .monthly(let day):
            let months = self.calendar.dateComponents([.month], from: start, to: end).month ?? 0

            for offset in 0...(months + 1) {
                guard
                    let month = self.calendar.date(byAdding: .month, value: offset, to: start),
                    let length = self.calendar.range(of: .day, in: .month, for: month)?.count
                else {
                    continue
                }

                var components = self.calendar.dateComponents([.year, .month], from: month)
                components.day = min(day, length)

                guard
                    let occurrence = self.calendar.date(from: components).map(
                        self.calendar.startOfDay(for:)
                    ),
                    occurrence > start,
                    occurrence <= end
                else {
                    continue
                }

                dates.append(occurrence)
            }
        }

        return dates
    }
}
