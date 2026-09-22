import UIKit

/// One category: its name, bucket, monthly budget, and subcategories. Changes
/// save as each field is left.
final class CategoryEditorViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case details
        case subcategories
        case delete
    }

    private let categoryID: TransactionCategory.ID
    private let store: CategoryStore
    private let transactionStore: TransactionStore
    private var category: TransactionCategory?

    private let nameField = UITextField()
    private let budgetField = UITextField()
    private let bucketButton = UIButton(type: .system)
    private lazy var detailRows: [UITableViewCell] = [
        FormRowCell(title: "Name", control: self.nameField, stretchesControl: true),
        FormRowCell(title: "Bucket", control: self.bucketButton, stretchesControl: true),
        FormRowCell(title: "Monthly budget (AUD)", control: self.budgetField, stretchesControl: true),
    ]
    private let addRow = CategoryActionCell(title: "Add Subcategory", style: .add)
    private let deleteRow = CategoryActionCell(title: "Delete Category", style: .delete)

    init(categoryID: TransactionCategory.ID, store: CategoryStore = .shared,
         transactionStore: TransactionStore = .shared) {
        self.categoryID = categoryID
        self.store = store
        self.transactionStore = transactionStore
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.largeTitleDisplayMode = .never
        self.tableView.keyboardDismissMode = .interactive
        for field in [self.nameField, self.budgetField] {
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            field.textAlignment = .right
            field.clearButtonMode = .whileEditing
            field.delegate = self
        }
        self.nameField.autocapitalizationType = .sentences
        self.nameField.returnKeyType = .done
        self.nameField.accessibilityLabel = "Category name"
        self.budgetField.keyboardType = .decimalPad
        self.budgetField.placeholder = "No budget"
        self.budgetField.accessibilityLabel = "Monthly budget in Australian dollars"
        self.bucketButton.showsMenuAsPrimaryAction = true
        self.bucketButton.contentHorizontalAlignment = .trailing
        self.bucketButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        self.bucketButton.titleLabel?.adjustsFontForContentSizeCategory = true
        self.bucketButton.accessibilityLabel = "Bucket"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reload()
    }

    /// Rows are only reloaded when asked: reloading as focus moves from one field
    /// to the next would take the keyboard away from the second.
    private func reload(rows: Bool = true) {
        let tree = self.store.tree()
        guard let category = tree.category(id: self.categoryID), let bucket = tree.bucket(containing: self.categoryID) else {
            self.navigationController?.popViewController(animated: true)
            return
        }
        self.category = category
        self.title = category.name
        self.nameField.text = category.name
        self.budgetField.text = category.monthlyBudget?.formatted(.number.grouping(.never))
        self.bucketButton.setTitle(bucket.name, for: .normal)
        self.bucketButton.menu = UIMenu(children: tree.buckets.map { option in
            UIAction(title: option.name, state: option.id == bucket.id ? .on : .off) { [weak self] _ in
                guard let self else { return }
                do {
                    try self.store.moveCategory(self.categoryID, to: option.id)
                } catch {
                    self.showCategoryError(error)
                }
                self.reload()
            }
        })
        if rows { self.tableView.reloadData() }
    }

    /// Saves the name and budget together; a rejected entry puts back what was saved.
    private func saveDetails() {
        guard let category = self.category else { return }
        let budgetText = (self.budgetField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            var budget: Decimal?
            if !budgetText.isEmpty {
                guard let parsed = TransactionAmount.parse(budgetText) else {
                    throw CategoryStore.CategoryError.invalidBudget
                }
                budget = parsed
            }
            if self.nameField.text != category.name || budget != category.monthlyBudget {
                try self.store.updateCategory(self.categoryID, name: self.nameField.text ?? "", monthlyBudget: budget)
            }
        } catch {
            self.showCategoryError(error)
        }
        self.reload(rows: false)
    }

    private func addSubcategory() {
        self.promptForName(title: "New Subcategory", actionTitle: "Add") { [weak self] name in
            guard let self else { return }
            try self.store.addSubcategory(named: name, to: self.categoryID)
            self.reload()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .details: self.detailRows.count
        case .subcategories: (self.category?.subcategories.count ?? 0) + 1
        case .delete: 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .details: return self.detailRows[indexPath.row]
        case .delete: return self.deleteRow
        case .subcategories:
            guard let subcategories = self.category?.subcategories, indexPath.row < subcategories.count else {
                return self.addRow
            }
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            var content = cell.defaultContentConfiguration()
            content.text = subcategories[indexPath.row].name
            cell.contentConfiguration = content
            cell.accessibilityHint = "Renames the subcategory."
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section) == .subcategories ? "Subcategories" : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .details: "Leave the budget blank to keep this category out of Budgets."
        case .subcategories: "A transaction can be narrowed to a subcategory, which counts toward this category. Deleting a subcategory keeps its transactions in the category."
        case .delete: nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
        let cell = tableView.cellForRow(at: indexPath)
        if cell === self.addRow {
            self.addSubcategory()
        } else if cell === self.deleteRow, let category = self.category {
            self.confirmDeletingCategory(category, from: cell, store: self.store, transactionStore: self.transactionStore) {
                [weak self] in _ = self?.navigationController?.popViewController(animated: true)
            }
        } else if let subcategories = self.category?.subcategories, Section(rawValue: indexPath.section) == .subcategories,
                  indexPath.row < subcategories.count {
            let subcategory = subcategories[indexPath.row]
            self.promptForName(title: "Rename Subcategory", name: subcategory.name, actionTitle: "Save") { [weak self] name in
                guard let self else { return }
                try self.store.renameSubcategory(subcategory.id, in: self.categoryID, to: name)
                self.reload()
            }
        }
    }

    override func tableView(
        _ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard Section(rawValue: indexPath.section) == .subcategories,
              let subcategories = self.category?.subcategories, indexPath.row < subcategories.count else { return nil }
        let subcategory = subcategories[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, complete in
            guard let self else { return complete(false) }
            do {
                try self.store.deleteSubcategory(subcategory.id, in: self.categoryID, transactionStore: self.transactionStore)
                complete(true)
            } catch {
                complete(false)
                self.showCategoryError(error)
            }
            self.reload()
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

extension CategoryEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.saveDetails()
    }
}
