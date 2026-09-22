import UIKit
import UniformTypeIdentifiers

final class TransactionCSVUploadViewController: UITableViewController {
    private let accountProvider: any AccountProviding
    private var accounts: [AccountPreview]
    private let onImport: (TransactionCSVImport) throws -> Void
    private var selectedAccount: AccountPreview?
    private var fileName: String?
    private var fileData: Data?
    private var isReadingFile = false
    private var parsedTransactions: [Transaction] = []
    /// Only meaningful while `parsedTransactions` holds the preview it came with.
    private var closingBalance: TransactionCSVImport.ClosingBalance?
    private var isParsing = false
    private var isImporting = false
    private let accountButton = UIButton(type: .system)
    private lazy var accountRow = FormRowCell(
        title: "Account", control: self.accountButton, stretchesControl: true
    )

    init(accountProvider: any AccountProviding, onImport: @escaping (TransactionCSVImport) throws -> Void) {
        self.accountProvider = accountProvider
        self.accounts = accountProvider.accounts()
        self.onImport = onImport
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Upload CSV"
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Upload", style: .done, target: self, action: #selector(self.confirmUpload)
        )
        self.accountButton.showsMenuAsPrimaryAction = true
        self.accountButton.contentHorizontalAlignment = .trailing
        self.accountButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        self.accountButton.titleLabel?.adjustsFontForContentSizeCategory = true
        self.accountButton.titleLabel?.lineBreakMode = .byTruncatingTail
        self.accountButton.accessibilityLabel = "Account"
        self.refresh()
    }

    private func refresh() {
        self.accountButton.menu = UIMenu(children: self.accounts.map { account in
            UIAction(title: "\(account.name) · \(account.institution)", state: self.selectedAccount?.id == account.id ? .on : .off) { [weak self] _ in
                self?.selectedAccount = account
                self?.parsedTransactions = []
                self?.refresh()
            }
        } + [
            UIAction(title: "Add New Account…", image: UIImage(systemName: "plus")) { [weak self] _ in
                self?.addAccount()
            },
        ])
        self.accountButton.setTitle(self.selectedAccount.map { "\($0.name) · \($0.institution)" } ?? "Select account", for: .normal)
        self.accountButton.isEnabled = !self.isReadingFile && !self.isParsing
        self.navigationItem.rightBarButtonItem?.title = self.isParsing ? "Parsing…" : "Upload"
        self.navigationItem.rightBarButtonItem?.isEnabled =
            self.selectedAccount != nil && self.fileData != nil && !self.isReadingFile
            && !self.isParsing && self.parsedTransactions.isEmpty
        self.tableView.reloadData()
    }

    private func addAccount() {
        let editor = AccountEditorViewController { [weak self] account in
            guard let self else { return }
            self.accounts.append(account)
            self.selectedAccount = account
            self.parsedTransactions = []
            self.refresh()
        }
        self.navigationController?.pushViewController(editor, animated: true)
    }

    /// The selected account, re-read from the store: it may have been deleted
    /// from Accounts while this screen was open. If it has, the choice and any
    /// preview are cleared (the file is kept) and the user is asked to pick
    /// another account or add one.
    private func accountStillOnFile() -> AccountPreview? {
        guard let selectedAccount else { return nil }
        self.accounts = self.accountProvider.accounts()
        if let account = self.accounts.first(where: { $0.id == selectedAccount.id }) {
            return account
        }
        self.selectedAccount = nil
        self.parsedTransactions = []
        self.refresh()

        let alert = UIAlertController(
            title: "Account No Longer Exists",
            message: "“\(selectedAccount.name)” has been deleted. Choose another account or add a new one, then upload the file again.",
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

    @objc private func confirmUpload() {
        guard let fileData, !self.isReadingFile, !self.isParsing,
              self.parsedTransactions.isEmpty, let selectedAccount = self.accountStillOnFile() else { return }
        self.isParsing = true
        self.refresh()
        let accountID = selectedAccount.id
        let institution = selectedAccount.institution
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try TransactionCSVParser.parse(fileData, accountID: accountID, institution: institution) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isParsing = false
                switch result {
                case .success(let parsed):
                    self.parsedTransactions = parsed.transactions
                    self.closingBalance = parsed.closingBalance
                    UIAccessibility.post(notification: .announcement, argument: "\(parsed.transactions.count) transactions ready to review")
                case .failure(let error):
                    self.showError(title: "Couldn’t parse CSV", error: error)
                }
                self.refresh()
                if !self.parsedTransactions.isEmpty {
                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: 2), at: .top, animated: true)
                }
            }
        }
    }

    private func importTransactions() {
        guard !self.parsedTransactions.isEmpty, !self.isReadingFile, !self.isParsing, !self.isImporting else { return }
        guard let selectedAccount = self.accountStillOnFile(),
              self.parsedTransactions.allSatisfy({ $0.accountID == selectedAccount.id }) else { return }
        self.isImporting = true
        do {
            try self.onImport(TransactionCSVImport(transactions: self.parsedTransactions, closingBalance: self.closingBalance))
            self.navigationController?.popViewController(animated: true)
        } catch {
            self.isImporting = false
            self.showError(title: "Couldn’t import transactions", error: error)
        }
    }

    private func chooseFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = self
        self.present(picker, animated: true)
    }

    private func removeFile() {
        self.fileName = nil
        self.fileData = nil
        self.parsedTransactions = []
        self.refresh()
    }

    private func showError(title: String, error: Error) {
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.parsedTransactions.isEmpty ? 2 : 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 1 }
        if section == 2 { return min(self.parsedTransactions.count, 5) + 1 }
        return self.fileData == nil ? 1 : 3
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 2 { return "\(self.parsedTransactions.count) transactions ready to import" }
        return section == 0 ? "Account" : "CSV file"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 { return "Select the account these transactions belong to, or add a new account from the menu." }
        if section == 2 {
            let balance = self.closingBalance.map {
                " and sets its balance to \(ForecastFormatter.currency($0.amount)), unless it already has later transactions"
            } ?? ""
            return "Previewing the first \(min(self.parsedTransactions.count, 5)) transactions. Import adds all \(self.parsedTransactions.count) to \(self.selectedAccount?.name ?? "the selected account") in AUD\(balance)."
        }
        if let institution = self.selectedAccount?.institution, TransactionCSVParser.readsMacquarieExport(for: institution) {
            return "Choose a Macquarie CSV export (up to 10 MB), then tap Upload to parse it. It needs Transaction Date, Details and Original Description columns, with Debit and Credit or an Amount column. Balance sets the account’s balance."
        }
        return "Choose a CSV (up to 10 MB), then tap Upload to parse it. Include Date, Description and Amount columns, or Debit and Credit instead of Amount. Dates use day/month/year or year-month-day. Negative amounts are money out."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 { return self.accountRow }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        if indexPath.section == 2 {
            if indexPath.row == 0 {
                content.text = "Import \(self.parsedTransactions.count) Transactions"
                let enabled = !self.isReadingFile && !self.isParsing
                content.textProperties.color = enabled ? self.view.tintColor : .secondaryLabel
                content.image = UIImage(systemName: "checkmark.circle")
                cell.isUserInteractionEnabled = enabled
                cell.accessibilityTraits = enabled ? .button : [.button, .notEnabled]
            } else {
                let transaction = self.parsedTransactions[indexPath.row - 1]
                content.text = transaction.summary
                content.secondaryText = "\(transaction.date.formatted(date: .abbreviated, time: .omitted)) · \(transaction.formattedAmount)"
                cell.selectionStyle = .none
                // Matches the Transactions list: the summary stays on one line.
                content.textProperties.numberOfLines = 1
                content.textProperties.lineBreakMode = .byTruncatingTail
                cell.contentConfiguration = content
                return cell
            }
            content.textProperties.numberOfLines = 0
            cell.contentConfiguration = content
            return cell
        }
        if indexPath.row == 0, let fileName, let fileData {
            content.text = fileName
            content.secondaryText = ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file)
            content.image = UIImage(systemName: "doc.text")
            cell.selectionStyle = .none
        } else {
            let isRemove = indexPath.row == 2
            content.text = self.isReadingFile ? "Reading file…" : (isRemove ? "Remove File" : (self.fileData == nil ? "Choose File" : "Replace File"))
            content.image = UIImage(systemName: isRemove ? "trash" : "folder")
            let enabled = !self.isReadingFile && !self.isParsing && self.selectedAccount != nil
            content.textProperties.color = enabled ? (isRemove ? .systemRed : self.view.tintColor) : .secondaryLabel
            content.imageProperties.tintColor = content.textProperties.color
            cell.isUserInteractionEnabled = enabled
            cell.accessibilityTraits = enabled ? .button : [.button, .notEnabled]
        }
        content.textProperties.numberOfLines = 0
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2, indexPath.row == 0 {
            self.importTransactions()
            return
        }
        guard indexPath.section == 1, !self.isReadingFile, !self.isParsing, self.selectedAccount != nil else { return }
        if indexPath.row == 2 {
            self.removeFile()
        } else if self.fileData == nil || indexPath.row == 1 {
            self.chooseFile()
        }
    }
}

extension TransactionCSVUploadViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        self.isReadingFile = true
        self.refresh()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try TransactionCSVAttachment.readFile(at: url) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isReadingFile = false
                switch result {
                case .success(let data):
                    self.fileName = url.lastPathComponent
                    self.fileData = data
                    self.parsedTransactions = []
                case .failure(let error):
                    self.showError(title: "Couldn’t read CSV", error: error)
                }
                self.refresh()
            }
        }
    }
}
