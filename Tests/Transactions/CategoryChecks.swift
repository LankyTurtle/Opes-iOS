import Foundation

extension TransactionTests {
    static func categoryChecks() throws {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = start.addingTimeInterval(1000)
        let expense = Transaction(id: UUID(), description: "Mixed shop", date: start,
                                  amount: -100, accountID: self.accountID)
        let split = try expense.withAllocations([
            TransactionAllocation(category: .groceries, amount: Decimal(string: "60.25")!),
            TransactionAllocation(category: .health, amount: Decimal(string: "20.15")!),
        ])
        try self.expect(split.unallocatedAmount == Decimal(string: "19.60"), "Partial allocation keeps exact remainder")
        let full = try expense.withAllocations([TransactionAllocation(category: .shopping, amount: 100)])
        try self.expect(full.unallocatedAmount == 0, "Whole expense can be categorised")
        for invalid in [
            [TransactionAllocation(category: .dining, amount: 101)],
            [TransactionAllocation(category: .dining, amount: -1)],
            [TransactionAllocation(category: .dining, amount: 0)],
            [TransactionAllocation(category: .dining, amount: Decimal(string: "1.001")!)],
            [TransactionAllocation(category: .dining, amount: 10), TransactionAllocation(category: .dining, amount: 10)],
            [TransactionAllocation(category: .dining, amount: 80), TransactionAllocation(category: .health, amount: 30)],
        ] {
            try self.rejects("Invalid allocation rejected") { _ = try expense.withAllocations(invalid) }
        }
        let income = Transaction(id: UUID(), description: "Income", date: start, amount: 100, accountID: self.accountID)
        let refund = try Transaction(id: UUID(), description: "Refund", date: start, amount: Decimal(string: "10.25")!,
                                     accountID: self.accountID)
            .withAllocations([TransactionAllocation(category: .groceries, amount: Decimal(string: "10.25")!)])
        try self.expect(refund.unallocatedAmount == 0, "Credits can be categorised")
        try self.expect(try income.withAllocations([TransactionAllocation(category: .dining, amount: 10)]).unallocatedAmount == 90, "Credits can be split")
        try self.rejects("A credit's split cannot exceed its amount") {
            _ = try income.withAllocations([TransactionAllocation(category: .dining, amount: 101)])
        }
        let legacy = try JSONEncoder().encode(expense)
        try self.expect(!String(decoding: legacy, as: UTF8.self).contains("categoryAllocations"), "Legacy payload has no category key")
        try self.expect(try JSONDecoder().decode(Transaction.self, from: legacy).allocations.isEmpty, "Existing records decode uncategorised")
        let suite = "category-checks-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TransactionStore(defaults: defaults)
        try store.save(split)
        let reloaded = TransactionStore(defaults: defaults).transactions()
        try self.expect(reloaded.first?.allocations == split.allocations, "Splits survive store reload")
        try store.save(split.withSummary("New summary"))
        try self.expect(store.transactions().first?.allocations == split.allocations, "Summary edits preserve allocations")
        let boundary = try Transaction(id: UUID(), description: "Next period", date: end, amount: -100,
                                       accountID: self.accountID).withAllocations(full.allocations)
        let before = try Transaction(id: UUID(), description: "Before period", date: start.addingTimeInterval(-1), amount: -100,
                                     accountID: self.accountID).withAllocations(full.allocations)
        let period = DateInterval(start: start, end: end)
        let totals = CategorySpending.totals(in: [split, income, expense, boundary, before, refund], during: period)
        try self.expect(totals[.groceries] == Decimal(string: "50.00") && totals[.health] == Decimal(string: "20.15"), "Budgets count allocated portions, less categorised credits")
        let refundOnly = CategorySpending.totals(in: [refund], during: period)
        try self.expect(refundOnly[.groceries] == 0, "A category never shows negative spending")
        try self.expect(totals[.shopping] == nil, "Budget interval includes start and excludes end and prior dates")
        var filter = TransactionCategoryFilter()
        try self.expect(filter.matches(income) && filter.matches(expense), "Empty filter includes all transactions")
        filter.categories = [.groceries]
        try self.expect(filter.matches(split) && !filter.matches(full), "Split matches each assigned category")
        filter.categories = [.shopping, .health]
        try self.expect(filter.matches(split) && filter.matches(full), "Multiple category choices use OR")
        filter.categories = []
        filter.includesUncategorised = true
        try self.expect(filter.matches(split) && filter.matches(expense) && !filter.matches(full) && filter.matches(income) && !filter.matches(refund), "Uncategorised includes any transaction with an unallocated amount")
        try store.save(full)
        try self.expect(store.transactions().count == 1 && store.transactions()[0].allocations == full.allocations, "Recategorising replaces previous split")
        try store.save(try full.withAllocations([]))
        try self.expect(store.transactions()[0].allocations.isEmpty, "Categories can be cleared")
        try store.save(split)
        try store.delete(id: split.id)
        try self.expect(CategorySpending.totals(in: store.transactions(), during: period).isEmpty, "Deleted expenses stop counting toward budgets")
    }
}
