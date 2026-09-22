import Foundation

struct TransactionAllocation: Codable, Hashable {
    let path: CategoryPath
    /// Positive AUD amount assigned to this category or subcategory.
    let amount: Decimal
}

enum AllocationError: LocalizedError {
    case invalid
    var errorDescription: String? {
        "Use positive amounts with up to two decimal places, one per category or subcategory. The total cannot exceed the transaction amount."
    }
}

enum CategorySpending {
    /// Debits add to a category and credits, such as refunds, take away from
    /// it. Subcategories count toward their category. A category never shows
    /// less than nothing spent.
    static func totals(in transactions: [Transaction], during period: DateInterval) -> [TransactionCategory.ID: Decimal] {
        var totals: [TransactionCategory.ID: Decimal] = [:]
        for transaction in transactions where transaction.date >= period.start && transaction.date < period.end {
            for allocation in transaction.allocations {
                totals[allocation.path.categoryID, default: 0] += transaction.isMoneyIn ? -allocation.amount : allocation.amount
            }
        }
        return totals.mapValues { max($0, 0) }
    }
}

/// Matches whole categories, subcategories included.
struct TransactionCategoryFilter {
    var categories: Set<TransactionCategory.ID> = []
    var includesUncategorised = false
    var isActive: Bool { !self.categories.isEmpty || self.includesUncategorised }

    func matches(_ transaction: Transaction) -> Bool {
        !self.isActive
            || transaction.allocations.contains { self.categories.contains($0.path.categoryID) }
            || (self.includesUncategorised && transaction.unallocatedAmount > 0)
    }
}
