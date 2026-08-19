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

/// One day on the forecast line.
struct ForecastPoint: Hashable {
    let date: Date
    let balance: Decimal
}

/// A projected balance over time, along with the assumptions that produced it, so
/// a screen can show its workings rather than an unexplained line.
struct Forecast {
    /// One point per day, starting at today's balance.
    let points: [ForecastPoint]
    let horizon: ForecastHorizon
    let startingBalance: Decimal
    /// Total pay expected to land across the whole horizon.
    let expectedIncome: Decimal
    let spending: SpendingPattern

    var projectedBalance: Decimal {
        self.points.last?.balance ?? self.startingBalance
    }

    var change: Decimal {
        self.projectedBalance - self.startingBalance
    }

    var endDate: Date? {
        self.points.last?.date
    }

    var monthlyIncome: Decimal {
        self.expectedIncome / Decimal(self.horizon.months)
    }

    var monthlySpending: Decimal {
        self.spending.monthlyOutflow
    }

    /// What the balance moves by in an average month, which is the slope of the
    /// line the chart draws.
    var monthlyNet: Decimal {
        self.monthlyIncome - self.monthlySpending
    }

    /// The first day the balance is projected to cross below zero, if it does.
    /// Worth surfacing: it's the part of a forecast a user acts on.
    ///
    /// A position that starts in the negative — a card, or a net worth carrying a
    /// mortgage — has nothing to cross, so it reports none rather than flagging
    /// today.
    var shortfallDate: Date? {
        guard self.startingBalance >= 0 else {
            return nil
        }

        return self.points.first { $0.balance < 0 }?.date
    }

    /// A forecast with nothing to project, used before any data is available.
    static func empty(horizon: ForecastHorizon, startingBalance: Decimal = 0) -> Forecast {
        Forecast(
            points: [],
            horizon: horizon,
            startingBalance: startingBalance,
            expectedIncome: 0,
            spending: .none
        )
    }
}

/// Projects a balance forward by crediting each pay cycle on the days it lands and
/// debiting the observed daily spend on every day in between.
///
/// Deliberately simple: no interest, no growth, no change in behaviour, and a loan
/// balance that doesn't amortise — only cash moves. It answers "where does today's
/// pattern take me?", which is what the user can act on, and keeps every number on
/// screen traceable to something they entered or spent.
struct BalanceForecaster {
    private let calendar: Calendar
    private let calculator: NextPayDateCalculator

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        self.calculator = NextPayDateCalculator(calendar: calendar)
    }

    func forecast(
        startingBalance: Decimal,
        payCycles: [PayCycle],
        spending: SpendingPattern,
        over horizon: ForecastHorizon,
        from date: Date = .now
    ) -> Forecast {
        let start = self.calendar.startOfDay(for: date)

        guard let end = self.calendar.date(byAdding: .month, value: horizon.months, to: start) else {
            return .empty(horizon: horizon, startingBalance: startingBalance)
        }

        let income = self.income(from: payCycles, between: start, and: end)

        var points = [ForecastPoint(date: start, balance: startingBalance)]
        var balance = startingBalance
        var expectedIncome = Decimal.zero
        var cursor = start

        // Starts crediting tomorrow: today's balance is what the accounts already
        // report, so pay landing today is in it either way.
        while cursor < end {
            guard let next = self.calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }

            cursor = self.calendar.startOfDay(for: next)
            let credited = income[cursor] ?? 0
            expectedIncome += credited
            balance += credited - spending.dailyOutflow
            points.append(ForecastPoint(date: cursor, balance: balance))
        }

        return Forecast(
            points: points,
            horizon: horizon,
            startingBalance: startingBalance,
            expectedIncome: expectedIncome,
            spending: spending
        )
    }

    /// Pay landing on each day, summed, so several cycles falling on one date read
    /// as a single step in the line.
    private func income(
        from payCycles: [PayCycle],
        between start: Date,
        and end: Date
    ) -> [Date: Decimal] {
        var income: [Date: Decimal] = [:]

        for cycle in payCycles where cycle.isEnabled && cycle.amount != 0 {
            for payDate in self.calculator.payDates(for: cycle, from: start, to: end) {
                income[payDate, default: 0] += cycle.amount
            }
        }

        return income
    }
}
