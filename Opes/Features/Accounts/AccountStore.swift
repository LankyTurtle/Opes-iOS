import Foundation

final class AccountStore {
    static let shared = AccountStore()
    private let defaults: UserDefaults
    private let key = "accounts.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> [Account] {
        guard let data = self.defaults.data(forKey: self.key) else { return [] }
        return try JSONDecoder().decode([Account].self, from: data)
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
