import UIKit

final class TransactionEditorViewController: UITableViewController {
    private let accountProvider: any AccountProviding
    private var accounts: [AccountPreview]
    private let onSave: (Transaction) throws -> Void
    private var accountID: AccountPreview.ID?

    private let descriptionField = UITextField()
    private let amountField = UITextField()
    private let directionControl = UISegmentedControl(items: ["Money out", "Money in"])
    private let datePicker = UIDatePicker()
    private let accountButton = UIButton(type: .system)
    private let categoryButton = UIButton(type: .system)
    private var allocations: [TransactionAllocation] = []
    private lazy var rows: [UITableViewCell] = [
        FormRowCell(title: "Description", control: self.descriptionField, stretchesControl: true),
        FormRowCell(title: "Amount (AUD)", control: self.amountField, stretchesControl: true),
        FormHostCell(view: self.directionControl),
        FormHostCell(view: self.datePicker),
        FormRowCell(title: "Account", control: self.accountButton, stretchesControl: true),
        FormRowCell(title: "Categories", control: self.categoryButton, stretchesControl: true),
    ]

    init(accountProvider: any AccountProviding, onSave: @escaping (Transaction) throws -> Void) {
        self.accountProvider = accountProvider
        self.accounts = accountProvider.accounts()
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
        self.directionControl.addTarget(self, action: #selector(self.validateForm), for: .valueChanged)
        self.categoryButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        self.categoryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        self.categoryButton.titleLabel?.numberOfLines = 0
        self.categoryButton.contentHorizontalAlignment = .trailing
        self.categoryButton.accessibilityLabel = "Categories"
        self.categoryButton.addTarget(self, action: #selector(self.editCategories), for: .touchUpInside)
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

    /// The selected account, re-read from the store: it may have been deleted
    /// from Accounts while this screen was open. If it has, the choice is
    /// cleared (everything else entered is kept) and the user is asked to pick
    /// another account or add one.
    private func accountStillOnFile() -> AccountPreview? {
        guard let accountID else { return nil }
        let name = self.accounts.first { $0.id == accountID }?.name
        self.accounts = self.accountProvider.accounts()
        if let account = self.accounts.first(where: { $0.id == accountID }) {
            return account
        }
        self.accountID = nil
        self.configureAccountMenu()
        self.view.endEditing(true)

        let alert = UIAlertController(
            title: "Account No Longer Exists",
            message: "\(name.map { "“\($0)”" } ?? "The selected account") has been deleted. Choose another account or add a new one, then save the transaction again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Add New Account", style: .default) { [weak self] _ in
            self?.addAccount()
        })
        if !self.accounts.isEmpty {
            // The account menu is on this screen, so choosing just returns to it.
            alert.addAction(UIAlertAction(title: "Choose Another Account", style: .default))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
        return nil
    }

    @objc private func validateForm() {
        self.categoryButton.isEnabled = TransactionAmount.parse(self.amountField.text ?? "") != nil
        self.categoryButton.setTitle(
            self.allocations.isEmpty ? "Uncategorised" : self.allocations.map { $0.category.rawValue }.joined(separator: ", "),
            for: .normal
        )
        self.navigationItem.rightBarButtonItem?.isEnabled =
            !(self.descriptionField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && TransactionAmount.parse(self.amountField.text ?? "") != nil
            && self.accounts.contains { $0.id == self.accountID }
    }

    @objc private func save() {
        let description = (self.descriptionField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, let amount = TransactionAmount.parse(self.amountField.text ?? ""),
              let account = self.accountStillOnFile() else {
            return
        }
        do {
            let transaction = try Transaction(
                id: UUID(), description: description, date: self.datePicker.date,
                amount: self.directionControl.selectedSegmentIndex == 0 ? -amount : amount,
                accountID: account.id
            ).withAllocations(self.allocations)
            try self.onSave(transaction)
            self.navigationController?.popViewController(animated: true)
        } catch {
            let alert = UIAlertController(
                title: "Couldn’t save transaction", message: error.localizedDescription, preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    @objc private func editCategories() {
        guard let amount = TransactionAmount.parse(self.amountField.text ?? "") else { return }
        self.view.endEditing(true)
        let draft = Transaction(id: UUID(), description: self.descriptionField.text ?? "",
                                date: self.datePicker.date,
                                amount: self.directionControl.selectedSegmentIndex == 0 ? -amount : amount,
                                accountID: self.accountID ?? UUID())
        // An amount edit may make the previous split too large; let the user
        // correct it in the editor instead of dropping their allocations.
        let editor = TransactionCategoriesViewController(
            transaction: draft, allocations: self.allocations
        ) { [weak self] allocations in
            self?.allocations = allocations
            self?.validateForm()
        }
        self.navigationController?.pushViewController(editor, animated: true)
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
