import UIKit

final class PayCyclesViewController: UITableViewController {
    private let store: PayCycleStore
    private let transactionProvider: any TransactionProviding
    private let onChange: () -> Void
    private let calculator = NextPayDateCalculator()
    private var cycles: [PayCycle] = []
    private var transactions: [Transaction] = []

    init(
        store: PayCycleStore,
        transactionProvider: any TransactionProviding = SampleTransactionProvider(),
        onChange: @escaping () -> Void
    ) {
        self.store = store
        self.transactionProvider = transactionProvider
        self.onChange = onChange
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Pay Cycles"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(self.addCycle)
        )
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PayCycleCell")
        self.reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reload()
    }

    @objc private func addCycle() {
        self.showEditor(for: nil)
    }

    private func reload() {
        self.transactions = self.transactionProvider.transactions()
        self.cycles = self.store.load().sorted { lhs, rhs in
            let left = self.calculator.nextPayDate(for: lhs) ?? .distantFuture
            let right = self.calculator.nextPayDate(for: rhs) ?? .distantFuture
            return left < right
        }
        self.tableView.reloadData()
        self.tableView.backgroundView = self.cycles.isEmpty ? Self.emptyView() : nil
    }

    private func showEditor(for cycle: PayCycle?) {
        let editor = PayCycleEditorViewController(cycle: cycle, transactions: self.transactions) { [weak self] saved in
            guard let self else { return }
            self.store.upsert(saved)
            self.onChange()
        }
        self.navigationController?.pushViewController(editor, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.cycles.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cycle = self.cycles[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "PayCycleCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = cycle.name
        let linkedTransaction = self.transactions.first { $0.id == cycle.linkedTransactionID }
        if let display = self.calculator.display(for: cycle) {
            let date = display.date.formatted(date: .abbreviated, time: .omitted)
            let amount = cycle.amount.formatted(.currency(code: "AUD"))
            let schedule = cycle.isEnabled
                ? "\(amount) · \(display.countdown) · \(date)"
                : "Disabled · \(amount) · \(date)"
            content.secondaryText = linkedTransaction.map { "\(schedule)\nLinked: \($0.merchant) · \($0.formattedAmount)" } ?? schedule
        } else {
            content.secondaryText = "No upcoming pay date"
        }
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.showEditor(for: self.cycles[indexPath.row])
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let cycle = self.cycles[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, complete in
            self?.store.delete(id: cycle.id)
            self?.onChange()
            self?.reload()
            complete(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        var cycle = self.cycles[indexPath.row]
        let title = cycle.isEnabled ? "Disable" : "Enable"
        let toggle = UIContextualAction(style: .normal, title: title) { [weak self] _, _, complete in
            cycle.isEnabled.toggle()
            self?.store.upsert(cycle)
            self?.onChange()
            self?.reload()
            complete(true)
        }
        toggle.backgroundColor = .systemBlue
        return UISwipeActionsConfiguration(actions: [toggle])
    }

    private static func emptyView() -> UIView {
        let label = UILabel()
        label.text = "No pay cycles yet\nTap + to add one."
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }
}
