import Foundation

enum TransactionCategory: String, Codable, CaseIterable, Hashable {
    case dining = "Dining"
    case entertainment = "Entertainment"
    case groceries = "Groceries"
    case health = "Health"
    case shopping = "Shopping"
    case transport = "Transport"

    var symbolName: String {
        switch self {
        case .dining: return "fork.knife"
        case .entertainment: return "play.rectangle.fill"
        case .groceries: return "cart.fill"
        case .health: return "cross.case.fill"
        case .shopping: return "bag.fill"
        case .transport: return "car.fill"
        }
    }
}

struct TransactionAllocation: Codable, Hashable {
    let category: TransactionCategory
    /// Positive AUD amount assigned to this category.
    let amount: Decimal
}

enum AllocationError: LocalizedError {
    case invalid
    var errorDescription: String? {
        "Use positive amounts with up to two decimal places, one per category. The total cannot exceed the transaction amount."
    }
}

enum CategorySpending {
    /// Debits add to a category and credits, such as refunds, take away from
    /// it. A category never shows less than nothing spent.
    static func totals(in transactions: [Transaction], during period: DateInterval) -> [TransactionCategory: Decimal] {
        var totals: [TransactionCategory: Decimal] = [:]
        for transaction in transactions where transaction.date >= period.start && transaction.date < period.end {
            for allocation in transaction.allocations {
                totals[allocation.category, default: 0] += transaction.isMoneyIn ? -allocation.amount : allocation.amount
            }
        }
        return totals.mapValues { max($0, 0) }
    }
}

struct TransactionCategoryFilter {
    var categories: Set<TransactionCategory> = []
    var includesUncategorised = false
    var isActive: Bool { !self.categories.isEmpty || self.includesUncategorised }

    func matches(_ transaction: Transaction) -> Bool {
        !self.isActive
            || transaction.allocations.contains { self.categories.contains($0.category) }
            || (self.includesUncategorised && transaction.unallocatedAmount > 0)
    }
}
