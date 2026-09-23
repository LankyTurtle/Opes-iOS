import Foundation

/// The user's changes to repeats, saved locally. Repeats nobody has touched are
/// found afresh from the history each time and aren't stored.
final class RecurrenceStore {
    static let shared = RecurrenceStore()

    private let defaults: UserDefaults
    private let key = "recurrenceRules"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func rules() -> [RecurrenceRule] {
        guard let data = self.defaults.data(forKey: self.key),
              let rules = try? self.decoder.decode([RecurrenceRule].self, from: data) else {
            return []
        }
        return rules
    }

    /// Only the rules for these accounts, so a deleted account's repeats never
    /// reach a forecast.
    func rules(forAccounts accountIDs: Set<UUID>) -> [RecurrenceRule] {
        self.rules().filter { accountIDs.contains($0.key.accountID) }
    }

    func rule(for key: RecurrenceKey) -> RecurrenceRule? {
        self.rules().first { $0.key == key }
    }

    /// The saved rule for a repeat, or a new one that starts from what was found,
    /// ready to be changed and saved.
    func rule(for item: RecurringTransaction) -> RecurrenceRule {
        self.rule(for: item.key) ?? RecurrenceRule(key: item.key, schedule: item.plan.schedule)
    }

    func save(_ rule: RecurrenceRule) {
        self.write(self.rules().filter { $0.key != rule.key } + [rule])
    }

    /// Forgets the user's changes, so the repeat is found from the history again.
    func delete(_ key: RecurrenceKey) {
        self.write(self.rules().filter { $0.key != key })
    }

    private func write(_ rules: [RecurrenceRule]) {
        guard let data = try? self.encoder.encode(rules) else { return }
        self.defaults.set(data, forKey: self.key)
    }
}
