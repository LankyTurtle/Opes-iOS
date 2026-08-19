import Foundation

struct NextPayDateCalculator {
    private var calendar: Calendar
    private let holidays: AustralianPublicHolidayProvider

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        self.holidays = AustralianPublicHolidayProvider(calendar: calendar)
    }

    func nextPayDate(for cycle: PayCycle, from date: Date = .now) -> Date? {
        let start = self.calendar.startOfDay(for: date)
        // A backward adjustment can pull a forthcoming nominal date into the
        // current week, so include a short history when evaluating candidates.
        guard let first = self.calendar.date(byAdding: .day, value: -7, to: start),
              let limit = self.calendar.date(byAdding: .year, value: 6, to: start) else {
            return nil
        }

        var cursor = first
        var next: Date?
        while cursor <= limit {
            if self.isNominalPayDay(cursor, for: cycle) {
                let effective = self.adjusted(cursor, for: cycle)
                if effective >= start, next == nil || effective < next! {
                    next = effective
                }
            }
            cursor = self.calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return next
    }

    /// Every effective pay date the cycle lands on between `start` and `end`,
    /// inclusive, so a forecast can credit income on the same days the tracker
    /// counts down to.
    ///
    /// A business-day adjustment can pull a nominal date from just outside the
    /// window into it, so the scan runs a little wider than the window itself.
    func payDates(for cycle: PayCycle, from start: Date, to end: Date) -> [Date] {
        let first = self.calendar.startOfDay(for: start)
        let last = self.calendar.startOfDay(for: end)

        guard
            first <= last,
            var cursor = self.calendar.date(byAdding: .day, value: -7, to: first),
            let limit = self.calendar.date(byAdding: .day, value: 7, to: last)
        else {
            return []
        }

        var dates: [Date] = []
        while cursor <= limit {
            if self.isNominalPayDay(cursor, for: cycle) {
                let effective = self.calendar.startOfDay(for: self.adjusted(cursor, for: cycle))
                if effective >= first, effective <= last {
                    dates.append(effective)
                }
            }
            cursor = self.calendar.date(byAdding: .day, value: 1, to: cursor)!
        }

        return dates.sorted()
    }

    func display(for cycle: PayCycle, from date: Date = .now) -> PayCycleDateDisplay? {
        guard let next = self.nextPayDate(for: cycle, from: date) else { return nil }
        let start = self.calendar.startOfDay(for: date)
        let days = self.calendar.dateComponents([.day], from: start, to: next).day ?? 0
        let countdown: String
        switch days {
        case 0: countdown = "Today"
        case 1: countdown = "Tomorrow"
        default: countdown = "In \(days) days"
        }
        return PayCycleDateDisplay(date: next, countdown: countdown)
    }

    private func isNominalPayDay(_ date: Date, for cycle: PayCycle) -> Bool {
        let components = self.calendar.dateComponents([.month, .day, .weekday], from: date)
        switch cycle.frequency {
        case .daily:
            return true
        case .weekly:
            switch cycle.rule.kind {
            case .firstDay: return components.weekday == self.calendar.firstWeekday
            case .lastDay: return components.weekday == ((self.calendar.firstWeekday + 5) % 7) + 1
            case .specific: return components.weekday == (cycle.rule.weekday ?? self.calendar.firstWeekday)
            }
        case .monthly:
            let lastDay = self.calendar.range(of: .day, in: .month, for: date)!.count
            switch cycle.rule.kind {
            case .firstDay: return components.day == 1
            case .lastDay: return components.day == lastDay
            case .specific: return components.day == min(max(cycle.rule.day ?? 1, 1), lastDay)
            }
        case .yearly:
            let lastDay = self.calendar.range(of: .day, in: .month, for: date)!.count
            switch cycle.rule.kind {
            case .firstDay: return components.month == 1 && components.day == 1
            case .lastDay: return components.month == 12 && components.day == 31
            case .specific:
                let month = min(max(cycle.rule.month ?? 1, 1), 12)
                return components.month == month && components.day == min(max(cycle.rule.day ?? 1, 1), lastDay)
            }
        }
    }

    private func adjusted(_ date: Date, for cycle: PayCycle) -> Date {
        guard cycle.businessDayAdjustment != .none else { return date }
        var candidate = date
        let direction = cycle.businessDayAdjustment == .previousBusinessDay ? -1 : 1
        while self.calendar.isDateInWeekend(candidate) || self.holidays.isPublicHoliday(candidate, in: cycle.stateOrTerritory) {
            candidate = self.calendar.date(byAdding: .day, value: direction, to: candidate)!
        }
        return candidate
    }
}

struct PayCycleDateDisplay {
    let date: Date
    let countdown: String
}
