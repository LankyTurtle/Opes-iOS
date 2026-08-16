import Foundation

/// Local persistence for the prototype. Keeping it behind this type makes a
/// future database or account-sync implementation a contained replacement.
final class PayCycleStore {
    static let shared = PayCycleStore()

    private let defaults: UserDefaults
    private let key = "payCycles.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [PayCycle] {
        guard let data = self.defaults.data(forKey: self.key),
              let cycles = try? self.decoder.decode([PayCycle].self, from: data) else {
            return []
        }
        return cycles
    }

    func save(_ cycles: [PayCycle]) {
        guard let data = try? self.encoder.encode(cycles) else {
            return
        }
        self.defaults.set(data, forKey: self.key)
    }

    func upsert(_ cycle: PayCycle) {
        var cycles = self.load()
        if let index = cycles.firstIndex(where: { $0.id == cycle.id }) {
            cycles[index] = cycle
        } else {
            cycles.append(cycle)
        }
        self.save(cycles)
    }

    func delete(id: PayCycle.ID) {
        self.save(self.load().filter { $0.id != id })
    }
}
