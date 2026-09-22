import Foundation

/// Local persistence for manually entered and imported transactions.
final class TransactionStore: TransactionProviding {
    static let shared = TransactionStore()

    private let defaults: UserDefaults
    private let key = "transactions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func transactions() -> [Transaction] {
        ((try? self.load()) ?? []).sorted { $0.date > $1.date }
    }

    func save(_ transaction: Transaction) throws {
        try self.save([transaction])
    }

    func save(_ newTransactions: [Transaction]) throws {
        for transaction in newTransactions { try transaction.validateAllocations() }
        var transactions = try self.load()
        let identifiers = Set(newTransactions.map(\.id))
        transactions.removeAll { identifiers.contains($0.id) }
        transactions.append(contentsOf: newTransactions)
        self.defaults.set(try JSONEncoder().encode(transactions), forKey: self.key)
    }

    /// Moves or drops allocations across every transaction, for when a
    /// category or subcategory is deleted.
    func reassignAllocations(_ transform: (CategoryPath) -> CategoryPath?) throws {
        let transactions = try self.load().map { $0.reassigningAllocations(transform) }
        self.defaults.set(try JSONEncoder().encode(transactions), forKey: self.key)
    }

    func delete(id: Transaction.ID) throws {
        let remaining = try self.load().filter { $0.id != id }
        let remainingData = try JSONEncoder().encode(remaining)
        self.defaults.set(remainingData, forKey: self.key)
    }

    func delete(accountID: Account.ID) throws {
        let remaining = try self.load().filter { $0.accountID != accountID }
        let remainingData = try JSONEncoder().encode(remaining)
        self.defaults.set(remainingData, forKey: self.key)
    }

    private func load() throws -> [Transaction] {
        guard let data = self.defaults.data(forKey: self.key) else {
            return []
        }
        return try JSONDecoder().decode([Transaction].self, from: data)
    }
}
