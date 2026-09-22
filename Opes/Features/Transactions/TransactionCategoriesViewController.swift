import UIKit

/// Edits a draft; only Save persists the allocations.
///
/// Choices are grouped by bucket, each category followed by its subcategories.
final class TransactionCategoriesViewController: UITableViewController {
    /// Somewhere an amount can go: a category, or one of its subcategories.
    private struct Choice {
        let path: CategoryPath
        /// `Groceries` or `Groceries › Supermarket`.
        let name: String
        /// What the row shows in One category mode: the category, or just the subcategory under it.
        let title: String
        let isSubcategory: Bool
        let symbolName: String
        let field: UITextField
        let amountRow: UITableViewCell
    }

    private struct Group {
        let bucketName: String
        let choices: [Choice]
    }

    private let transaction: Transaction
    private let initialAllocations: [TransactionAllocation]
    private let tree: CategoryTree
    private let onSave: ([TransactionAllocation]) throws -> Void
    private let mode = UISegmentedControl(items: ["One category", "Split amount"])
    private var selectedPath: CategoryPath?
    private var groups: [Group] = []
    private var choices: [Choice] { self.groups.flatMap(\.choices) }
    private let statusLabel = UILabel()
    private lazy var modeView = FormControlView(control: self.mode)
    private lazy var statusRow = FormHostCell(view: self.statusLabel)

    // Sections: the mode picker (no rows), Uncategorised, one per bucket, then the status.
    private let uncategorisedSection = 1
    private let firstBucketSection = 2
    private var statusSection: Int { self.firstBucketSection + self.groups.count }
    private var isSplit: Bool { self.mode.selectedSegmentIndex == 1 }

    init(transaction: Transaction, allocations: [TransactionAllocation]? = nil,
         tree: CategoryTree = CategoryStore.shared.tree(),
         onSave: @escaping ([TransactionAllocation]) throws -> Void) {
        self.transaction = transaction
        self.initialAllocations = allocations ?? transaction.allocations
        self.tree = tree
        self.onSave = onSave
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Categories"
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(self.save)
        )
        self.tableView.keyboardDismissMode = .interactive
        let allocations = self.initialAllocations
        let isSingle = allocations.count == 1 && allocations[0].amount == abs(self.transaction.amount)
        self.selectedPath = isSingle ? allocations.first?.path : nil
        self.mode.selectedSegmentIndex = allocations.isEmpty || isSingle ? 0 : 1
        self.mode.addTarget(self, action: #selector(self.changeMode), for: .valueChanged)
        self.groups = self.tree.buckets.compactMap { bucket in
            let choices = bucket.categories.flatMap { category in
                [self.makeChoice(path: CategoryPath(categoryID: category.id), title: category.name,
                                 isSubcategory: false, symbolName: category.symbolName, allocations: allocations)]
                    + category.subcategories.map { subcategory in
                        self.makeChoice(path: CategoryPath(categoryID: category.id, subcategoryID: subcategory.id),
                                        title: subcategory.name, isSubcategory: true,
                                        symbolName: "arrow.turn.down.right", allocations: allocations)
                    }
            }
            return choices.isEmpty ? nil : Group(bucketName: bucket.name, choices: choices)
        }
        self.statusLabel.font = .preferredFont(forTextStyle: .body)
        self.statusLabel.adjustsFontForContentSizeCategory = true
        self.statusLabel.numberOfLines = 0
        self.statusLabel.accessibilityTraits = .updatesFrequently
        self.validateForm()
    }

    private func makeChoice(path: CategoryPath, title: String, isSubcategory: Bool, symbolName: String,
                            allocations: [TransactionAllocation]) -> Choice {
        let name = self.tree.name(of: path)
        let field = UITextField()
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.keyboardType = .decimalPad
        field.textAlignment = .right
        field.placeholder = "Not allocated"
        field.clearButtonMode = .whileEditing
        field.accessibilityLabel = "\(name) amount in AUD"
        if let allocation = allocations.first(where: { $0.path == path }) {
            field.text = allocation.amount.formatted(.number.grouping(.never))
        }
        field.addTarget(self, action: #selector(self.validateForm), for: .editingChanged)
        // Split rows stand alone, so they give the full name.
        let row = FormRowCell(title: name, control: field, stretchesControl: true)
        return Choice(path: path, name: name, title: title, isSubcategory: isSubcategory,
                      symbolName: symbolName, field: field, amountRow: row)
    }

    @objc private func changeMode() {
        self.view.endEditing(true)
        if self.isSplit, let path = self.selectedPath {
            for choice in self.choices {
                choice.field.text = choice.path == path
                    ? abs(self.transaction.amount).formatted(.number.grouping(.never)) : nil
            }
        }
        self.tableView.reloadData()
        self.validateForm()
    }

    private func draft() throws -> [TransactionAllocation] {
        let allocations: [TransactionAllocation]
        if !self.isSplit {
            allocations = self.selectedPath.map {
                [TransactionAllocation(path: $0, amount: abs(self.transaction.amount))]
            } ?? []
        } else {
            allocations = try self.choices.compactMap { choice in
                let text = (choice.field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                guard let amount = TransactionAmount.parse(text) else { throw AllocationError.invalid }
                return TransactionAllocation(path: choice.path, amount: amount)
            }
        }
        _ = try self.transaction.withAllocations(allocations)
        return allocations
    }

    @objc private func validateForm() {
        do {
            let allocations = try self.draft()
            let total = allocations.reduce(Decimal.zero) { $0 + $1.amount }
            let remaining = abs(self.transaction.amount) - total
            self.statusLabel.text = "\(total.formatted(.currency(code: "AUD"))) allocated\n\(remaining.formatted(.currency(code: "AUD"))) uncategorised"
            self.statusLabel.textColor = .secondaryLabel
            self.navigationItem.rightBarButtonItem?.isEnabled = true
        } catch {
            self.statusLabel.text = error.localizedDescription
            self.statusLabel.textColor = .systemRed
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        }
        self.tableView.performBatchUpdates(nil)
    }

    @objc private func save() {
        do {
            try self.onSave(self.draft())
            self.navigationController?.popViewController(animated: true)
        } catch {
            let alert = UIAlertController(title: "Couldn’t save categories", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    private func choice(at indexPath: IndexPath) -> Choice? {
        let group = indexPath.section - self.firstBucketSection
        guard self.groups.indices.contains(group), self.groups[group].choices.indices.contains(indexPath.row) else {
            return nil
        }
        return self.groups[group].choices[indexPath.row]
    }

    override func numberOfSections(in tableView: UITableView) -> Int { self.statusSection + 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: 0
        case self.uncategorisedSection: self.isSplit ? 0 : 1
        case self.statusSection: 1
        default: self.groups[section - self.firstBucketSection].choices.count
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == self.statusSection { return self.statusRow }
        let choice = self.choice(at: indexPath)
        if let choice, self.isSplit { return choice.amountRow }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = choice?.title ?? "Uncategorised"
        content.image = UIImage(systemName: choice?.symbolName ?? "tag.slash")
        if choice?.isSubcategory == true {
            content.imageProperties.tintColor = .tertiaryLabel
        }
        cell.contentConfiguration = content
        cell.accessibilityLabel = choice?.name ?? "Uncategorised"
        cell.accessoryType = self.selectedPath == choice?.path ? .checkmark : .none
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !self.isSplit, indexPath.section >= self.uncategorisedSection, indexPath.section < self.statusSection else {
            return
        }
        self.selectedPath = self.choice(at: indexPath)?.path
        self.tableView.reloadSections(IndexSet(self.uncategorisedSection..<self.statusSection), with: .none)
        self.validateForm()
    }
    /// The mode picker has no rows, so it sits in its section's footer: on the
    /// grouped background rather than boxed in a cell.
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        section == 0 ? self.modeView : nil
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: "\(self.transaction.directionDescription): \(abs(self.transaction.amount).formatted(.currency(code: "AUD")))"
        case self.uncategorisedSection, self.statusSection: nil
        default: self.groups[section - self.firstBucketSection].bucketName
        }
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == self.statusSection else { return nil }
        return self.isSplit
            ? "Enter an amount for each category or subcategory you need. Leave the rest blank. Only allocated amounts count toward budgets; credits, such as refunds, reduce that category’s spending."
            : "Choose a category or subcategory for the whole transaction, or split the amount across several. Manage them from Budgets."
    }
}
