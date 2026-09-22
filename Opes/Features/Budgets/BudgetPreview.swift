import UIKit

/// Budget presentation with spending calculated from saved expense allocations.
struct BudgetPreview: Hashable, Identifiable {
    typealias Category = ExpenseCategory

    let category: Category
    let spent: Decimal
    let limit: Decimal
    let periodUnit: BudgetPeriodUnit

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
    static func current(transactions: [Transaction], now: Date = .now, calendar: Calendar = .current) -> [BudgetPreview] {
        guard let period = calendar.dateInterval(of: .month, for: now) else { return [] }
        let totals = CategorySpending.totals(in: transactions, during: period)
        // Retain the existing monthly limits until budget editing is available.
        let limits: [(Category, Decimal)] = [
            (.groceries, 650), (.dining, 300), (.transport, 250),
            (.shopping, 400), (.entertainment, 150), (.health, 300),
        ]
        return limits.map { category, limit in
            BudgetPreview(category: category, spent: totals[category, default: 0], limit: limit, periodUnit: .monthly)
        }
    }
}
