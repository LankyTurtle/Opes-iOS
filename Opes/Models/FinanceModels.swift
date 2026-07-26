import Foundation

struct UserProfile {
    let name: String
    let email: String
    let initials: String

    static let sample = UserProfile(
        name: "Alex Morgan",
        email: "alex@example.com",
        initials: "AM"
    )
}

struct FinancialAccount: Identifiable {
    enum Kind: String, CaseIterable, Hashable, Identifiable {
        case everyday
        case savings

        var id: Self { self }

        var title: String {
            switch self {
            case .everyday: "Everyday"
            case .savings: "Savings"
            }
        }

        var icon: String {
            switch self {
            case .everyday: "wallet.bifold.fill"
            case .savings: "banknote.fill"
            }
        }
    }

    let id: UUID
    let name: String
    let maskedNumber: String
    let balance: Decimal
    let kind: Kind

    init(
        id: UUID = UUID(),
        name: String,
        maskedNumber: String,
        balance: Decimal,
        kind: Kind
    ) {
        self.id = id
        self.name = name
        self.maskedNumber = maskedNumber
        self.balance = balance
        self.kind = kind
    }
}

struct BudgetCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let spent: Decimal
    let limit: Decimal

    var progress: Double {
        guard limit > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: spent / limit).doubleValue, 1)
    }
}

struct Transaction: Identifiable {
    let id = UUID()
    let merchant: String
    let category: String
    let icon: String
    let amount: Decimal
    let date: Date
}

enum SampleData {
    static let accounts = [
        FinancialAccount(name: "Everyday", maskedNumber: "•••• 4821", balance: 3_284.75, kind: .everyday),
        FinancialAccount(name: "Savings", maskedNumber: "•••• 9014", balance: 12_650.00, kind: .savings)
    ]

    static let budgets = [
        BudgetCategory(name: "Groceries", icon: "cart.fill", spent: 420, limit: 650),
        BudgetCategory(name: "Dining", icon: "fork.knife", spent: 188, limit: 300),
        BudgetCategory(name: "Transport", icon: "car.fill", spent: 96, limit: 240)
    ]

    static let transactions = [
        Transaction(merchant: "Corner Market", category: "Groceries", icon: "basket.fill", amount: -64.20, date: .now),
        Transaction(merchant: "Salary", category: "Income", icon: "arrow.down.left", amount: 2_850.00, date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now),
        Transaction(merchant: "Metro", category: "Transport", icon: "tram.fill", amount: -4.80, date: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now)
    ]
}
