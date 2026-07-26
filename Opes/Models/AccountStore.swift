import Combine
import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [FinancialAccount]

    init(accounts: [FinancialAccount] = SampleData.accounts) {
        self.accounts = accounts
    }

    func add(_ account: FinancialAccount) {
        accounts.append(account)
    }

    func update(_ account: FinancialAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            return
        }
        accounts[index] = account
    }

    func remove(_ account: FinancialAccount) {
        accounts.removeAll { $0.id == account.id }
    }
}
