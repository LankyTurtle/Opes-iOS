import Foundation

/// Local persistence for the bucket, category and subcategory tree. A new
/// install starts from `CategoryTree.starter()`.
///
/// Category names are unique across the whole tree, so a category keeps one
/// meaning wherever it is shown and can move between buckets without clashing.
/// Subcategory names are unique within their category.
final class CategoryStore {
    static let shared = CategoryStore()
    private let defaults: UserDefaults
    private let key = "buckets"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved tree. The starter set is saved the first time, so its
    /// identifiers stay put for the allocations that come to use them.
    func tree() -> CategoryTree {
        if let data = self.defaults.data(forKey: self.key),
           let buckets = try? JSONDecoder().decode([Bucket].self, from: data) {
            return CategoryTree(buckets: buckets)
        }
        let starter = CategoryTree.starter()
        try? self.save(starter)
        return starter
    }

    @discardableResult
    func addBucket(named name: String) throws -> Bucket {
        var tree = self.tree()
        let bucket = Bucket(id: UUID(), name: try Self.validName(name, among: tree.buckets.map(\.name)), categories: [])
        tree.buckets.append(bucket)
        try self.save(tree)
        return bucket
    }

    func renameBucket(_ id: Bucket.ID, to name: String) throws {
        var tree = self.tree()
        guard let index = tree.buckets.firstIndex(where: { $0.id == id }) else { throw CategoryError.notFound }
        tree.buckets[index].name = try Self.validName(name, among: tree.buckets.filter { $0.id != id }.map(\.name))
        try self.save(tree)
    }

    @discardableResult
    func addCategory(named name: String, to bucketID: Bucket.ID) throws -> TransactionCategory {
        var tree = self.tree()
        guard let index = tree.buckets.firstIndex(where: { $0.id == bucketID }) else { throw CategoryError.notFound }
        let category = TransactionCategory(
            id: UUID(), name: try Self.validName(name, among: tree.categories.map(\.name)),
            symbolName: TransactionCategory.defaultSymbolName, monthlyBudget: nil, subcategories: []
        )
        tree.buckets[index].categories.append(category)
        try self.save(tree)
        return category
    }

    /// A nil budget leaves the category out of Budgets.
    func updateCategory(_ id: TransactionCategory.ID, name: String, monthlyBudget: Decimal?) throws {
        if let monthlyBudget, !Self.isValidBudget(monthlyBudget) { throw CategoryError.invalidBudget }
        var tree = self.tree()
        guard let (bucket, index) = Self.position(of: id, in: tree) else { throw CategoryError.notFound }
        let name = try Self.validName(name, among: tree.categories.filter { $0.id != id }.map(\.name))
        tree.buckets[bucket].categories[index].name = name
        tree.buckets[bucket].categories[index].monthlyBudget = monthlyBudget
        try self.save(tree)
    }

    /// Moves the category, with its subcategories and transactions, to the end
    /// of another bucket.
    func moveCategory(_ id: TransactionCategory.ID, to bucketID: Bucket.ID) throws {
        var tree = self.tree()
        guard let (bucket, index) = Self.position(of: id, in: tree),
              let destination = tree.buckets.firstIndex(where: { $0.id == bucketID })
        else { throw CategoryError.notFound }
        guard destination != bucket else { return }
        let category = tree.buckets[bucket].categories.remove(at: index)
        tree.buckets[destination].categories.append(category)
        try self.save(tree)
    }

    @discardableResult
    func addSubcategory(named name: String, to categoryID: TransactionCategory.ID) throws -> Subcategory {
        var tree = self.tree()
        guard let (bucket, index) = Self.position(of: categoryID, in: tree) else { throw CategoryError.notFound }
        let siblings = tree.buckets[bucket].categories[index].subcategories
        let subcategory = Subcategory(id: UUID(), name: try Self.validName(name, among: siblings.map(\.name)))
        tree.buckets[bucket].categories[index].subcategories.append(subcategory)
        try self.save(tree)
        return subcategory
    }

    func renameSubcategory(_ id: Subcategory.ID, in categoryID: TransactionCategory.ID, to name: String) throws {
        var tree = self.tree()
        guard let (bucket, index) = Self.position(of: categoryID, in: tree),
              let position = tree.buckets[bucket].categories[index].subcategories.firstIndex(where: { $0.id == id })
        else { throw CategoryError.notFound }
        let siblings = tree.buckets[bucket].categories[index].subcategories.filter { $0.id != id }
        tree.buckets[bucket].categories[index].subcategories[position].name = try Self.validName(
            name, among: siblings.map(\.name)
        )
        try self.save(tree)
    }

    /// Transactions in the subcategory stay in its category.
    func deleteSubcategory(_ id: Subcategory.ID, in categoryID: TransactionCategory.ID,
                           transactionStore: TransactionStore) throws {
        var tree = self.tree()
        guard let (bucket, index) = Self.position(of: categoryID, in: tree) else { throw CategoryError.notFound }
        // Transactions go first, so a failure never leaves them pointing at
        // something that no longer exists.
        try transactionStore.reassignAllocations { path in
            path.subcategoryID == id ? CategoryPath(categoryID: path.categoryID) : path
        }
        tree.buckets[bucket].categories[index].subcategories.removeAll { $0.id == id }
        try self.save(tree)
    }

    /// Transactions in the category move to `destination`, or become
    /// uncategorised when it is nil.
    func deleteCategory(_ id: TransactionCategory.ID, movingTransactionsTo destination: TransactionCategory.ID?,
                        transactionStore: TransactionStore) throws {
        var tree = self.tree()
        guard let (bucket, _) = Self.position(of: id, in: tree) else { throw CategoryError.notFound }
        if let destination, destination == id || tree.category(id: destination) == nil { throw CategoryError.notFound }
        try transactionStore.reassignAllocations { path in
            path.categoryID == id ? destination.map { CategoryPath(categoryID: $0) } : path
        }
        tree.buckets[bucket].categories.removeAll { $0.id == id }
        try self.save(tree)
    }

    /// The bucket's categories move to `destination`, transactions and all.
    /// When it is nil they are deleted too, and their transactions become
    /// uncategorised.
    func deleteBucket(_ id: Bucket.ID, movingCategoriesTo destination: Bucket.ID?,
                      transactionStore: TransactionStore) throws {
        var tree = self.tree()
        guard let bucket = tree.buckets.first(where: { $0.id == id }) else { throw CategoryError.notFound }
        if let destination {
            guard destination != id, let index = tree.buckets.firstIndex(where: { $0.id == destination }) else {
                throw CategoryError.notFound
            }
            tree.buckets[index].categories += bucket.categories
        } else {
            let deleted = Set(bucket.categories.map(\.id))
            try transactionStore.reassignAllocations { deleted.contains($0.categoryID) ? nil : $0 }
        }
        tree.buckets.removeAll { $0.id == id }
        try self.save(tree)
    }

    private func save(_ tree: CategoryTree) throws {
        self.defaults.set(try JSONEncoder().encode(tree.buckets), forKey: self.key)
    }

    private static func position(of categoryID: TransactionCategory.ID, in tree: CategoryTree) -> (Int, Int)? {
        for (bucket, value) in tree.buckets.enumerated() {
            if let index = value.categories.firstIndex(where: { $0.id == categoryID }) { return (bucket, index) }
        }
        return nil
    }

    /// Above zero, whole cents.
    private static func isValidBudget(_ budget: Decimal) -> Bool {
        var amount = budget
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 2, .plain)
        return budget > 0 && budget == rounded
    }

    private static func validName(_ name: String, among siblings: [String]) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryError.missingName }
        guard !siblings.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            throw CategoryError.duplicateName(trimmed)
        }
        return trimmed
    }

    enum CategoryError: LocalizedError, Equatable {
        case missingName
        case duplicateName(String)
        case invalidBudget
        case notFound

        var errorDescription: String? {
            switch self {
            case .missingName: "Enter a name."
            case let .duplicateName(name): "“\(name)” is already in use. Choose another name."
            case .invalidBudget: "Enter a monthly budget above zero with up to two decimal places, or leave it blank."
            case .notFound: "It has already been deleted."
            }
        }
    }
}
