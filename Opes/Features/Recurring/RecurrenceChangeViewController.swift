import UIKit

/// Sets a change to a repeat from a future day: it stops, or carries on for a
/// different amount, how often, or from a different pay day.
final class RecurrenceChangeViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case kind
        case details
        case delete
    }

    private let existing: RecurrenceChange?
    private let isIncome: Bool
    private let onSave: (RecurrenceChange) throws -> Void
    private let onDelete: (() -> Void)?
    private let calendar = Calendar.autoupdatingCurrent

    private var stops: Bool
    private var cadence: RecurrenceCadence

    private let kindControl = UISegmentedControl(items: ["Change", "Stop"])
    private lazy var kindView = FormControlView(control: self.kindControl)
    private let datePicker = UIDatePicker()
    private let amountField = UITextField()
    private let cadenceButton = UIButton(type: .system)
    private lazy var dateRow = FormRowCell(title: "First payment", control: self.datePicker, stretchesControl: false)
    private lazy var amountRow = FormRowCell(title: "Amount (AUD)", control: self.amountField, stretchesControl: true)
    private lazy var cadenceRow = FormRowCell(title: "Repeats", control: self.cadenceButton, stretchesControl: true)
    private let deleteRow = CategoryActionCell(title: "Delete Change", style: .delete)

    /// `suggestedDate` and `suggestedTerms` fill in a new change: the next payment
    /// and the terms it would land on.
    init(
        change: RecurrenceChange?,
        suggestedDate: Date,
        suggestedTerms: RecurrenceChange.Terms,
        isIncome: Bool,
        minimumDate: Date,
        onSave: @escaping (RecurrenceChange) throws -> Void,
        onDelete: (() -> Void)?
    ) {
        self.existing = change
        self.isIncome = isIncome
        self.onSave = onSave
        self.onDelete = onDelete
        self.stops = change != nil && change?.terms == nil
        let terms = change?.terms ?? suggestedTerms
        self.cadence = terms.cadence
        super.init(style: .insetGrouped)

        self.datePicker.minimumDate = minimumDate
        self.datePicker.date = max(change?.date ?? suggestedDate, minimumDate)
        self.amountField.text = abs(terms.amount).formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = self.existing == nil ? "Add Change" : "Edit Change"
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(self.save)
        )
        self.tableView.keyboardDismissMode = .interactive

        self.kindControl.selectedSegmentIndex = self.stops ? 1 : 0
        self.kindControl.addAction(UIAction { [weak self] _ in self?.kindChanged() }, for: .valueChanged)

        self.datePicker.datePickerMode = .date
        self.datePicker.preferredDatePickerStyle = .compact
        self.datePicker.contentHorizontalAlignment = .trailing

        self.amountField.font = .preferredFont(forTextStyle: .body)
        self.amountField.adjustsFontForContentSizeCategory = true
        self.amountField.textAlignment = .right
        self.amountField.keyboardType = .decimalPad
        self.amountField.accessibilityLabel = "Amount in AUD"

        self.cadenceButton.showsMenuAsPrimaryAction = true
        self.cadenceButton.contentHorizontalAlignment = .trailing
        self.cadenceButton.accessibilityLabel = "Repeats"
        self.updateCadenceMenu()
        self.updateDateTitle()
    }

    private func kindChanged() {
        self.stops = self.kindControl.selectedSegmentIndex == 1
        self.view.endEditing(true)
        self.updateDateTitle()
        self.tableView.reloadData()
    }

    private func updateDateTitle() {
        self.dateRow.title = self.stops ? "Stops from" : "First payment"
        self.datePicker.accessibilityLabel = self.dateRow.title
    }

    private func updateCadenceMenu() {
        self.cadenceButton.setTitle(self.cadence.description.capitalizedFirst, for: .normal)
        var choices = RecurrenceCadence.choices
        if !choices.contains(self.cadence) { choices.insert(self.cadence, at: 0) }
        self.cadenceButton.menu = UIMenu(children: choices.map { cadence in
            UIAction(title: cadence.description.capitalizedFirst, state: cadence == self.cadence ? .on : .off) {
                [weak self] _ in
                self?.cadence = cadence
                self?.updateCadenceMenu()
            }
        })
    }

    @objc private func save() {
        self.view.endEditing(true)
        let date = self.calendar.startOfDay(for: self.datePicker.date)
        var terms: RecurrenceChange.Terms?
        if !self.stops {
            guard let amount = TransactionAmount.parse(self.amountField.text ?? "") else {
                self.showError(RecurrenceError.invalidAmount)
                return
            }
            terms = RecurrenceChange.Terms(amount: self.isIncome ? amount : -amount, cadence: self.cadence)
        }
        let change = RecurrenceChange(id: self.existing?.id ?? UUID(), date: date, terms: terms)
        do {
            try self.onSave(change)
            self.navigationController?.popViewController(animated: true)
        } catch {
            self.showError(error)
        }
    }

    private func confirmDelete() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Delete Change", style: .destructive) { [weak self] _ in
            self?.onDelete?()
            self?.navigationController?.popViewController(animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = self.deleteRow
            popover.sourceRect = self.deleteRow.bounds
        }
        self.present(sheet, animated: true)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "Couldn’t save", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    // MARK: - Table

    private var detailRows: [UITableViewCell] {
        self.stops ? [self.dateRow] : [self.dateRow, self.amountRow, self.cadenceRow]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.onDelete == nil ? Section.allCases.count - 1 : Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .kind: 0
        case .details: self.detailRows.count
        case .delete: 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .kind: UITableViewCell()
        case .details: self.detailRows[indexPath.row]
        case .delete: self.deleteRow
        }
    }

    /// The Change and Stop control sits on the background, under the navigation bar.
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        Section(rawValue: section) == .kind ? self.kindView : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard Section(rawValue: section) == .details else { return nil }
        return self.stops
            ? "Nothing is projected from this day on."
            : "Payments land on this day, then every period after it, for this amount."
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView.cellForRow(at: indexPath) === self.deleteRow {
            self.confirmDelete()
        }
    }
}
