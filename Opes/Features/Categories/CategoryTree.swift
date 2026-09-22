import Foundation

/// The top level of the category tree, such as Income, Living or Lifestyle.
struct Bucket: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var categories: [TransactionCategory]
}

/// What transactions are assigned to. Each belongs to one bucket.
struct TransactionCategory: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var symbolName: String
    /// The monthly limit shown in Budgets. Nil leaves the category out of Budgets.
    var monthlyBudget: Decimal?
    var subcategories: [Subcategory]

    static let defaultSymbolName = "tag"
}

/// An optional narrowing of a category, such as Groceries › Supermarket.
struct Subcategory: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
}

/// Where an allocation points: a category, optionally narrowed to one of its
/// subcategories.
struct CategoryPath: Codable, Hashable {
    let categoryID: TransactionCategory.ID
    var subcategoryID: Subcategory.ID?
}

struct CategoryTree: Hashable {
    var buckets: [Bucket]

    /// What a new install starts with. Every bucket and category can be renamed
    /// or deleted afterwards.
    static func starter() -> CategoryTree {
        func bucket(_ name: String, _ categories: [(String, String, Decimal?)]) -> Bucket {
            Bucket(id: UUID(), name: name, categories: categories.map { name, symbolName, budget in
                TransactionCategory(id: UUID(), name: name, symbolName: symbolName,
                                    monthlyBudget: budget, subcategories: [])
            })
        }
        return CategoryTree(buckets: [
            bucket("Income", [
                ("Salary", "banknote.fill", nil),
                ("Interest", "percent", nil),
                ("Refunds", "arrow.uturn.backward", nil),
                ("Other income", "plus.circle.fill", nil),
            ]),
            bucket("Living", [
                ("Groceries", "cart.fill", 650),
                ("Housing", "house.fill", nil),
                ("Utilities", "bolt.fill", nil),
                ("Transport", "car.fill", 250),
                ("Health", "cross.case.fill", 300),
                ("Insurance", "checkmark.shield.fill", nil),
            ]),
            bucket("Lifestyle", [
                ("Dining", "fork.knife", 300),
                ("Entertainment", "play.rectangle.fill", 150),
                ("Shopping", "bag.fill", 400),
                ("Travel", "airplane", nil),
                ("Subscriptions", "repeat", nil),
            ]),
        ])
    }

    var categories: [TransactionCategory] {
        self.buckets.flatMap(\.categories)
    }

    func category(id: TransactionCategory.ID) -> TransactionCategory? {
        self.categories.first { $0.id == id }
    }

    func bucket(containing categoryID: TransactionCategory.ID) -> Bucket? {
        self.buckets.first { $0.categories.contains { $0.id == categoryID } }
    }

    /// `Groceries`, or `Groceries › Supermarket` when narrowed to a subcategory.
    func name(of path: CategoryPath) -> String {
        guard let category = self.category(id: path.categoryID) else { return "Unknown category" }
        guard let subcategoryID = path.subcategoryID,
              let subcategory = category.subcategories.first(where: { $0.id == subcategoryID }) else {
            return category.name
        }
        return "\(category.name) › \(subcategory.name)"
    }
}
