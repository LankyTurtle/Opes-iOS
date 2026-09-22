import UIKit

final class TransactionEditorViewController: UITableViewController {
    private var accounts: [AccountPreview]
    private let onSave: (Transaction) throws -> Void
    private var accountID: AccountPreview.ID?

    private let descriptionField = UITextField()
    private let amountField = UITextField()
    private let directionControl = UISegmentedControl(items: ["Money out", "Money in"])
    private let datePicker = UIDatePicker()
    private let accountButton = UIButton(type: .system)
    private lazy var rows: [UITableViewCell] = [
        FormRowCell(title: "Description", control: self.descriptionField, stretchesControl: true),
        FormRowCell(title: "Amount (AUD)", control: self.amountField, stretchesControl: true),
        FormHostCell(view: self.directionControl),
        FormHostCell(view: self.datePicker),
        FormRowCell(title: "Account", control: self.accountButton, stretchesControl: true),
    ]

    init(accounts: [AccountPreview], onSave: @escaping (Transaction) throws -> Void) {
        self.accounts = accounts
        self.onSave = onSave
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Add Transaction"
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(self.save)
        )
        self.tableView.keyboardDismissMode = .interactive

        for field in [self.descriptionField, self.amountField] {
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            field.textAlignment = .right
            field.clearButtonMode = .whileEditing
            field.addTarget(self, action: #selector(self.validateForm), for: .editingChanged)
        }
        self.descriptionField.placeholder = "What it was for"
        self.descriptionField.accessibilityLabel = "Description"
        self.descriptionField.autocapitalizationType = .words
        self.descriptionField.returnKeyType = .done
        self.descriptionField.delegate = self
        self.amountField.placeholder = "0\(Locale.autoupdatingCurrent.decimalSeparator ?? ".")00"
        self.amountField.keyboardType = .decimalPad
        self.amountField.accessibilityLabel = "Amount in Australian dollars"
        self.directionControl.selectedSegmentIndex = 0
        self.directionControl.accessibilityLabel = "Transaction direction"
        self.datePicker.datePickerMode = .dateAndTime
        self.datePicker.preferredDatePickerStyle = .compact
        self.datePicker.contentHorizontalAlignment = .trailing
        self.datePicker.accessibilityLabel = "Transaction date and time"

        self.accountButton.showsMenuAsPrimaryAction = true
        self.accountButton.contentHorizontalAlignment = .trailing
        self.accountButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        self.accountButton.titleLabel?.adjustsFontForContentSizeCategory = true
        self.accountButton.titleLabel?.lineBreakMode = .byTruncatingTail
        self.accountButton.accessibilityLabel = "Account"
        self.configureAccountMenu()
        self.validateForm()
    }

    private func configureAccountMenu() {
        self.accountButton.menu = UIMenu(children: self.accounts.map { account in
            UIAction(
                title: "\(account.name) · \(account.institution)",
                state: self.accountID == account.id ? .on : .off
            ) { [weak self] _ in
                self?.accountID = account.id
                self?.configureAccountMenu()
            }
        } + [
            UIAction(title: "Add New Account…", image: UIImage(systemName: "plus")) { [weak self] _ in
                self?.addAccount()
            },
        ])
        self.accountButton.setTitle(
            self.accounts.first { $0.id == self.accountID }.map { "\($0.name) · \($0.institution)" } ?? "Select account",
            for: .normal
        )
        self.validateForm()
    }

    private func addAccount() {
        self.view.endEditing(true)
        let editor = AccountEditorViewController { [weak self] account in
            guard let self else { return }
            self.accounts.append(account)
            self.accountID = account.id
            self.configureAccountMenu()
        }
        self.navigationController?.pushViewController(editor, animated: true)
    }

    @objc private func validateForm() {
        self.navigationItem.rightBarButtonItem?.isEnabled =
            !(self.descriptionField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && TransactionAmount.parse(self.amountField.text ?? "") != nil
            && self.accounts.contains { $0.id == self.accountID }
    }

    @objc private func save() {
        let description = (self.descriptionField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, let amount = TransactionAmount.parse(self.amountField.text ?? ""),
              let account = self.accounts.first(where: { $0.id == self.accountID }) else {
            return
        }
        do {
            try self.onSave(Transaction(
                id: UUID(), description: description, date: self.datePicker.date,
                amount: self.directionControl.selectedSegmentIndex == 0 ? -amount : amount,
                accountID: account.id
            ))
            self.navigationController?.popViewController(animated: true)
        } catch {
            let alert = UIAlertController(
                title: "Couldn’t save transaction", message: error.localizedDescription, preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        self.rows[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Enter a positive amount with up to two decimal places, then choose money out or money in."
    }
}

extension TransactionEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
