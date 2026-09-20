import UIKit

final class AccountEditorViewController: UITableViewController {
    private let store: AccountStore
    private let onSave: (AccountPreview) -> Void
    private let nameField = UITextField()
    private let institutionField = UITextField()
    private lazy var rows = [
        FormRowCell(title: "Account name", control: self.nameField, stretchesControl: true),
        FormRowCell(title: "Institution", control: self.institutionField, stretchesControl: true),
    ]

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
        for field in [self.nameField, self.institutionField] {
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
        self.institutionField.placeholder = "Bank or institution"
        self.institutionField.accessibilityLabel = "Institution"
        self.updateSaveButton()
    }

    @objc private func updateSaveButton() {
        self.navigationItem.rightBarButtonItem?.isEnabled = [self.nameField, self.institutionField].allSatisfy {
            !($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @objc private func saveAccount() {
        do {
            let account = try self.store.create(
                name: self.nameField.text ?? "", institution: self.institutionField.text ?? ""
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
        "The new account will be selected for your transactions. Its balance starts at $0.00; importing transaction history does not set the current balance."
    }
}

extension AccountEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
