import UIKit

struct AccountPreview: Hashable, Identifiable {
    let id: UUID
    let name: String
    let type: AccountType
    let number: String
    let bsb: String?
    /// Positive for credit, negative for debt.
    let balance: Decimal
    let institution: String
    let institutionLogo: UIImage

    var formattedBalance: String {
        self.balance.formatted(.currency(code: "AUD"))
    }

    /// The full account number, or only the last four digits of a card number.
    /// `nil` for accounts saved before numbers were recorded.
    var displayNumber: String? {
        guard !self.number.isEmpty else { return nil }
        return self.type.hasBSB ? self.number : "•••• \(self.number.suffix(4))"
    }

    /// The BSB as it's usually written, e.g. `062-000`.
    var formattedBSB: String? {
        self.bsb.map { "\($0.prefix(3))-\($0.suffix(3))" }
    }

    /// The institution, followed by the account number when there is one.
    var subtitle: String {
        [self.institution, self.displayNumber].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Screens depend on this small read interface instead of a particular local
/// store. A backend implementation can replace local persistence later.
protocol AccountProviding {
    func accounts() -> [AccountPreview]
}

extension AccountStore: AccountProviding {
    func accounts() -> [AccountPreview] {
        ((try? self.load()) ?? []).map { AccountPreview(account: $0) }
    }
}

extension AccountPreview {
    init(account: Account) {
        self.init(
            id: account.id, name: account.name, type: account.type, number: account.number,
            bsb: account.bsb, balance: account.balance,
            institution: account.institution,
            institutionLogo: UIImage(systemName: "building.columns.fill") ?? UIImage()
        )
    }
}
