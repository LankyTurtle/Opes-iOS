import Foundation

/// Local persistence for manually entered and imported transactions.
final class TransactionStore: TransactionProviding {
    static let shared = TransactionStore()

    private let defaults: UserDefaults
    // v2 renamed the fields and made the account and time flag required; v1
    // history no longer decodes, so it is left behind rather than read.
    private let key = "transactions.v2"
    private let deletedAccountIDsKey = "transactionDeletedAccounts.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func transactions() -> [Transaction] {
        let deletedAccounts = (try? self.deletedAccountIDs()) ?? []
        return ((try? self.load()) ?? [])
            .filter { !deletedAccounts.contains($0.accountID) }
            .sorted { $0.date > $1.date }
    }

    func save(_ transaction: Transaction) throws {
        try self.save([transaction])
    }

    func save(_ newTransactions: [Transaction]) throws {
        let deletedAccounts = try self.deletedAccountIDs()
        guard newTransactions.allSatisfy({ !deletedAccounts.contains($0.accountID) }) else {
            throw SaveError.accountDeleted
        }
        var transactions = try self.load()
        let identifiers = Set(newTransactions.map(\.id))
        transactions.removeAll { identifiers.contains($0.id) }
        transactions.append(contentsOf: newTransactions)
        self.defaults.set(try JSONEncoder().encode(transactions), forKey: self.key)
    }

    func delete(id: Transaction.ID) throws {
        let remaining = try self.load().filter { $0.id != id }
        let remainingData = try JSONEncoder().encode(remaining)
        self.defaults.set(remainingData, forKey: self.key)
    }

    func delete(accountID: Account.ID) throws {
        let remaining = try self.load().filter { $0.accountID != accountID }
        var deletedAccounts = try self.deletedAccountIDs()
        deletedAccounts.insert(accountID)
        let remainingData = try JSONEncoder().encode(remaining)
        let deletedData = try JSONEncoder().encode(deletedAccounts)
        // Remember deleted accounts so stale forms cannot save new linked history.
        self.defaults.set(deletedData, forKey: self.deletedAccountIDsKey)
        self.defaults.set(remainingData, forKey: self.key)
    }

    private func deletedAccountIDs() throws -> Set<Account.ID> {
        guard let data = self.defaults.data(forKey: self.deletedAccountIDsKey) else { return [] }
        return try JSONDecoder().decode(Set<Account.ID>.self, from: data)
    }

    private func load() throws -> [Transaction] {
        guard let data = self.defaults.data(forKey: self.key) else {
            return []
        }
        return try JSONDecoder().decode([Transaction].self, from: data)
    }

    enum SaveError: LocalizedError {
        case accountDeleted
        var errorDescription: String? {
            switch self {
            case .accountDeleted: "This account has been deleted. Select another account before saving."
            }
        }
    }
}
