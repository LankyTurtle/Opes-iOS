import Foundation

extension TransactionTests {
    static func categoryChecks() throws {
        let tree = CategoryTree.starter()
        try self.expect(tree.buckets.map(\.name) == ["Income", "Living", "Lifestyle"], "Income, Living and Lifestyle are the starter buckets")
        func path(_ name: String) -> CategoryPath { CategoryPath(categoryID: tree.categories.first { $0.name == name }!.id) }
        let groceries = path("Groceries"), health = path("Health"), shopping = path("Shopping"), dining = path("Dining")
        try self.expect(tree.bucket(containing: groceries.categoryID)?.name == "Living", "Groceries starts in Living")
        try self.expect(tree.name(of: groceries) == "Groceries", "A category path is named by its category")

        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = start.addingTimeInterval(1000)
        let expense = Transaction(id: UUID(), description: "Mixed shop", date: start,
                                  amount: -100, accountID: self.accountID)
        let split = try expense.withAllocations([
            TransactionAllocation(path: groceries, amount: Decimal(string: "60.25")!),
            TransactionAllocation(path: health, amount: Decimal(string: "20.15")!),
        ])
        try self.expect(split.unallocatedAmount == Decimal(string: "19.60"), "Partial allocation keeps exact remainder")
        let full = try expense.withAllocations([TransactionAllocation(path: shopping, amount: 100)])
        try self.expect(full.unallocatedAmount == 0, "Whole expense can be categorised")
        for invalid in [
            [TransactionAllocation(path: dining, amount: 101)],
            [TransactionAllocation(path: dining, amount: -1)],
            [TransactionAllocation(path: dining, amount: 0)],
            [TransactionAllocation(path: dining, amount: Decimal(string: "1.001")!)],
            [TransactionAllocation(path: dining, amount: 10), TransactionAllocation(path: dining, amount: 10)],
            [TransactionAllocation(path: dining, amount: 80), TransactionAllocation(path: health, amount: 30)],
        ] {
            try self.rejects("Invalid allocation rejected") { _ = try expense.withAllocations(invalid) }
        }
        let takeaway = CategoryPath(categoryID: dining.categoryID, subcategoryID: UUID())
        let narrowed = try expense.withAllocations([
            TransactionAllocation(path: dining, amount: 10), TransactionAllocation(path: takeaway, amount: 15),
        ])
        try self.expect(narrowed.unallocatedAmount == 75, "A category and one of its subcategories are separate allocations")
        let income = Transaction(id: UUID(), description: "Income", date: start, amount: 100, accountID: self.accountID)
        let refund = try Transaction(id: UUID(), description: "Refund", date: start, amount: Decimal(string: "10.25")!,
                                     accountID: self.accountID)
            .withAllocations([TransactionAllocation(path: groceries, amount: Decimal(string: "10.25")!)])
        try self.expect(refund.unallocatedAmount == 0, "Credits can be categorised")
        try self.expect(try income.withAllocations([TransactionAllocation(path: dining, amount: 10)]).unallocatedAmount == 90, "Credits can be split")
        try self.rejects("A credit's split cannot exceed its amount") {
            _ = try income.withAllocations([TransactionAllocation(path: dining, amount: 101)])
        }
        let uncategorised = try JSONEncoder().encode(expense)
        try self.expect(!String(decoding: uncategorised, as: UTF8.self).contains("categoryAllocations"), "Uncategorised payload has no category key")
        try self.expect(try JSONDecoder().decode(Transaction.self, from: uncategorised).allocations.isEmpty, "Uncategorised records decode uncategorised")
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
        let totals = CategorySpending.totals(in: [split, income, expense, boundary, before, refund, narrowed], during: period)
        try self.expect(totals[groceries.categoryID] == Decimal(string: "50.00") && totals[health.categoryID] == Decimal(string: "20.15"), "Budgets count allocated portions, less categorised credits")
        try self.expect(totals[dining.categoryID] == 25, "Subcategories count toward their category")
        let refundOnly = CategorySpending.totals(in: [refund], during: period)
        try self.expect(refundOnly[groceries.categoryID] == 0, "A category never shows negative spending")
        try self.expect(totals[shopping.categoryID] == nil, "Budget interval includes start and excludes end and prior dates")
        var filter = TransactionCategoryFilter()
        try self.expect(filter.matches(income) && filter.matches(expense), "Empty filter includes all transactions")
        filter.categories = [groceries.categoryID]
        try self.expect(filter.matches(split) && !filter.matches(full), "Split matches each assigned category")
        filter.categories = [shopping.categoryID, health.categoryID]
        try self.expect(filter.matches(split) && filter.matches(full), "Multiple category choices use OR")
        filter.categories = [dining.categoryID]
        try self.expect(filter.matches(try expense.withAllocations([TransactionAllocation(path: takeaway, amount: 5)])), "A category filter matches its subcategories")
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
        try self.categoryStoreChecks()
    }

    static func categoryStoreChecks() throws {
        let suite = "category-store-checks-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let categories = CategoryStore(defaults: defaults)
        let transactions = TransactionStore(defaults: defaults)
        let seeded = categories.tree()
        try self.expect(seeded == categories.tree(), "The starter tree is saved once and keeps its identifiers")
        func category(_ name: String) -> TransactionCategory { categories.tree().categories.first { $0.name == name }! }
        func bucket(_ name: String) -> Bucket { categories.tree().buckets.first { $0.name == name }! }

        let pets = try categories.addBucket(named: "  Pets ")
        try self.expect(pets.name == "Pets" && categories.tree().buckets.last == pets, "Users can add buckets")
        try self.rejects("Bucket names are unique") { try categories.addBucket(named: "living") }
        try self.rejects("Names cannot be blank") { try categories.addBucket(named: "  ") }
        try categories.renameBucket(bucket("Income").id, to: "Earnings")
        try self.expect(categories.tree().buckets.first?.name == "Earnings", "Default buckets can be renamed")

        let vet = try categories.addCategory(named: "Vet", to: pets.id)
        try self.expect(vet.monthlyBudget == nil && categories.tree().bucket(containing: vet.id)?.id == pets.id, "Categories are added to a bucket without a budget")
        try self.rejects("Category names are unique across buckets") { try categories.addCategory(named: "groceries", to: pets.id) }
        try categories.updateCategory(vet.id, name: "Vet bills", monthlyBudget: Decimal(string: "80.50"))
        try self.expect(category("Vet bills").monthlyBudget == Decimal(string: "80.50"), "Categories can be renamed and given a budget")
        for budget in [Decimal(0), -5, Decimal(string: "1.001")!] {
            try self.rejects("Budgets are positive whole cents") { try categories.updateCategory(vet.id, name: "Vet bills", monthlyBudget: budget) }
        }

        let supermarket = try categories.addSubcategory(named: "Supermarket", to: category("Groceries").id)
        try self.rejects("Subcategory names are unique within their category") {
            try categories.addSubcategory(named: "SUPERMARKET", to: category("Groceries").id)
        }
        _ = try categories.addSubcategory(named: "Supermarket", to: category("Dining").id)
        try categories.renameSubcategory(supermarket.id, in: category("Groceries").id, to: "Supermarkets")
        let groceries = CategoryPath(categoryID: category("Groceries").id)
        let supermarkets = CategoryPath(categoryID: groceries.categoryID, subcategoryID: supermarket.id)
        try self.expect(categories.tree().name(of: supermarkets) == "Groceries › Supermarkets", "Subcategory paths name both levels")

        let shop = try Transaction(id: UUID(), description: "Shop", date: .now, amount: -100, accountID: self.accountID)
            .withAllocations([TransactionAllocation(path: groceries, amount: 30), TransactionAllocation(path: supermarkets, amount: 50)])
        try transactions.save(shop)
        try categories.deleteSubcategory(supermarket.id, in: groceries.categoryID, transactionStore: transactions)
        try self.expect(transactions.transactions()[0].allocations == [TransactionAllocation(path: groceries, amount: 80)], "Deleting a subcategory moves its amounts to the category, combined")
        try self.expect(category("Groceries").subcategories.isEmpty, "The subcategory is gone")

        let dining = CategoryPath(categoryID: category("Dining").id)
        try categories.deleteCategory(groceries.categoryID, movingTransactionsTo: dining.categoryID, transactionStore: transactions)
        try self.expect(transactions.transactions()[0].allocations == [TransactionAllocation(path: dining, amount: 80)], "Deleting a category can move its transactions to another")
        try self.rejects("A category cannot move its transactions to itself") {
            try categories.deleteCategory(dining.categoryID, movingTransactionsTo: dining.categoryID, transactionStore: transactions)
        }

        let lifestyle = bucket("Lifestyle")
        try categories.deleteBucket(lifestyle.id, movingCategoriesTo: pets.id, transactionStore: transactions)
        try self.expect(categories.tree().bucket(containing: dining.categoryID)?.id == pets.id, "Deleting a bucket can move its categories, transactions and all")
        try self.expect(transactions.transactions()[0].allocations.count == 1, "Moving categories keeps their transactions")
        try categories.deleteBucket(pets.id, movingCategoriesTo: nil, transactionStore: transactions)
        try self.expect(categories.tree().category(id: dining.categoryID) == nil && transactions.transactions()[0].allocations.isEmpty, "Deleting a bucket with its categories leaves their transactions uncategorised")
        try self.expect(categories.tree().buckets.map(\.name) == ["Earnings", "Living"], "Default buckets can be deleted")
    }
}
