import Foundation

/// How often a repeat lands.
enum RecurrenceCadence: Codable, Hashable {
    /// A steady gap in days: weekly, fortnightly, or anything else regular.
    case everyDays(Int)
    /// On the same day of the month as the schedule's anchor, every so many months.
    /// Short months land on their last day.
    case everyMonths(Int)

    /// The rhythms offered when the user sets one.
    static let choices: [RecurrenceCadence] = [
        .everyDays(7), .everyDays(14), .everyDays(28), .everyMonths(1), .everyMonths(3), .everyMonths(12),
    ]

    /// The rhythm a typical gap between transactions reads as. A month is 28 to 31
    /// days, and a bill paid a few days late is still monthly.
    static func fitting(days: Int) -> RecurrenceCadence {
        switch days {
        case 26...35: .everyMonths(1)
        case 80...100: .everyMonths(3)
        case 350...380: .everyMonths(12)
        default: .everyDays(max(days, 1))
        }
    }

    /// Roughly how many times a year it lands, for a monthly average.
    var occurrencesPerYear: Decimal {
        switch self {
        case .everyDays(let interval): Decimal(365) / Decimal(max(interval, 1))
        case .everyMonths(let interval): Decimal(12) / Decimal(max(interval, 1))
        }
    }

    var description: String {
        switch self {
        case .everyDays(7): "weekly"
        case .everyDays(14): "fortnightly"
        case .everyDays(28): "every 4 weeks"
        case .everyDays(1): "daily"
        case .everyDays(let interval): "every \(interval) days"
        case .everyMonths(1): "monthly"
        case .everyMonths(3): "quarterly"
        case .everyMonths(12): "yearly"
        case .everyMonths(let interval): "every \(interval) months"
        }
    }

    /// The `index`th occurrence counted from `anchor`, which may be before it.
    /// Months are always counted from the anchor, so the 31st stays the 31st
    /// after a short month rather than drifting to the 28th.
    func date(_ index: Int, from anchor: Date, calendar: Calendar) -> Date? {
        switch self {
        case .everyDays(let interval): calendar.date(byAdding: .day, value: index * max(interval, 1), to: anchor)
        case .everyMonths(let interval): calendar.date(byAdding: .month, value: index * max(interval, 1), to: anchor)
        }
    }

    /// Days per step, rounded so a first guess at an index never overshoots.
    fileprivate func stepDays(forward: Bool) -> Int {
        switch self {
        case .everyDays(let interval): max(interval, 1)
        case .everyMonths(let interval): max(interval, 1) * (forward ? 31 : 28)
        }
    }
}

/// The terms a repeat lands on: how much, how often, and a day it falls on.
struct RecurrenceSchedule: Codable, Hashable {
    /// Signed the way it moves the balance: negative for money out.
    var amount: Decimal
    var cadence: RecurrenceCadence
    /// Any day it falls on. Every other occurrence steps from here, both ways.
    var anchor: Date

    /// Every day it falls on after `start`, up to and including `end`.
    func dates(after start: Date, through end: Date, calendar: Calendar) -> [Date] {
        let anchor = calendar.startOfDay(for: self.anchor)
        let offset = calendar.dateComponents([.day], from: anchor, to: start).day ?? 0
        let step = self.cadence.stepDays(forward: offset >= 0)
        // Floor division, less one, starts at or before the first occurrence
        // that's wanted; the loop skips forward from there.
        var index = Int((Double(offset) / Double(step)).rounded(.down)) - 1
        var dates: [Date] = []
        for _ in 0..<10_000 {
            guard let date = self.cadence.date(index, from: anchor, calendar: calendar).map(calendar.startOfDay(for:)),
                  date <= end else { break }
            if date > start { dates.append(date) }
            index += 1
        }
        return dates
    }
}

/// A change the user has set from a future day: the repeat stops, or carries on
/// under new terms.
struct RecurrenceChange: Codable, Hashable, Identifiable {
    struct Terms: Codable, Hashable {
        /// Signed like the schedule's.
        var amount: Decimal
        var cadence: RecurrenceCadence
    }

    let id: UUID
    /// The first day it applies. For new terms, the first payment on them, which
    /// also sets the days that follow.
    var date: Date
    /// Nil stops the repeat from `date`.
    var terms: Terms?

    var schedule: RecurrenceSchedule? {
        self.terms.map { RecurrenceSchedule(amount: $0.amount, cadence: $0.cadence, anchor: self.date) }
    }
}

/// A schedule and the changes set against it: everything needed to say when a
/// repeat lands and for how much.
struct RecurrencePlan: Hashable {
    struct Occurrence: Hashable {
        let date: Date
        let amount: Decimal
        let cadence: RecurrenceCadence
    }

    var schedule: RecurrenceSchedule
    /// Sorted by date.
    var changes: [RecurrenceChange]

    init(schedule: RecurrenceSchedule, changes: [RecurrenceChange] = []) {
        self.schedule = schedule
        self.changes = changes.sorted { $0.date < $1.date }
    }

    /// Every payment after `start`, up to and including `end`. Each change takes
    /// over from its own day until the next one does.
    func occurrences(after start: Date, through end: Date, calendar: Calendar) -> [Occurrence] {
        var segments: [(from: Date?, schedule: RecurrenceSchedule?)] = [(nil, self.schedule)]
        segments += self.changes.map { (calendar.startOfDay(for: $0.date), $0.schedule) }
        var result: [Occurrence] = []
        for (index, segment) in segments.enumerated() {
            guard let schedule = segment.schedule else { continue }
            let until = index + 1 < segments.count ? segments[index + 1].from : nil
            result += schedule.dates(after: start, through: end, calendar: calendar)
                .filter { date in segment.from.map { date >= $0 } ?? true && until.map { date < $0 } ?? true }
                .map { Occurrence(date: $0, amount: schedule.amount, cadence: schedule.cadence) }
        }
        return result
    }

    /// The next payment after `date`, looking up to five years ahead.
    func next(after date: Date, calendar: Calendar) -> Occurrence? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .year, value: 5, to: start) else { return nil }
        return self.occurrences(after: start, through: end, calendar: calendar).first
    }

    /// The terms in force on `date`, or nil once a change has stopped it.
    func terms(on date: Date, calendar: Calendar) -> RecurrenceChange.Terms? {
        let day = calendar.startOfDay(for: date)
        guard let change = self.changes.last(where: { calendar.startOfDay(for: $0.date) <= day }) else {
            return RecurrenceChange.Terms(amount: self.schedule.amount, cadence: self.schedule.cadence)
        }
        return change.terms
    }
}

/// Names one repeat: the account, the summary its transactions share, and which
/// way the money moves. A transfer in and a transfer out under the same summary
/// are different repeats.
struct RecurrenceKey: Codable, Hashable {
    let accountID: UUID
    let name: String
    let isIncome: Bool

    init(accountID: UUID, name: String, isIncome: Bool) {
        self.accountID = accountID
        self.name = name
        self.isIncome = isIncome
    }

    init(_ transaction: Transaction) {
        self.init(accountID: transaction.accountID, name: transaction.summary, isIncome: transaction.amount > 0)
    }
}

/// What a repeat was read from, so the screen can say why it was called one.
struct RecurrenceEvidence: Hashable {
    let count: Int
    /// Days between consecutive transactions.
    let gaps: ClosedRange<Int>?
    /// Signed amounts, lowest to highest.
    let amounts: ClosedRange<Decimal>?
    let last: Date?

    init(_ transactions: [Transaction], calendar: Calendar) {
        let days = transactions.map { calendar.startOfDay(for: $0.date) }.sorted()
        let gaps = zip(days, days.dropFirst()).map { calendar.dateComponents([.day], from: $0, to: $1).day ?? 0 }
        let amounts = transactions.map(\.amount)
        self.count = transactions.count
        self.gaps = gaps.min().flatMap { low in gaps.max().map { low...$0 } }
        self.amounts = amounts.min().flatMap { low in amounts.max().map { low...$0 } }
        self.last = days.last
    }
}

/// The user's own say over a repeat, saved once they change anything about it.
///
/// Transactions on the account with the repeat's summary and direction belong to
/// it, so a new month's rent joins by itself, apart from any the user took out;
/// ones the user added belong whatever their summary.
struct RecurrenceRule: Codable, Hashable {
    let key: RecurrenceKey
    /// The terms last worked out or set. Used as they are unless
    /// `followsTransactions`, when they're only the fallback for too few
    /// transactions to work them out from.
    var schedule: RecurrenceSchedule
    /// Whether the amount and dates keep coming from the transactions, or stay
    /// as the user set them.
    var followsTransactions: Bool
    var changes: [RecurrenceChange]
    var addedTransactionIDs: Set<UUID>
    var removedTransactionIDs: Set<UUID>
    /// The user said it isn't a repeat: nothing is projected, and it isn't found again.
    var isDismissed: Bool

    init(key: RecurrenceKey, schedule: RecurrenceSchedule, followsTransactions: Bool = true,
         changes: [RecurrenceChange] = [], addedTransactionIDs: Set<UUID> = [],
         removedTransactionIDs: Set<UUID> = [], isDismissed: Bool = false) {
        self.key = key
        self.schedule = schedule
        self.followsTransactions = followsTransactions
        self.changes = changes
        self.addedTransactionIDs = addedTransactionIDs
        self.removedTransactionIDs = removedTransactionIDs
        self.isDismissed = isDismissed
    }

    func includes(_ transaction: Transaction) -> Bool {
        guard transaction.accountID == self.key.accountID else { return false }
        return self.addedTransactionIDs.contains(transaction.id)
            || (RecurrenceKey(transaction) == self.key && !self.removedTransactionIDs.contains(transaction.id))
    }

    /// Adds or replaces the change with the same identifier. Two changes can't
    /// share a day, because only one of them could apply.
    func settingChange(_ change: RecurrenceChange, calendar: Calendar) throws -> RecurrenceRule {
        let day = calendar.startOfDay(for: change.date)
        guard !self.changes.contains(where: { $0.id != change.id && calendar.startOfDay(for: $0.date) == day }) else {
            throw RecurrenceError.changeOnSameDay
        }
        var copy = self
        copy.changes = (copy.changes.filter { $0.id != change.id } + [change]).sorted { $0.date < $1.date }
        return copy
    }

    func removingChange(_ id: RecurrenceChange.ID) -> RecurrenceRule {
        var copy = self
        copy.changes.removeAll { $0.id == id }
        return copy
    }

    func adding(_ ids: Set<UUID>) -> RecurrenceRule {
        var copy = self
        copy.addedTransactionIDs.formUnion(ids)
        copy.removedTransactionIDs.subtract(ids)
        return copy
    }

    func removing(_ transaction: Transaction) -> RecurrenceRule {
        var copy = self
        copy.addedTransactionIDs.remove(transaction.id)
        if RecurrenceKey(transaction) == self.key { copy.removedTransactionIDs.insert(transaction.id) }
        return copy
    }
}

enum RecurrenceError: LocalizedError, Equatable {
    case changeOnSameDay
    case invalidAmount

    var errorDescription: String? {
        switch self {
        case .changeOnSameDay: "There’s already a change on that day. Edit that one instead."
        case .invalidAmount: "Enter an amount above zero, in dollars and cents."
        }
    }
}

/// A repeat as the forecast uses it: found in the history, or as the user shaped it.
struct RecurringTransaction: Hashable, Identifiable {
    let key: RecurrenceKey
    let plan: RecurrencePlan
    /// The transactions it was read from, oldest first.
    let transactionIDs: [Transaction.ID]
    let evidence: RecurrenceEvidence
    /// Whether the user has saved changes to it.
    let isEdited: Bool
    /// Whether its amount and dates still come from its transactions.
    let followsTransactions: Bool

    var id: RecurrenceKey { self.key }
    /// The transactions' summary, which is how the user sees them everywhere else.
    var merchant: String { self.key.name }
    var isIncome: Bool { self.key.isIncome }
    /// The amount it lands for now, signed the way it moves the balance.
    var amount: Decimal { self.plan.schedule.amount }
    var cadence: RecurrenceCadence { self.plan.schedule.cadence }

    var monthlyAmount: Decimal {
        self.amount * self.cadence.occurrencesPerYear / 12
    }
}

/// Puts the history and the user's rules together into the repeats a position has.
struct RecurrenceFinder {
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    /// `rules` should be the ones for the accounts `transactions` come from, so an
    /// account's forecast doesn't pick up another account's repeats.
    func find(in transactions: [Transaction], rules: [RecurrenceRule]) -> [RecurringTransaction] {
        let ruleKeys = Set(rules.map(\.key))
        var claimed = Set<Transaction.ID>()
        var found: [RecurringTransaction] = []

        for rule in rules {
            let members = transactions.filter(rule.includes).sorted { $0.date < $1.date }
            claimed.formUnion(members.map(\.id))
            guard !rule.isDismissed else { continue }
            let derived = rule.followsTransactions
                ? RecurrenceDetector(calendar: self.calendar).fit(members)
                : nil
            found.append(RecurringTransaction(
                key: rule.key,
                plan: RecurrencePlan(schedule: derived ?? rule.schedule, changes: rule.changes),
                transactionIDs: members.map(\.id),
                evidence: RecurrenceEvidence(members, calendar: self.calendar),
                isEdited: true,
                followsTransactions: rule.followsTransactions
            ))
        }

        // Whatever a rule speaks for, including what it was told to leave out, is
        // never found again on its own.
        let unclaimed = transactions.filter { !claimed.contains($0.id) && !ruleKeys.contains(RecurrenceKey($0)) }
        found += RecurrenceDetector(calendar: self.calendar).detect(in: unclaimed)
        return found.sorted { abs($0.monthlyAmount) > abs($1.monthlyAmount) }
    }
}
