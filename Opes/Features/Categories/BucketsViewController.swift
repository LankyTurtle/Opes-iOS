import UIKit

/// The buckets categories are grouped into, such as Income, Living and
/// Lifestyle. Reached from Budgets.
final class BucketsViewController: UITableViewController {
    private let store: CategoryStore
    private let transactionStore: TransactionStore
    private var buckets: [Bucket] = []

    init(store: CategoryStore = .shared, transactionStore: TransactionStore = .shared) {
        self.store = store
        self.transactionStore = transactionStore
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Buckets"
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = AppBarButtonItem.add(
            target: self, action: #selector(self.addBucket), accessibilityLabel: "Add bucket"
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reload()
    }

    private func reload() {
        self.buckets = self.store.tree().buckets
        self.tableView.reloadData()
    }

    @objc private func addBucket() {
        self.promptForName(title: "New Bucket", actionTitle: "Add") { [weak self] name in
            guard let self else { return }
            let bucket = try self.store.addBucket(named: name)
            self.reload()
            self.navigationController?.pushViewController(BucketViewController(bucketID: bucket.id), animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.buckets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let bucket = self.buckets[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = bucket.name
        let count = bucket.categories.count
        content.secondaryText = count == 0 ? "No categories" : count == 1 ? "1 category" : "\(count) categories"
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Every category belongs to a bucket. Transactions are given a category, and optionally one of its subcategories. Set a category’s monthly budget to show it in Budgets."
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.navigationController?.pushViewController(
            BucketViewController(bucketID: self.buckets[indexPath.row].id), animated: true
        )
    }

    override func tableView(
        _ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let bucket = self.buckets[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, complete in
            guard let self else { return complete(false) }
            // The row stays until the user has chosen what happens to its categories.
            complete(false)
            self.confirmDeletingBucket(
                bucket, from: tableView.cellForRow(at: indexPath),
                store: self.store, transactionStore: self.transactionStore
            ) { [weak self] in self?.reload() }
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
