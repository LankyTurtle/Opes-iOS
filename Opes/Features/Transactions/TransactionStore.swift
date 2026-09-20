import Foundation

/// User-entered transactions are kept separately from the prototype's sample history.
final class TransactionStore: TransactionProviding {
    static let shared = TransactionStore()

    private let defaults: UserDefaults
    private let sampleProvider: any TransactionProviding
    private let key = "manualTransactions.v1"

    init(
        defaults: UserDefaults = .standard,
        sampleProvider: any TransactionProviding = SampleTransactionProvider()
    ) {
        self.defaults = defaults
        self.sampleProvider = sampleProvider
    }

    func transactions() -> [Transaction] {
        (self.sampleProvider.transactions() + ((try? self.load()) ?? []))
            .sorted { $0.date > $1.date }
    }

    func save(_ transaction: Transaction) throws {
        try self.save([transaction])
    }

    func save(_ newTransactions: [Transaction]) throws {
        guard newTransactions.allSatisfy({ $0.accountID != nil }) else {
            throw SaveError.accountRequired
        }
        var transactions = try self.load()
        let identifiers = Set(newTransactions.map(\.id))
        transactions.removeAll { identifiers.contains($0.id) }
        transactions.append(contentsOf: newTransactions)
        self.defaults.set(try JSONEncoder().encode(transactions), forKey: self.key)
    }

    private func load() throws -> [Transaction] {
        guard let data = self.defaults.data(forKey: self.key) else {
            return []
        }
        return try JSONDecoder().decode([Transaction].self, from: data)
    }

    enum SaveError: LocalizedError {
        case accountRequired
        var errorDescription: String? { "Select an account for every transaction before saving." }
    }
}
