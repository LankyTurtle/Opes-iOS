import UIKit

struct AccountPreview: Hashable, Identifiable {
    let id: UUID
    let name: String
    /// Positive for credit, negative for debt.
    let balance: Decimal
    let institution: String
    let institutionLogo: UIImage

    var formattedBalance: String {
        self.balance.formatted(.currency(code: "AUD"))
    }
}

/// Screens depend on this small read interface instead of a particular local
/// store. A backend implementation can replace local persistence later.
protocol AccountProviding {
    func accounts() -> [AccountPreview]
}

extension AccountStore: AccountProviding {
    func accounts() -> [AccountPreview] {
        let deletedIDs = (try? self.deletedAccountIDs()) ?? []
        return ((try? self.load()) ?? []).map { AccountPreview(account: $0) }
            .filter { !deletedIDs.contains($0.id) }
    }
}

extension AccountPreview {
    init(account: Account) {
        self.init(
            id: account.id, name: account.name, balance: account.balance,
            institution: account.institution,
            institutionLogo: UIImage(systemName: "building.columns.fill") ?? UIImage()
        )
    }
}
