import UIKit

/// One repeat: why it was called one, the terms it's projected on, changes the
/// user has set from future days, and the transactions it was read from.
///
/// Every edit is saved as it's made. The first one turns the repeat into a rule of
/// the user's own, which it stays until they undo their changes.
final class RecurrenceViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case summary
        case schedule
        case changes
        case transactions
        case actions
    }

    private let key: RecurrenceKey
    private let accountProvider: any AccountProviding
    private let transactionProvider: any TransactionProviding
    private let store: RecurrenceStore
    private let calendar = Calendar.autoupdatingCurrent

    private var item: RecurringTransaction?
    /// The repeat's transactions, newest first.
    private var members: [Transaction] = []
    private var summaryRow = UITableViewCell()

    private let amountField = UITextField()
    private let cadenceButton = UIButton(type: .system)
    private let nextDatePicker = UIDatePicker()
    private lazy var amountRow = FormRowCell(title: "Amount (AUD)", control: self.amountField, stretchesControl: true)
    private lazy var cadenceRow = FormRowCell(title: "Repeats", control: self.cadenceButton, stretchesControl: true)
    private lazy var nextDateRow = FormRowCell(title: "Next payment", control: self.nextDatePicker, stretchesControl: false)
    private let followRow = RecurrenceActionCell(title: "Use Amount and Dates From Transactions")

    private let addChangeRow = CategoryActionCell(title: "Add Change", style: .add)
    private let addTransactionsRow = CategoryActionCell(title: "Add Transactions", style: .add)
    private let undoRow = RecurrenceActionCell(title: "Undo My Changes")
    private let dismissRow = CategoryActionCell(title: "Not a Repeat", style: .delete)

    init(
        key: RecurrenceKey,
        accountProvider: any AccountProviding = AccountStore.shared,
        transactionProvider: any TransactionProviding = TransactionStore.shared,
        store: RecurrenceStore = .shared
    ) {
        self.key = key
        self.accountProvider = accountProvider
        self.transactionProvider = transactionProvider
        self.store = store
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = self.key.name
        self.navigationItem.largeTitleDisplayMode = .never
        self.tableView.keyboardDismissMode = .interactive

        self.amountField.font = .preferredFont(forTextStyle: .body)
        self.amountField.adjustsFontForContentSizeCategory = true
        self.amountField.textAlignment = .right
        self.amountField.keyboardType = .decimalPad
        self.amountField.accessibilityLabel = "Amount in AUD"
        self.amountField.delegate = self

        self.cadenceButton.showsMenuAsPrimaryAction = true
        self.cadenceButton.contentHorizontalAlignment = .trailing
        self.cadenceButton.accessibilityLabel = "Repeats"

        self.nextDatePicker.datePickerMode = .date
        self.nextDatePicker.preferredDatePickerStyle = .compact
        self.nextDatePicker.accessibilityLabel = "Next payment"
        self.nextDatePicker.addAction(UIAction { [weak self] _ in self?.nextDateChanged() }, for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reload()
    }

    /// Works the repeat out again from what's saved now, the same way the
    /// account's forecast does.
    private func reload() {
        let transactions = self.transactionProvider.transactions()
            .filter { $0.accountID == self.key.accountID && $0.date <= .now }
        let rules = self.store.rules().filter { $0.key.accountID == self.key.accountID }
        guard let item = RecurrenceFinder(calendar: self.calendar).find(in: transactions, rules: rules)
            .first(where: { $0.key == self.key }) else {
            // Dismissed, or no longer found after a transaction was deleted.
            self.navigationController?.popViewController(animated: true)
            return
        }
        self.item = item
        let ids = Set(item.transactionIDs)
        self.members = transactions.filter { ids.contains($0.id) }.sorted { $0.date > $1.date }
        self.summaryRow = RecurrenceRows.repeatRow(for: item, showsDisclosure: false, calendar: self.calendar)

        let schedule = item.plan.schedule
        self.amountField.text = abs(schedule.amount).formatted(.number.precision(.fractionLength(2)).grouping(.never))
        self.cadenceButton.setTitle(schedule.cadence.description.capitalizedFirst, for: .normal)
        var choices = RecurrenceCadence.choices
        if !choices.contains(schedule.cadence) { choices.insert(schedule.cadence, at: 0) }
        self.cadenceButton.menu = UIMenu(children: choices.map { cadence in
            UIAction(title: cadence.description.capitalizedFirst, state: cadence == schedule.cadence ? .on : .off) {
                [weak self] _ in self?.updateSchedule { $0.cadence = cadence }
            }
        })
        let tomorrow = self.tomorrow
        self.nextDatePicker.minimumDate = tomorrow
        self.nextDatePicker.date = self.nextScheduledDate(of: schedule) ?? tomorrow
        self.tableView.reloadData()
    }

    private var tomorrow: Date {
        let today = self.calendar.startOfDay(for: .now)
        return self.calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    /// When the current terms next land, ignoring any changes set after them.
    private func nextScheduledDate(of schedule: RecurrenceSchedule) -> Date? {
        let today = self.calendar.startOfDay(for: .now)
        guard let end = self.calendar.date(byAdding: .year, value: 2, to: today) else { return nil }
        return schedule.dates(after: today, through: end, calendar: self.calendar).first
    }

    // MARK: - Editing

    /// Saves a change to the rule, starting one from what was found if the user
    /// hasn't changed this repeat before.
    private func updateRule(_ change: (inout RecurrenceRule) throws -> Void) {
        guard let item = self.item else { return }
        var rule = self.store.rule(for: item)
        do {
            try change(&rule)
            self.store.save(rule)
        } catch {
            self.showError(error)
        }
        self.reload()
    }

    /// Sets the terms by hand: from here they stay as set rather than following
    /// the transactions.
    private func updateSchedule(_ change: (inout RecurrenceSchedule) -> Void) {
        guard let item = self.item else { return }
        self.updateRule { rule in
            var schedule = item.plan.schedule
            change(&schedule)
            rule.schedule = schedule
            rule.followsTransactions = false
        }
    }

    private func saveAmount() {
        guard let item = self.item else { return }
        let text = (self.amountField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = TransactionAmount.parse(text) else {
            self.showError(RecurrenceError.invalidAmount)
            self.reload()
            return
        }
        let signed = item.isIncome ? amount : -amount
        guard signed != item.plan.schedule.amount else { return }
        self.updateSchedule { $0.amount = signed }
    }

    private func nextDateChanged() {
        let date = self.calendar.startOfDay(for: self.nextDatePicker.date)
        guard let item = self.item, date != self.nextScheduledDate(of: item.plan.schedule) else { return }
        self.updateSchedule { $0.anchor = date }
    }

    private func editChange(_ change: RecurrenceChange?) {
        guard let item = self.item else { return }
        let today = self.calendar.startOfDay(for: .now)
        // A new change starts from the next payment, on the terms in force then.
        let next = item.plan.next(after: today, calendar: self.calendar)
        let terms = next.map { RecurrenceChange.Terms(amount: $0.amount, cadence: $0.cadence) }
            ?? RecurrenceChange.Terms(amount: item.amount, cadence: item.cadence)
        let onDelete: (() -> Void)? = change.map { change in
            { [weak self] in self?.updateRule { $0 = $0.removingChange(change.id) } }
        }
        let editor = RecurrenceChangeViewController(
            change: change, suggestedDate: next?.date ?? self.tomorrow, suggestedTerms: terms,
            isIncome: item.isIncome, minimumDate: self.tomorrow,
            onSave: { [weak self] change in
                guard let self else { return }
                let rule = try self.store.rule(for: item).settingChange(change, calendar: self.calendar)
                self.store.save(rule)
            },
            onDelete: onDelete
        )
        self.navigationController?.pushViewController(editor, animated: true)
    }

    private func addTransactions() {
        guard let item = self.item else { return }
        let memberIDs = Set(item.transactionIDs)
        let candidates = self.transactionProvider.transactions()
            .filter {
                $0.accountID == self.key.accountID && $0.date <= .now && ($0.amount > 0) == item.isIncome
                    && !memberIDs.contains($0.id)
            }
            .sorted { $0.date > $1.date }
        let picker = RecurrenceTransactionPickerViewController(transactions: candidates) { [weak self] ids in
            self?.updateRule { $0 = $0.adding(ids) }
        }
        self.navigationController?.pushViewController(picker, animated: true)
    }

    private func confirmUndo(from cell: UITableViewCell?) {
        let sheet = UIAlertController(
            title: "Undo your changes?",
            message: "This repeat goes back to what was found in the transactions, and any future changes you set are removed.",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "Undo My Changes", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.store.delete(self.key)
            self.reload()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(sheet, from: cell)
    }

    private func confirmDismiss(from cell: UITableViewCell?) {
        let sheet = UIAlertController(
            title: "Not a repeat?",
            message: "It won’t be projected in forecasts or found again. Its transactions count as everyday spending instead.",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "Not a Repeat", style: .destructive) { [weak self] _ in
            self?.updateRule { $0.isDismissed = true }
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(sheet, from: cell)
    }

    private func present(_ sheet: UIAlertController, from cell: UITableViewCell?) {
        if let popover = sheet.popoverPresentationController {
            let source: UIView = cell ?? self.view
            popover.sourceView = source
            popover.sourceRect = source.bounds
        }
        self.present(sheet, animated: true)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "Couldn’t save", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    // MARK: - Explanations

    /// Says why this was called a repeat, or that the user has taken it over.
    private var explanation: String? {
        guard let item = self.item else { return nil }
        let evidence = item.evidence
        let noun = item.isIncome ? "deposits" : "payments"
        if item.isEdited {
            return item.followsTransactions
                ? "You’ve changed this repeat. Its amount and dates still come from its \(evidence.count) \(noun): the usual gap and amount, counted on from the most recent."
                : "You’ve set its amount and dates yourself, so they no longer follow its transactions."
        }
        var sentences: [String] = []
        let apart = evidence.gaps.map { gaps in
            gaps.lowerBound == gaps.upperBound ? "\(gaps.lowerBound) days apart" : "\(gaps.lowerBound) to \(gaps.upperBound) days apart"
        } ?? "on a steady rhythm"
        let amounts = evidence.amounts.map { range -> String in
            let low = min(abs(range.lowerBound), abs(range.upperBound))
            let high = max(abs(range.lowerBound), abs(range.upperBound))
            return low == high
                ? "each for \(Self.currency(low))"
                : "for \(Self.currency(low)) to \(Self.currency(high)); the middle amount, \(Self.currency(abs(item.amount))), is projected"
        } ?? ""
        sentences.append("Found because \(evidence.count) \(noun) on this account are summarised “\(item.merchant)” and landed \(apart), \(amounts).")
        sentences.append(item.isIncome
            ? "Money in only has to arrive on a steady rhythm."
            : "Money out also has to stay within 20% of the usual amount, so a shop visited on a rhythm isn’t mistaken for a bill.")
        if let last = evidence.last {
            sentences.append("Its next payment is counted on from the most recent, on \(RecurrenceRows.formatted(last, calendar: self.calendar)).")
        }
        return sentences.joined(separator: " ")
    }

    private static func currency(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "AUD"))
    }

    // MARK: - Table

    private func change(at indexPath: IndexPath) -> RecurrenceChange? {
        guard Section(rawValue: indexPath.section) == .changes, let changes = self.item?.plan.changes,
              changes.indices.contains(indexPath.row) else { return nil }
        return changes[indexPath.row]
    }

    private func member(at indexPath: IndexPath) -> Transaction? {
        guard Section(rawValue: indexPath.section) == .transactions, self.members.indices.contains(indexPath.row) else {
            return nil
        }
        return self.members[indexPath.row]
    }

    private var scheduleRows: [UITableViewCell] {
        [self.amountRow, self.cadenceRow, self.nextDateRow] + (self.item?.followsTransactions == false ? [self.followRow] : [])
    }

    private var actionRows: [UITableViewCell] {
        (self.item?.isEdited == true ? [self.undoRow] : []) + [self.dismissRow]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.item == nil ? 0 : Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .summary: 1
        case .schedule: self.scheduleRows.count
        case .changes: (self.item?.plan.changes.count ?? 0) + 1
        case .transactions: self.members.count + 1
        case .actions: self.actionRows.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .summary: return self.summaryRow
        case .schedule: return self.scheduleRows[indexPath.row]
        case .actions: return self.actionRows[indexPath.row]
        case .changes:
            guard let change = self.change(at: indexPath) else { return self.addChangeRow }
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            var content = UIListContentConfiguration.subtitleCell()
            let date = RecurrenceRows.formatted(change.date, calendar: self.calendar)
            if let terms = change.terms {
                content.text = "From \(date)"
                content.secondaryText = "\(terms.amount.formatted(.currency(code: "AUD"))) · \(terms.cadence.description)"
            } else {
                content.text = "Stops \(date)"
                content.secondaryText = "Nothing is projected from this day"
            }
            content.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return cell
        case .transactions:
            guard let transaction = self.member(at: indexPath) else { return self.addTransactionsRow }
            return RecurrenceRows.transactionRow(for: transaction)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .summary, .actions: nil
        case .schedule: "Repeats"
        case .changes: "Future Changes"
        case .transactions: "Transactions"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .summary: self.explanation
        case .schedule:
            self.item?.followsTransactions == false
                ? nil : "Changing any of these sets them yourself, instead of working them out from the transactions."
        case .changes: "Stop this repeat, or change its amount, how often it lands, or its pay day, from a future day."
        case .transactions:
            "New transactions on this account summarised “\(self.key.name)” join by themselves. Swipe to remove one that doesn’t belong."
        case .actions: nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
        let cell = tableView.cellForRow(at: indexPath)
        if cell === self.followRow {
            self.updateRule { $0.followsTransactions = true }
        } else if cell === self.addChangeRow {
            self.editChange(nil)
        } else if cell === self.addTransactionsRow {
            self.addTransactions()
        } else if cell === self.undoRow {
            self.confirmUndo(from: cell)
        } else if cell === self.dismissRow {
            self.confirmDismiss(from: cell)
        } else if let change = self.change(at: indexPath) {
            self.editChange(change)
        } else if let transaction = self.member(at: indexPath) {
            self.navigationController?.pushViewController(
                TransactionDetailsViewController(
                    transaction: transaction,
                    accountProvider: self.accountProvider,
                    transactionProvider: self.transactionProvider
                ),
                animated: true
            )
        }
    }

    override func tableView(
        _ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        if let change = self.change(at: indexPath) {
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, complete in
                self?.updateRule { $0 = $0.removingChange(change.id) }
                complete(true)
            }
            delete.image = UIImage(systemName: "trash")
            return UISwipeActionsConfiguration(actions: [delete])
        }
        if let transaction = self.member(at: indexPath) {
            let remove = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, complete in
                self?.updateRule { $0 = $0.removing(transaction) }
                complete(true)
            }
            remove.image = UIImage(systemName: "minus.circle")
            return UISwipeActionsConfiguration(actions: [remove])
        }
        return nil
    }
}

extension RecurrenceViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.saveAmount()
    }
}

/// A row that acts as a button without adding or deleting anything.
final class RecurrenceActionCell: UITableViewCell {
    init(title: String) {
        super.init(style: .default, reuseIdentifier: nil)
        var content = self.defaultContentConfiguration()
        content.text = title
        content.textProperties.numberOfLines = 0
        content.textProperties.color = .tintColor
        content.textProperties.alignment = .center
        self.contentConfiguration = content
        self.accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

extension String {
    /// `Fortnightly` from `fortnightly`, for a menu or a button.
    var capitalizedFirst: String {
        self.prefix(1).uppercased() + self.dropFirst()
    }
}
