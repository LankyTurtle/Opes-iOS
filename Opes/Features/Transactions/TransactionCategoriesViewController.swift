import UIKit

/// Edits a draft; only Save persists the allocations.
final class TransactionCategoriesViewController: UITableViewController {
    private let transaction: Transaction
    private let initialAllocations: [TransactionAllocation]
    private let onSave: ([TransactionAllocation]) throws -> Void
    private let mode = UISegmentedControl(items: ["One category", "Split amount"])
    private var selectedCategory: ExpenseCategory?
    private let categories = ExpenseCategory.allCases
    private var fields: [UITextField] = []
    private var amountRows: [UITableViewCell] = []
    private let statusLabel = UILabel()
    private lazy var modeRow = FormHostCell(view: self.mode)
    private lazy var statusRow = FormHostCell(view: self.statusLabel)

    init(transaction: Transaction, allocations: [TransactionAllocation]? = nil,
         onSave: @escaping ([TransactionAllocation]) throws -> Void) {
        self.transaction = transaction
        self.initialAllocations = allocations ?? transaction.allocations
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
        let isSingle = allocations.count == 1 && allocations[0].amount == -self.transaction.amount
        self.selectedCategory = isSingle ? allocations.first?.category : nil
        self.mode.selectedSegmentIndex = allocations.isEmpty || isSingle ? 0 : 1
        self.mode.addTarget(self, action: #selector(self.changeMode), for: .valueChanged)
        for category in self.categories {
            let field = UITextField()
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            field.keyboardType = .decimalPad
            field.textAlignment = .right
            field.placeholder = "Not allocated"
            field.clearButtonMode = .whileEditing
            field.accessibilityLabel = "\(category.rawValue) amount in AUD"
            if let allocation = allocations.first(where: { $0.category == category }) {
                field.text = allocation.amount.formatted(.number.grouping(.never))
            }
            field.addTarget(self, action: #selector(self.validate), for: .editingChanged)
            self.fields.append(field)
            self.amountRows.append(FormRowCell(title: category.rawValue, control: field, stretchesControl: true))
        }
        self.statusLabel.font = .preferredFont(forTextStyle: .body)
        self.statusLabel.adjustsFontForContentSizeCategory = true
        self.statusLabel.numberOfLines = 0
        self.statusLabel.accessibilityTraits = .updatesFrequently
        self.validate()
    }

    @objc private func changeMode() {
        self.view.endEditing(true)
        if self.mode.selectedSegmentIndex == 1, let category = self.selectedCategory {
            for (index, value) in self.categories.enumerated() {
                self.fields[index].text = value == category
                    ? (-self.transaction.amount).formatted(.number.grouping(.never)) : nil
            }
        }
        self.tableView.reloadData()
        self.validate()
    }

    private func draft() throws -> [TransactionAllocation] {
        let allocations: [TransactionAllocation]
        if self.mode.selectedSegmentIndex == 0 {
            allocations = self.selectedCategory.map {
                [TransactionAllocation(category: $0, amount: -self.transaction.amount)]
            } ?? []
        } else {
            allocations = try self.categories.enumerated().compactMap { index, category in
                let text = (self.fields[index].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                guard let amount = TransactionAmount.parse(text) else { throw AllocationError.invalid }
                return TransactionAllocation(category: category, amount: amount)
            }
        }
        _ = try self.transaction.withAllocations(allocations)
        return allocations
    }

    @objc private func validate() {
        do {
            let allocations = try self.draft()
            let total = allocations.reduce(Decimal.zero) { $0 + $1.amount }
            let remaining = -self.transaction.amount - total
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

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 1 ? (self.mode.selectedSegmentIndex == 0 ? self.categories.count + 1 : self.categories.count) : 1
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 { return self.modeRow }
        if indexPath.section == 2 { return self.statusRow }
        if self.mode.selectedSegmentIndex == 1 { return self.amountRows[indexPath.row] }
        let category = indexPath.row == 0 ? nil : self.categories[indexPath.row - 1]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = category?.rawValue ?? "Uncategorised"
        content.image = UIImage(systemName: category?.symbolName ?? "tag.slash")
        cell.contentConfiguration = content
        cell.accessoryType = self.selectedCategory == category ? .checkmark : .none
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1, self.mode.selectedSegmentIndex == 0 else { return }
        self.selectedCategory = indexPath.row == 0 ? nil : self.categories[indexPath.row - 1]
        self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
        self.validate()
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 1 ? "Expense: \((-self.transaction.amount).formatted(.currency(code: "AUD")))" : nil
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 1 else { return nil }
        return self.mode.selectedSegmentIndex == 0
            ? "Choose a category for the whole expense, or split the amount across categories."
            : "Enter an amount for each category you need. Leave unused categories blank. Only allocated amounts count toward budgets."
    }
}
