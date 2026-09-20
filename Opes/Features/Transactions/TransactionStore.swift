import Foundation

/// User-entered transactions are kept separately from the prototype's sample history.
final class TransactionStore: TransactionProviding {
    static let shared = TransactionStore()

    private let defaults: UserDefaults
    private let sampleProvider: any TransactionProviding
    private let key = "manualTransactions.v1"
    private let deletedSampleIDsKey = "deletedSampleTransactions.v1"

    init(
        defaults: UserDefaults = .standard,
        sampleProvider: any TransactionProviding = SampleTransactionProvider()
    ) {
        self.defaults = defaults
        self.sampleProvider = sampleProvider
    }

    func transactions() -> [Transaction] {
        let deletedIDs = (try? self.deletedSampleIDs()) ?? []
        return (self.sampleProvider.transactions().filter { !deletedIDs.contains($0.id) } + ((try? self.load()) ?? []))
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

    func delete(id: Transaction.ID) throws {
        let remaining = try self.load().filter { $0.id != id }
        var deletedIDs = try self.deletedSampleIDs()
        if self.sampleProvider.transactions().contains(where: { $0.id == id }) {
            deletedIDs.insert(id)
        }
        // Prepare both values before mutating storage so decoding or encoding
        // failures leave the existing history intact.
        let remainingData = try JSONEncoder().encode(remaining)
        let deletedData = try JSONEncoder().encode(deletedIDs)
        self.defaults.set(deletedData, forKey: self.deletedSampleIDsKey)
        self.defaults.set(remainingData, forKey: self.key)
    }

    private func deletedSampleIDs() throws -> Set<Transaction.ID> {
        guard let data = self.defaults.data(forKey: self.deletedSampleIDsKey) else { return [] }
        return try JSONDecoder().decode(Set<Transaction.ID>.self, from: data)
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
