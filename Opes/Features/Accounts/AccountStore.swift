import Foundation

final class AccountStore {
    static let shared = AccountStore()
    private let defaults: UserDefaults
    private let key = "accounts"
    private let deletedIDsKey = "deletedAccounts"

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

    /// Spaces and hyphens in `number` and `bsb` are ignored. The BSB is
    /// required when the type has one, and dropped for card accounts.
    @discardableResult
    func create(
        name: String, type: AccountType, number: String, bsb: String?, institution: String
    ) throws -> Account {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let institution = institution.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !institution.isEmpty else { throw AccountError.missingDetails }
        guard let number = Self.digits(number), (1...20).contains(number.count) else {
            throw AccountError.invalidNumber
        }
        var validBSB: String?
        if type.hasBSB {
            guard let digits = Self.digits(bsb ?? ""), digits.count == 6 else { throw AccountError.invalidBSB }
            validBSB = digits
        }
        var accounts = try self.load()
        let account = Account(
            id: UUID(), name: name, type: type, number: number, bsb: validBSB,
            institution: institution, balance: 0
        )
        accounts.append(account)
        self.defaults.set(try JSONEncoder().encode(accounts), forKey: self.key)
        return account
    }

    /// The digits in `text` once spaces and hyphens are removed, or `nil` if
    /// anything else remains.
    private static func digits(_ text: String) -> String? {
        let stripped = text.filter { $0 != " " && $0 != "-" }
        return stripped.allSatisfy { ("0"..."9").contains($0) } ? stripped : nil
    }

    enum AccountError: LocalizedError {
        case missingDetails
        case invalidNumber
        case invalidBSB

        var errorDescription: String? {
            switch self {
            case .missingDetails: "Enter an account name and institution."
            case .invalidNumber: "Enter an account number of up to 20 digits."
            case .invalidBSB: "Enter a six-digit BSB."
            }
        }
    }
}
