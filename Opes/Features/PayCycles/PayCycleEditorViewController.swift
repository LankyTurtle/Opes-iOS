import UIKit

/// The pay cycle form, laid out as an inset-grouped list so each control sits in a
/// system row — a borderless text field against the trailing edge, a section header
/// for its label — rather than in hand-built boxes stacked down the screen.
final class PayCycleEditorViewController: UITableViewController {
    private let existingCycle: PayCycle?
    private let onSave: (PayCycle) -> Void
    private let calculator = NextPayDateCalculator()

    private let nameField = UITextField()
    private let amountField = UITextField()
    private let transactionButton = UIButton(type: .system)
    private let accountButton = UIButton(type: .system)
    private let frequencyControl = UISegmentedControl(items: PayFrequency.allCases.map(\.title))
    private let ruleControl = UISegmentedControl(items: ["First", "Last", "Specific"])
    private let weekdayControl = UISegmentedControl(
        items: Calendar.autoupdatingCurrent.shortWeekdaySymbols
    )
    private let datePicker = UIDatePicker()
    private let adjustmentControl = UISegmentedControl(items: ["Exact", "Back", "Forward"])
    private let stateButton = UIButton(type: .system)
    private let enabledSwitch = UISwitch()

    // The rows are built once and rearranged as the form changes, rather than
    // dequeued, so every control keeps its state — and its first responder — while
    // the sections around it come and go.
    private lazy var nameRow = FormRowCell(
        title: "Name",
        control: self.nameField,
        stretchesControl: true
    )
    private lazy var amountRow = FormRowCell(
        title: "Amount (AUD)",
        control: self.amountField,
        stretchesControl: true
    )
    private lazy var transactionRow = FormRowCell(
        title: "Linked transaction",
        control: self.transactionButton,
        stretchesControl: true
    )
    // The segmented controls sit on the grouped background under their section
    // header rather than in a row, because each already draws its own selected pill
    // and a row behind it reads as a second surface stacked under the first.
    private lazy var frequencyControlView = FormControlView(control: self.frequencyControl)
    private lazy var ruleControlView = FormControlView(control: self.ruleControl)
    private lazy var weekdayControlView = FormControlView(control: self.weekdayControl)
    private lazy var adjustmentControlView = FormControlView(control: self.adjustmentControl)

    private lazy var accountRow = FormRowCell(
        title: "Paid into",
        control: self.accountButton,
        stretchesControl: true
    )
    private lazy var dateRow = FormRowCell(
        title: "Day of month",
        control: self.datePicker,
        stretchesControl: false
    )
    private lazy var stateRow = FormRowCell(
        title: "Public holiday calendar",
        control: self.stateButton,
        stretchesControl: true
    )
    private lazy var enabledRow = FormRowCell(
        title: "Enabled",
        control: self.enabledSwitch,
        stretchesControl: false
    )

    private var sections: [FormSection] = []

    private var frequency: PayFrequency
    private var rule: PayDateRule
    private var adjustment: BusinessDayAdjustment
    private var state: AustralianStateOrTerritory
    private var weekday: Int
    private var linkedTransactionID: Transaction.ID?
    private var accountID: AccountPreview.ID?
    private let transactions: [Transaction]
    private let accounts: [AccountPreview]

    init(
        cycle: PayCycle?,
        transactions: [Transaction],
        accounts: [AccountPreview],
        onSave: @escaping (PayCycle) -> Void
    ) {
        self.existingCycle = cycle
        self.onSave = onSave
        self.frequency = cycle?.frequency ?? .monthly
        self.rule = cycle?.rule ?? .firstDay
        self.adjustment = cycle?.businessDayAdjustment ?? .none
        self.state = cycle?.stateOrTerritory ?? .newSouthWales
        self.weekday = cycle?.rule.weekday ?? Calendar.autoupdatingCurrent.firstWeekday
        self.linkedTransactionID = cycle?.linkedTransactionID
        self.accountID = cycle?.accountID
        self.transactions = transactions
        self.accounts = accounts
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = self.existingCycle == nil ? "Add Pay Cycle" : "Edit Pay Cycle"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(self.save)
        )
        self.tableView.keyboardDismissMode = .interactive

        self.configureControls()
        self.refreshForm()
    }

    private func configureControls() {
        // Borderless, because the row supplies the chrome a rounded-rect field would
        // otherwise draw inside it.
        self.nameField.borderStyle = .none
        self.nameField.placeholder = "Salary"
        self.nameField.text = self.existingCycle?.name
        self.nameField.textAlignment = .right
        self.nameField.font = .preferredFont(forTextStyle: .body)
        self.nameField.adjustsFontForContentSizeCategory = true
        self.nameField.autocapitalizationType = .words
        self.nameField.clearButtonMode = .whileEditing
        self.nameField.returnKeyType = .done
        self.nameField.delegate = self
        self.nameField.accessibilityLabel = "Name"

        self.amountField.borderStyle = .none
        self.amountField.placeholder = "0.00"
        self.amountField.text = self.existingCycle?.amount.formatted(.number.precision(.fractionLength(2)))
        self.amountField.textAlignment = .right
        self.amountField.font = .preferredFont(forTextStyle: .body)
        self.amountField.adjustsFontForContentSizeCategory = true
        self.amountField.keyboardType = .decimalPad
        self.amountField.clearButtonMode = .whileEditing
        self.amountField.accessibilityLabel = "Pay amount in Australian dollars"

        self.configureMenuButton(self.transactionButton)
        self.configureMenuButton(self.accountButton)
        self.configureMenuButton(self.stateButton)

        self.frequencyControl.selectedSegmentIndex = PayFrequency.allCases.firstIndex(of: self.frequency) ?? 2
        self.frequencyControl.addAction(
            UIAction { [weak self] _ in
                self?.frequencyChanged()
            },
            for: .valueChanged
        )

        self.ruleControl.selectedSegmentIndex = switch self.rule.kind {
        case .firstDay: 0
        case .lastDay: 1
        case .specific: 2
        }
        self.ruleControl.addAction(
            UIAction { [weak self] _ in
                self?.ruleChanged()
            },
            for: .valueChanged
        )

        self.weekdayControl.selectedSegmentIndex = max(min(self.weekday - 1, 6), 0)
        self.weekdayControl.addAction(
            UIAction { [weak self] _ in
                guard let self else {
                    return
                }

                self.weekday = self.weekdayControl.selectedSegmentIndex + 1
                self.reloadPreview()
            },
            for: .valueChanged
        )

        self.datePicker.datePickerMode = .date
        self.datePicker.preferredDatePickerStyle = .compact
        self.datePicker.addTarget(self, action: #selector(self.dateChanged), for: .valueChanged)
        if let month = self.rule.month, let day = self.rule.day {
            self.datePicker.date = Calendar.autoupdatingCurrent.date(from: DateComponents(year: 2024, month: month, day: day)) ?? .now
        } else if let day = self.rule.day {
            self.datePicker.date = Calendar.autoupdatingCurrent.date(from: DateComponents(year: 2024, month: 1, day: day)) ?? .now
        }

        self.adjustmentControl.selectedSegmentIndex = BusinessDayAdjustment.allCases.firstIndex(of: self.adjustment) ?? 0
        self.adjustmentControl.addAction(
            UIAction { [weak self] _ in
                self?.adjustmentChanged()
            },
            for: .valueChanged
        )

        self.enabledSwitch.isOn = self.existingCycle?.isEnabled ?? true
        self.enabledSwitch.accessibilityLabel = "Enabled"
    }

    /// Rebuilds the section list for the current frequency and adjustment, then
    /// reloads. Row order and titles are the only thing that changes; the controls
    /// themselves are long-lived.
    private func refreshForm() {
        self.configureTransactionButton()
        self.configureAccountButton()
        self.configureStateButton()

        var sections: [FormSection] = [
            FormSection(rows: [self.nameRow, self.amountRow, self.accountRow, self.transactionRow]),
            FormSection(header: "Frequency", control: self.frequencyControlView),
        ]

        if self.frequency != .daily {
            sections.append(FormSection(header: "When", control: self.ruleControlView))

            if self.ruleControl.selectedSegmentIndex == 2 {
                switch self.frequency {
                case .weekly:
                    sections.append(FormSection(header: "Weekday", control: self.weekdayControlView))
                case .monthly:
                    sections.append(FormSection(rows: [self.makeDateRow(titled: "Day of month")]))
                case .yearly:
                    sections.append(FormSection(rows: [self.makeDateRow(titled: "Month and day")]))
                case .daily:
                    break
                }
            }
        }

        sections.append(
            FormSection(header: "If weekend or public holiday", control: self.adjustmentControlView)
        )
        if self.adjustment != .none {
            sections.append(FormSection(rows: [self.stateRow]))
        }

        // The preview reads as a grouped footer, which is where a form explains the
        // consequence of the choices above it.
        sections.append(FormSection(rows: [self.enabledRow], showsPreviewFooter: true))

        self.sections = sections
        self.tableView.reloadData()
    }

    private func makeDateRow(titled title: String) -> UITableViewCell {
        self.dateRow.title = title
        self.datePicker.accessibilityLabel = title
        return self.dateRow
    }

    private func configureMenuButton(_ button: UIButton) {
        button.showsMenuAsPrimaryAction = true
        // Trailing, so the choice sits where a grouped row shows its value.
        button.contentHorizontalAlignment = .trailing
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.lineBreakMode = .byTruncatingTail
    }

    /// Which account the pay lands in, so a forecast for that account can count it.
    private func configureAccountButton() {
        let selected = self.accounts.first { $0.id == self.accountID }
        self.accountButton.menu = UIMenu(children: [
            UIAction(title: "No account", state: selected == nil ? .on : .off) { [weak self] _ in
                self?.accountID = nil
                self?.refreshForm()
            },
        ] + self.accounts.map { account in
            UIAction(
                title: "\(account.name) · \(account.institution)",
                state: account.id == self.accountID ? .on : .off
            ) { [weak self] _ in
                self?.accountID = account.id
                self?.refreshForm()
            }
        })
        self.accountButton.setTitle(selected?.name ?? "No account", for: .normal)
    }

    private func configureStateButton() {
        self.stateButton.menu = UIMenu(children: AustralianStateOrTerritory.allCases.map { state in
            UIAction(title: state.title, state: state == self.state ? .on : .off) { [weak self] _ in
                self?.state = state
                self?.refreshForm()
            }
        })
        self.stateButton.setTitle(self.state.title, for: .normal)
    }

    /// A pay cycle is linked to a deposit, so the menu offers recent money in
    /// rather than a year of every card tap — with whatever is already linked kept
    /// in the list however old it is.
    private var linkableTransactions: [Transaction] {
        let selected = self.transactions.first { $0.id == self.linkedTransactionID }
        let recentDeposits = self.transactions
            .filter { $0.amount > 0 && $0.id != selected?.id }
            .sorted { $0.date > $1.date }
            .prefix(Self.linkableTransactionLimit)

        return ([selected].compactMap { $0 } + recentDeposits)
            .sorted { $0.date > $1.date }
    }

    private static let linkableTransactionLimit = 20

    private func configureTransactionButton() {
        let selected = self.transactions.first { $0.id == self.linkedTransactionID }
        self.transactionButton.menu = UIMenu(children: [
            UIAction(title: "No linked transaction", state: selected == nil ? .on : .off) { [weak self] _ in
                self?.linkedTransactionID = nil
                self?.refreshForm()
            },
        ] + self.linkableTransactions.map { transaction in
            let title = "\(transaction.merchant) · \(transaction.formattedAmount) · \(transaction.formattedDate)"
            return UIAction(title: title, state: transaction.id == self.linkedTransactionID ? .on : .off) { [weak self] _ in
                self?.linkedTransactionID = transaction.id
                self?.refreshForm()
            }
        })
        self.transactionButton.setTitle(
            selected.map { "\($0.merchant) · \($0.formattedAmount)" } ?? "No linked transaction",
            for: .normal
        )
    }

    /// Only the schedule feeds the preview — name, amount and the enabled switch
    /// don't move the next pay date — so the footer is refreshed from the controls
    /// that do, rather than on every keystroke.
    private var previewText: String {
        let cycle = self.makeCycle(name: self.nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Pay")
        guard let display = self.calculator.display(for: cycle) else {
            return "No upcoming pay date could be calculated."
        }
        return "Next pay: \(display.countdown), \(display.date.formatted(date: .complete, time: .omitted))"
    }

    /// Reloads the footer's own section, which leaves the date picker and any field
    /// being edited elsewhere in the form untouched.
    private func reloadPreview() {
        guard let section = self.sections.firstIndex(where: \.showsPreviewFooter) else {
            return
        }

        self.tableView.reloadSections(IndexSet(integer: section), with: .none)
    }

    private func makeCycle(name: String) -> PayCycle {
        let rule: PayDateRule
        switch self.frequency {
        case .daily:
            rule = .firstDay
        case .weekly:
            rule = self.ruleControl.selectedSegmentIndex == 2 ? .weekly(weekday: self.weekday) : self.boundaryRule()
        case .monthly:
            rule = self.ruleControl.selectedSegmentIndex == 2
                ? .monthly(day: Calendar.autoupdatingCurrent.component(.day, from: self.datePicker.date))
                : self.boundaryRule()
        case .yearly:
            let components = Calendar.autoupdatingCurrent.dateComponents([.month, .day], from: self.datePicker.date)
            rule = self.ruleControl.selectedSegmentIndex == 2
                ? .yearly(month: components.month ?? 1, day: components.day ?? 1)
                : self.boundaryRule()
        }
        return PayCycle(
            id: self.existingCycle?.id ?? UUID(),
            name: name,
            amount: self.amount(),
            linkedTransactionID: self.linkedTransactionID,
            accountID: self.accountID,
            frequency: self.frequency,
            rule: rule,
            businessDayAdjustment: self.adjustment,
            stateOrTerritory: self.state,
            isEnabled: self.enabledSwitch.isOn
        )
    }

    private func boundaryRule() -> PayDateRule {
        self.ruleControl.selectedSegmentIndex == 1 ? .lastDay : .firstDay
    }

    private func frequencyChanged() {
        self.frequency = PayFrequency.allCases[self.frequencyControl.selectedSegmentIndex]
        self.refreshForm()
    }

    private func ruleChanged() {
        self.refreshForm()
    }

    @objc private func dateChanged() {
        self.reloadPreview()
    }

    private func adjustmentChanged() {
        self.adjustment = BusinessDayAdjustment.allCases[self.adjustmentControl.selectedSegmentIndex]
        self.refreshForm()
    }

    @objc private func save() {
        let name = self.nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else {
            let alert = UIAlertController(title: "Name required", message: "Give this pay cycle a name so you can recognise it on Home.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        guard self.amount() > 0 else {
            let alert = UIAlertController(title: "Amount required", message: "Enter a pay amount greater than zero.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        self.onSave(self.makeCycle(name: name))
        self.navigationController?.popViewController(animated: true)
    }

    private func amount() -> Decimal {
        let input = self.amountField.text?.replacingOccurrences(of: ",", with: "") ?? ""
        return Decimal(string: input, locale: Locale(identifier: "en_AU")) ?? 0
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.sections[section].rows.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        self.sections[indexPath.section].rows[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        self.sections[section].header
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        self.sections[section].showsPreviewFooter ? self.previewText : nil
    }

    /// A section carrying a control has no rows, so its footer is where the control
    /// lands: on the background, directly under its own header. Returning `nil`
    /// leaves the preview section to the footer title above.
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        self.sections[section].control
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        // Anywhere in a text row starts editing, the way a Contacts field does,
        // rather than only the width the text itself occupies.
        let row = self.sections[indexPath.section].rows[indexPath.row]
        if row === self.nameRow {
            self.nameField.becomeFirstResponder()
        } else if row === self.amountRow {
            self.amountField.becomeFirstResponder()
        }
    }
}

extension PayCycleEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private struct FormSection {
    var header: String?
    var rows: [UITableViewCell] = []
    /// Shown under the header on the plain background, in place of any rows.
    var control: UIView?
    var showsPreviewFooter = false
}
