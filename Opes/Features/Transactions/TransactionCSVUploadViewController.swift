import UIKit
import UniformTypeIdentifiers

final class TransactionCSVUploadViewController: UITableViewController {
    private var accounts: [AccountPreview]
    private let onImport: ([Transaction]) throws -> Void
    private var selectedAccount: AccountPreview?
    private var fileName: String?
    private var fileData: Data?
    private var isReadingFile = false
    private var parsedTransactions: [Transaction] = []
    private var isParsing = false
    private var isImporting = false
    private let accountButton = UIButton(type: .system)
    private lazy var accountRow = FormRowCell(
        title: "Account", control: self.accountButton, stretchesControl: true
    )

    init(accounts: [AccountPreview], onImport: @escaping ([Transaction]) throws -> Void) {
        self.accounts = accounts
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

    @objc private func confirmUpload() {
        guard let selectedAccount, let fileData, !self.isReadingFile, !self.isParsing,
              self.parsedTransactions.isEmpty else { return }
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
                case .success(let transactions):
                    self.parsedTransactions = transactions
                    UIAccessibility.post(notification: .announcement, argument: "\(transactions.count) transactions ready to review")
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
        guard let selectedAccount,
              self.parsedTransactions.allSatisfy({ $0.accountID == selectedAccount.id }) else { return }
        self.isImporting = true
        do {
            try self.onImport(self.parsedTransactions)
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
            return "Previewing the first \(min(self.parsedTransactions.count, 5)) transactions. Import adds all \(self.parsedTransactions.count) to \(self.selectedAccount?.name ?? "the selected account") in AUD."
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
                content.text = transaction.description
                content.secondaryText = "\(transaction.date.formatted(date: .abbreviated, time: .omitted)) · \(transaction.formattedAmount)"
                cell.selectionStyle = .none
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
