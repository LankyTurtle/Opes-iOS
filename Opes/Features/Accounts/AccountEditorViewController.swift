import UIKit

final class AccountEditorViewController: UITableViewController {
    private let store: AccountStore
    private let onSave: (AccountPreview) -> Void
    private var type = AccountType.transaction
    private let nameField = UITextField()
    private let typeButton = UIButton(type: .system)
    private let numberField = UITextField()
    private let bsbField = UITextField()
    private let institutionField = UITextField()
    private lazy var nameRow = FormRowCell(title: "Account name", control: self.nameField, stretchesControl: true)
    private lazy var typeRow = FormRowCell(title: "Type", control: self.typeButton, stretchesControl: true)
    private lazy var numberRow = FormRowCell(title: "Number", control: self.numberField, stretchesControl: true)
    private lazy var bsbRow = FormRowCell(title: "BSB", control: self.bsbField, stretchesControl: true)
    private lazy var institutionRow = FormRowCell(
        title: "Institution", control: self.institutionField, stretchesControl: true
    )
    // Card accounts have no BSB, so its row is left out rather than disabled.
    private var rows: [FormRowCell] {
        [self.nameRow, self.typeRow, self.numberRow] + (self.type.hasBSB ? [self.bsbRow] : []) + [self.institutionRow]
    }

    init(store: AccountStore = .shared, onSave: @escaping (AccountPreview) -> Void) {
        self.store = store
        self.onSave = onSave
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Add Account"
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(self.saveAccount)
        )
        self.tableView.keyboardDismissMode = .interactive
        for field in [self.nameField, self.numberField, self.bsbField, self.institutionField] {
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            field.textAlignment = .right
            field.autocapitalizationType = .words
            field.clearButtonMode = .whileEditing
            field.returnKeyType = .done
            field.delegate = self
            field.addTarget(self, action: #selector(self.updateSaveButton), for: .editingChanged)
        }
        self.nameField.placeholder = "Everyday account"
        self.nameField.accessibilityLabel = "Account name"
        self.numberField.placeholder = "Account or card number"
        self.numberField.accessibilityLabel = "Account number"
        self.bsbField.placeholder = "000-000"
        self.bsbField.accessibilityLabel = "BSB"
        for field in [self.numberField, self.bsbField] {
            field.keyboardType = .numberPad
            field.autocorrectionType = .no
        }
        self.institutionField.placeholder = "Bank or institution"
        self.institutionField.accessibilityLabel = "Institution"

        self.typeButton.showsMenuAsPrimaryAction = true
        self.typeButton.contentHorizontalAlignment = .trailing
        self.typeButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        self.typeButton.titleLabel?.adjustsFontForContentSizeCategory = true
        self.typeButton.titleLabel?.lineBreakMode = .byTruncatingTail
        self.typeButton.accessibilityLabel = "Account type"
        self.configureTypeMenu()
        self.updateSaveButton()
    }

    private func configureTypeMenu() {
        self.typeButton.menu = UIMenu(children: AccountType.allCases.map { type in
            UIAction(title: type.title, state: self.type == type ? .on : .off) { [weak self] _ in
                self?.selectType(type)
            }
        })
        self.typeButton.setTitle(self.type.title, for: .normal)
    }

    private func selectType(_ type: AccountType) {
        let hadBSB = self.type.hasBSB
        self.type = type
        self.configureTypeMenu()
        self.updateSaveButton()
        guard hadBSB != type.hasBSB, let numberIndex = self.rows.firstIndex(of: self.numberRow) else { return }
        // The BSB row sits directly below the number row whenever it's shown.
        let indexPath = IndexPath(row: numberIndex + 1, section: 0)
        if type.hasBSB {
            self.tableView.insertRows(at: [indexPath], with: .automatic)
        } else {
            if self.bsbField.isFirstResponder { self.bsbField.resignFirstResponder() }
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    @objc private func updateSaveButton() {
        let requiredFields = [self.nameField, self.numberField, self.institutionField]
            + (self.type.hasBSB ? [self.bsbField] : [])
        self.navigationItem.rightBarButtonItem?.isEnabled = requiredFields.allSatisfy {
            !($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @objc private func saveAccount() {
        do {
            let account = try self.store.create(
                name: self.nameField.text ?? "", type: self.type, number: self.numberField.text ?? "",
                bsb: self.type.hasBSB ? self.bsbField.text : nil, institution: self.institutionField.text ?? ""
            )
            self.onSave(AccountPreview(account: account))
            self.navigationController?.popViewController(animated: true)
        } catch {
            let alert = UIAlertController(title: "Couldn’t save account", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { self.rows.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { self.rows[indexPath.row] }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "The account’s balance starts at $0.00; importing transaction history does not set the current balance."
    }
}

extension AccountEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
