import UIKit

/// Sample presentation data for the budgets screen, until budgets and transaction
/// categories come from the app's data store.
struct BudgetPreview: Hashable, Identifiable {
    enum Category: String, Hashable {
        case dining = "Dining"
        case entertainment = "Entertainment"
        case groceries = "Groceries"
        case shopping = "Shopping"
        case transport = "Transport"

        var symbolName: String {
            switch self {
            case .dining:
                return "fork.knife"
            case .entertainment:
                return "play.rectangle.fill"
            case .groceries:
                return "cart.fill"
            case .shopping:
                return "bag.fill"
            case .transport:
                return "car.fill"
            }
        }
    }

    let category: Category
    let spent: Decimal
    let limit: Decimal

    var id: Category {
        self.category
    }

    var remaining: Decimal {
        self.limit - self.spent
    }

    var progress: Float {
        guard self.limit > 0 else {
            return 0
        }

        let ratio = NSDecimalNumber(decimal: self.spent / self.limit).floatValue
        return min(max(ratio, 0), 1)
    }

    var statusColor: UIColor {
        if self.remaining < 0 {
            return .systemRed
        }

        return self.progress >= 0.8 ? .systemOrange : .systemTeal
    }

    var formattedSpent: String {
        self.spent.formatted(.currency(code: "AUD"))
    }

    var formattedLimit: String {
        self.limit.formatted(.currency(code: "AUD"))
    }

    var formattedStatus: String {
        if self.remaining >= 0 {
            return "\(self.remaining.formatted(.currency(code: "AUD"))) left"
        }

        return "\((-self.remaining).formatted(.currency(code: "AUD"))) over"
    }
}

extension BudgetPreview {
    static let sample: [BudgetPreview] = [
        .makeSample(category: .groceries, spentCents: 48_625, limitCents: 65_000),
        .makeSample(category: .dining, spentCents: 31_840, limitCents: 30_000),
        .makeSample(category: .transport, spentCents: 14_270, limitCents: 25_000),
        .makeSample(category: .shopping, spentCents: 21_000, limitCents: 40_000),
        .makeSample(category: .entertainment, spentCents: 8_495, limitCents: 15_000),
    ]

    private static func makeSample(
        category: Category,
        spentCents: Int,
        limitCents: Int
    ) -> BudgetPreview {
        BudgetPreview(
            category: category,
            spent: Decimal(spentCents) / 100,
            limit: Decimal(limitCents) / 100
        )
    }
}
