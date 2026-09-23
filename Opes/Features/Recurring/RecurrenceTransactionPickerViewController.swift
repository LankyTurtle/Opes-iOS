import UIKit

/// Picks transactions to add to a repeat, from the ones on its account that move
/// money the same way and aren't in it already.
final class RecurrenceTransactionPickerViewController: UITableViewController {
    private let transactions: [Transaction]
    private let onAdd: (Set<UUID>) -> Void
    private var selected = Set<UUID>()
    private lazy var addButton = UIBarButtonItem(
        title: "Add", style: .done, target: self, action: #selector(self.add)
    )

    /// `transactions` newest first.
    init(transactions: [Transaction], onAdd: @escaping (Set<UUID>) -> Void) {
        self.transactions = transactions
        self.onAdd = onAdd
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Add Transactions"
        self.navigationItem.largeTitleDisplayMode = .never
        self.addButton.isEnabled = false
        self.navigationItem.rightBarButtonItem = self.addButton
    }

    @objc private func add() {
        self.onAdd(self.selected)
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.transactions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let transaction = self.transactions[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var details = UIListContentConfiguration.subtitleCell()
        details.text = transaction.summary
        details.textProperties.numberOfLines = 1
        details.textProperties.lineBreakMode = .byTruncatingTail
        details.secondaryText = "\(transaction.formattedDate) · \(transaction.formattedAmount)"
        details.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = details
        cell.accessoryType = self.selected.contains(transaction.id) ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        self.transactions.isEmpty
            ? "There are no other transactions on this account that move money this way."
            : "Transactions from this account that move money the same way. Added ones stay in the repeat whatever their summary."
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = self.transactions[indexPath.row].id
        if self.selected.remove(id) == nil { self.selected.insert(id) }
        tableView.cellForRow(at: indexPath)?.accessoryType = self.selected.contains(id) ? .checkmark : .none
        self.addButton.isEnabled = !self.selected.isEmpty
    }
}
