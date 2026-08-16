import Foundation

/// Calendar data is isolated here so gazetted state exceptions can be added
/// without touching pay-cycle calculations. The rules cover national holidays
/// and the recurring state/territory holidays used by the tracker.
struct AustralianPublicHolidayProvider {
    private var calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func isPublicHoliday(_ date: Date, in region: AustralianStateOrTerritory) -> Bool {
        self.holidays(in: region, year: self.calendar.component(.year, from: date))
            .contains(self.calendar.startOfDay(for: date))
    }

    func holidays(in region: AustralianStateOrTerritory, year: Int) -> Set<Date> {
        var dates = Set<Date>()
        func add(_ month: Int, _ day: Int) {
            dates.insert(self.date(year: year, month: month, day: day))
        }
        func addMonday(_ month: Int, _ ordinal: Int) {
            dates.insert(self.nthWeekday(year: year, month: month, weekday: 2, ordinal: ordinal))
        }

        // National holidays and their common observed days.
        add(1, 1)
        self.addObservedFixedHoliday(month: 1, day: 1, year: year, to: &dates)
        add(1, 26)
        self.addObservedFixedHoliday(month: 1, day: 26, year: year, to: &dates)
        let easter = Self.easterSunday(year: year, calendar: self.calendar)
        dates.insert(self.calendar.date(byAdding: .day, value: -2, to: easter)!)
        dates.insert(self.calendar.date(byAdding: .day, value: 1, to: easter)!)
        add(4, 25) // Anzac Day; substitute arrangements vary by jurisdiction.
        self.addChristmasAndBoxingDays(year: year, to: &dates)

        switch region {
        case .australianCapitalTerritory:
            addMonday(3, 2) // Canberra Day
            let kingsBirthday = self.nthWeekday(year: year, month: 6, weekday: 2, ordinal: 2)
            if let reconciliationDay = self.calendar.date(byAdding: .day, value: -7, to: kingsBirthday) {
                dates.insert(self.calendar.startOfDay(for: reconciliationDay))
            }
            dates.insert(kingsBirthday)
            addMonday(10, 1) // Labour Day
        case .newSouthWales:
            addMonday(6, 2) // King's Birthday
            addMonday(10, 1) // Labour Day
        case .northernTerritory:
            addMonday(5, 1) // May Day
            addMonday(6, 2) // King's Birthday
            addMonday(8, 1) // Picnic Day
        case .queensland:
            addMonday(5, 1) // Labour Day
            addMonday(10, 1) // King's Birthday
        case .southAustralia:
            addMonday(3, 2) // Adelaide Cup (gazetted exceptions are supported below)
            addMonday(6, 2) // King's Birthday
            addMonday(10, 1) // Labour Day
        case .tasmania:
            addMonday(3, 2) // Eight Hours Day
            addMonday(6, 2) // King's Birthday
        case .victoria:
            addMonday(3, 2) // Labour Day
            addMonday(6, 2) // King's Birthday
            dates.insert(self.fridayBeforeLastMonday(year: year, month: 9)) // AFL Grand Final eve
            dates.insert(self.nthWeekday(year: year, month: 11, weekday: 3, ordinal: 1)) // Melbourne Cup
        case .westernAustralia:
            addMonday(3, 1) // Labour Day
            addMonday(6, 1) // WA Day
        }

        for override in Self.gazettedOverrides[year]?[region] ?? [] {
            dates.insert(self.date(year: year, month: override.month, day: override.day))
        }
        return dates
    }

    // Exceptional, one-off gazetted dates belong here. Keeping these values
    // data-driven makes annual updates small and auditable.
    private static let gazettedOverrides: [Int: [AustralianStateOrTerritory: [(month: Int, day: Int)]]] = [:]

    private func date(year: Int, month: Int, day: Int) -> Date {
        self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func nthWeekday(year: Int, month: Int, weekday: Int, ordinal: Int) -> Date {
        let first = self.date(year: year, month: month, day: 1)
        let offset = (weekday - self.calendar.component(.weekday, from: first) + 7) % 7
        return self.calendar.startOfDay(for: self.calendar.date(byAdding: .day, value: offset + (ordinal - 1) * 7, to: first)!)
    }

    private func fridayBeforeLastMonday(year: Int, month: Int) -> Date {
        let lastDay = self.calendar.date(byAdding: DateComponents(month: 1, day: -1), to: self.date(year: year, month: month, day: 1))!
        let weekday = self.calendar.component(.weekday, from: lastDay)
        let daysBackToMonday = (weekday - 2 + 7) % 7
        let lastMonday = self.calendar.date(byAdding: .day, value: -daysBackToMonday, to: lastDay)!
        return self.calendar.startOfDay(for: self.calendar.date(byAdding: .day, value: -3, to: lastMonday)!)
    }

    private func addObservedFixedHoliday(month: Int, day: Int, year: Int, to dates: inout Set<Date>) {
        let actual = self.date(year: year, month: month, day: day)
        switch self.calendar.component(.weekday, from: actual) {
        case 7: dates.insert(self.calendar.date(byAdding: .day, value: 2, to: actual)!)
        case 1: dates.insert(self.calendar.date(byAdding: .day, value: 1, to: actual)!)
        default: break
        }
    }

    private func addChristmasAndBoxingDays(year: Int, to dates: inout Set<Date>) {
        let christmas = self.date(year: year, month: 12, day: 25)
        let boxingDay = self.date(year: year, month: 12, day: 26)
        dates.insert(christmas)
        dates.insert(boxingDay)
        switch self.calendar.component(.weekday, from: christmas) {
        case 7: // Saturday
            dates.insert(self.calendar.date(byAdding: .day, value: 2, to: christmas)!)
            dates.insert(self.calendar.date(byAdding: .day, value: 2, to: boxingDay)!)
        case 1: // Sunday; Monday is Boxing Day already
            dates.insert(self.calendar.date(byAdding: .day, value: 2, to: christmas)!)
        default: break
        }
    }

    private static func easterSunday(year: Int, calendar: Calendar) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
