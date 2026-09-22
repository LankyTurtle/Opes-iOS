import UIKit

/// One bucket: its name and the categories in it.
final class BucketViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case name
        case categories
        case delete
    }

    private let bucketID: Bucket.ID
    private let store: CategoryStore
    private let transactionStore: TransactionStore
    private var bucket: Bucket?

    private let nameField = UITextField()
    private lazy var nameRow = FormRowCell(title: "Name", control: self.nameField, stretchesControl: true)
    private let addRow = CategoryActionCell(title: "Add Category", style: .add)
    private let deleteRow = CategoryActionCell(title: "Delete Bucket", style: .delete)

    init(bucketID: Bucket.ID, store: CategoryStore = .shared, transactionStore: TransactionStore = .shared) {
        self.bucketID = bucketID
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
        self.nameField.font = .preferredFont(forTextStyle: .body)
        self.nameField.adjustsFontForContentSizeCategory = true
        self.nameField.textAlignment = .right
        self.nameField.autocapitalizationType = .sentences
        self.nameField.clearButtonMode = .whileEditing
        self.nameField.returnKeyType = .done
        self.nameField.accessibilityLabel = "Bucket name"
        self.nameField.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reload()
    }

    private func reload() {
        guard let bucket = self.store.tree().buckets.first(where: { $0.id == self.bucketID }) else {
            // Deleted, here or while this screen was out of view.
            self.navigationController?.popViewController(animated: true)
            return
        }
        self.bucket = bucket
        self.title = bucket.name
        self.nameField.text = bucket.name
        self.tableView.reloadData()
    }

    private func addCategory() {
        self.promptForName(title: "New Category", actionTitle: "Add") { [weak self] name in
            guard let self else { return }
            let category = try self.store.addCategory(named: name, to: self.bucketID)
            self.reload()
            self.navigationController?.pushViewController(
                CategoryEditorViewController(categoryID: category.id), animated: true
            )
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section) == .categories ? (self.bucket?.categories.count ?? 0) + 1 : 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .name: return self.nameRow
        case .delete: return self.deleteRow
        case .categories:
            guard let categories = self.bucket?.categories, indexPath.row < categories.count else { return self.addRow }
            return CategorySummaryCell(category: categories[indexPath.row])
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section) == .categories ? "Categories" : nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
        let cell = tableView.cellForRow(at: indexPath)
        if cell === self.addRow {
            self.addCategory()
        } else if cell === self.deleteRow, let bucket = self.bucket {
            self.confirmDeletingBucket(bucket, from: cell, store: self.store, transactionStore: self.transactionStore) {
                [weak self] in _ = self?.navigationController?.popViewController(animated: true)
            }
        } else if let categories = self.bucket?.categories, Section(rawValue: indexPath.section) == .categories,
                  indexPath.row < categories.count {
            self.navigationController?.pushViewController(
                CategoryEditorViewController(categoryID: categories[indexPath.row].id), animated: true
            )
        }
    }

    override func tableView(
        _ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard Section(rawValue: indexPath.section) == .categories,
              let categories = self.bucket?.categories, indexPath.row < categories.count else { return nil }
        let category = categories[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, complete in
            guard let self else { return complete(false) }
            // The row stays until the user has chosen where its transactions go.
            complete(false)
            self.confirmDeletingCategory(
                category, from: tableView.cellForRow(at: indexPath),
                store: self.store, transactionStore: self.transactionStore
            ) { [weak self] in self?.reload() }
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

extension BucketViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let bucket = self.bucket, textField.text != bucket.name else { return }
        do {
            try self.store.renameBucket(self.bucketID, to: textField.text ?? "")
        } catch {
            self.showCategoryError(error)
        }
        // Shows the saved name: trimmed, or the old one if it was rejected.
        self.reload()
    }
}

/// A category in a list: its symbol, name, and budget.
final class CategorySummaryCell: UITableViewCell {
    init(category: TransactionCategory) {
        super.init(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.image = UIImage(systemName: category.symbolName)
        content.text = category.name
        var details = [category.monthlyBudget.map { "\($0.formatted(.currency(code: "AUD"))) a month" } ?? "No budget"]
        switch category.subcategories.count {
        case 0: break
        case 1: details.append("1 subcategory")
        case let count: details.append("\(count) subcategories")
        }
        content.secondaryText = details.joined(separator: " · ")
        content.secondaryTextProperties.color = .secondaryLabel
        self.contentConfiguration = content
        self.accessoryType = .disclosureIndicator
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// A row that acts as a button: adding something, or deleting the screen's subject.
final class CategoryActionCell: UITableViewCell {
    enum Style {
        case add
        case delete
    }

    init(title: String, style: Style) {
        super.init(style: .default, reuseIdentifier: nil)
        var content = self.defaultContentConfiguration()
        content.text = title
        content.textProperties.numberOfLines = 0
        switch style {
        case .add:
            content.image = UIImage(systemName: "plus.circle.fill")
            content.textProperties.color = .tintColor
        case .delete:
            content.textProperties.color = .systemRed
            content.textProperties.alignment = .center
        }
        self.contentConfiguration = content
        self.accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
