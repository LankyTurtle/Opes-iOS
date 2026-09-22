import UIKit

/// Budget presentation with spending calculated from saved category allocations,
/// net of categorised credits such as refunds.
struct BudgetPreview: Hashable, Identifiable {
    let category: TransactionCategory
    let spent: Decimal
    let limit: Decimal
    let periodUnit: BudgetPeriodUnit

    var id: TransactionCategory.ID {
        self.category.id
    }

    var remaining: Decimal {
        self.limit - self.spent
    }

    var progress: Float {
        guard self.limit > 0 else {
            return 0
        }

        let ratio = NSDecimalNumber(decimal: self.spent / self.limit).floatValue
        return max(ratio, 0)
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
    /// This month's budgets, one per category with a monthly budget, grouped by
    /// bucket. Buckets with no budgeted categories, like Income usually, are left out.
    static func current(transactions: [Transaction], tree: CategoryTree, now: Date = .now,
                        calendar: Calendar = .current) -> [BudgetGroup] {
        guard let period = calendar.dateInterval(of: .month, for: now) else { return [] }
        let totals = CategorySpending.totals(in: transactions, during: period)
        return tree.buckets.compactMap { bucket in
            let budgets = bucket.categories.compactMap { category in
                category.monthlyBudget.map { limit in
                    BudgetPreview(category: category, spent: totals[category.id, default: 0], limit: limit, periodUnit: .monthly)
                }
            }
            return budgets.isEmpty ? nil : BudgetGroup(bucket: bucket, budgets: budgets)
        }
    }
}

/// A bucket's budgets, shown under its name with their combined total.
struct BudgetGroup: Hashable {
    let bucket: Bucket
    let budgets: [BudgetPreview]

    var spent: Decimal { self.budgets.reduce(Decimal.zero) { $0 + $1.spent } }
    var limit: Decimal { self.budgets.reduce(Decimal.zero) { $0 + $1.limit } }
}
