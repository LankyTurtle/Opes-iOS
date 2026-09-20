import Foundation

final class AccountStore {
    static let shared = AccountStore()
    private let defaults: UserDefaults
    private let key = "accounts.v1"
    private let deletedIDsKey = "deletedAccounts.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> [Account] {
        guard let data = self.defaults.data(forKey: self.key) else { return [] }
        return try JSONDecoder().decode([Account].self, from: data)
    }

    func deletedAccountIDs() throws -> Set<Account.ID> {
        guard let data = self.defaults.data(forKey: self.deletedIDsKey) else { return [] }
        return try JSONDecoder().decode(Set<Account.ID>.self, from: data)
    }

    func delete(id: Account.ID, transactionStore: TransactionStore) throws {
        let remaining = try self.load().filter { $0.id != id }
        var deletedIDs = try self.deletedAccountIDs()
        deletedIDs.insert(id)
        let remainingData = try JSONEncoder().encode(remaining)
        let deletedData = try JSONEncoder().encode(deletedIDs)
        // Validate and encode account state before deleting linked history. All
        // throwing work finishes before the final account writes.
        try transactionStore.delete(accountID: id)
        self.defaults.set(deletedData, forKey: self.deletedIDsKey)
        self.defaults.set(remainingData, forKey: self.key)
    }

    @discardableResult
    func create(name: String, institution: String) throws -> Account {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let institution = institution.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !institution.isEmpty else { throw AccountError.missingDetails }
        var accounts = try self.load()
        let account = Account(id: UUID(), name: name, institution: institution, balance: 0)
        accounts.append(account)
        self.defaults.set(try JSONEncoder().encode(accounts), forKey: self.key)
        return account
    }

    enum AccountError: LocalizedError {
        case missingDetails
        var errorDescription: String? { "Enter an account name and institution." }
    }
}
