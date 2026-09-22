import Foundation

struct Account: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let type: AccountType
    /// Digits only; separators are removed when the account is saved.
    let number: String
    /// Six digits without a separator. Always `nil` for card accounts.
    let bsb: String?
    let institution: String
    let balance: Decimal

    init(
        id: UUID, name: String, type: AccountType, number: String, bsb: String?,
        institution: String, balance: Decimal
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.number = number
        self.bsb = type.hasBSB ? bsb : nil
        self.institution = institution
        self.balance = balance
    }

    // Decoding goes through the memberwise init so a stored card account can
    // never come back with a BSB.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            type: try container.decode(AccountType.self, forKey: .type),
            number: try container.decode(String.self, forKey: .number),
            bsb: try container.decodeIfPresent(String.self, forKey: .bsb),
            institution: try container.decode(String.self, forKey: .institution),
            balance: try container.decode(Decimal.self, forKey: .balance)
        )
    }
}

enum AccountType: String, Codable, CaseIterable {
    case transaction
    case savings
    case creditCard
    case chargeCard
    case personalLoan
    case homeLoan
    case investmentLoan

    var title: String {
        switch self {
        case .transaction: "Transaction"
        case .savings: "Savings"
        case .creditCard: "Credit Card"
        case .chargeCard: "Charge Card"
        case .personalLoan: "Personal Loan"
        case .homeLoan: "Home Loan"
        case .investmentLoan: "Investment Loan"
        }
    }

    /// Credit and charge cards are identified by card number alone.
    var hasBSB: Bool {
        switch self {
        case .creditCard, .chargeCard: false
        case .transaction, .savings, .personalLoan, .homeLoan, .investmentLoan: true
        }
    }
}
