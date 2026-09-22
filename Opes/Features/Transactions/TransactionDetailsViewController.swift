import UIKit

/// One transaction in full: what it was, when it moved, the account it moved
/// through, and how it sits against everything else from the same merchant.
///
/// Reached by tapping a row in the transactions list. The account row carries on
/// to that account's forecast, so a transaction is a way into the balance it
/// changed rather than a dead end.
final class TransactionDetailsViewController: UITableViewController {
    private var transaction: Transaction
    private let accountProvider: any AccountProviding
    private let transactionProvider: any TransactionProviding
    private let transactionStore: TransactionStore
    private let onDelete: (() -> Void)?
    private var isDeleting = false

    /// The account the money moved through, when the transaction names one that is
    /// still on file.
    private let account: AccountPreview?
    private let merchantHistory: MerchantHistory

    private let summaryView = TransactionSummaryView()

    private lazy var summaryRow = FormHostCell(view: self.summaryView)

    private let displayDescriptionField = UITextField()
    private lazy var displayDescriptionRow = FormRowCell(
        title: "Display Description", control: self.displayDescriptionField, stretchesControl: true
    )

    private lazy var deleteRow: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = "Delete Transaction"
        content.textProperties.color = .systemRed
        content.textProperties.alignment = .center
        content.textProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.accessibilityTraits = .button
        return cell
    }()

    /// A row the user can follow, so it is a plain cell with a disclosure rather
    /// than one of the form rows, which don't highlight.
    private lazy var accountRow: UITableViewCell? = self.account.map { account -> UITableViewCell in
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.valueCell()
        content.image = account.institutionLogo
        content.text = "Account"
        content.secondaryText = account.name
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    private lazy var sections: [DetailsSection] = self.makeSections()

    init(
        transaction: Transaction,
        accountProvider: any AccountProviding = AccountStore.shared,
        transactionProvider: any TransactionProviding = TransactionStore.shared,
        transactionStore: TransactionStore = .shared,
        onDelete: (() -> Void)? = nil
    ) {
        self.transaction = transaction
        self.accountProvider = accountProvider
        self.transactionProvider = transactionProvider
        self.transactionStore = transactionStore
        self.onDelete = onDelete
        self.account = accountProvider.accounts().first { $0.id == transaction.accountID }
        self.merchantHistory = MerchantHistory.make(
            for: transaction.merchant,
            in: transactionProvider.transactions()
        )
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // The name is already the bar’s title; a large one repeating it directly
        // above the same name on the card reads as a stutter.
        self.navigationItem.largeTitleDisplayMode = .never
        self.tableView.keyboardDismissMode = .interactive

        let field = self.displayDescriptionField
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textAlignment = .right
        field.autocapitalizationType = .words
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .done
        field.accessibilityLabel = "Display description"
        // Clearing the field goes back to the description, so it is the hint.
        field.placeholder = self.transaction.merchant
        field.delegate = self

        self.showTransaction()
    }

    private func showTransaction() {
        self.title = self.transaction.displayName
        self.displayDescriptionField.text = self.transaction.displayName
        self.summaryView.show(self.transaction)
    }

    private func rename(to name: String) {
        // Leaving the screen ends editing; after a delete that must not save
        // the transaction back.
        guard !self.isDeleting else { return }
        let renamed = self.transaction.renamed(to: name)
        if renamed != self.transaction {
            do {
                try self.transactionStore.save(renamed)
                self.transaction = renamed
            } catch {
                let alert = UIAlertController(
                    title: "Couldn’t rename transaction", message: error.localizedDescription, preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
        // Also puts the description back when the field was left blank.
        self.showTransaction()
    }

    private func makeSections() -> [DetailsSection] {
        var details: [UITableViewCell] = [
            self.displayDescriptionRow,
            Self.makeDetailRow(title: "Description", value: self.transaction.merchant),
            Self.makeDetailRow(title: "Reference", value: self.transaction.reference ?? "None"),
            Self.makeDetailRow(title: "Date", value: self.transaction.formattedFullDate),
            Self.makeDetailRow(title: "Time", value: self.transaction.formattedTime),
        ]

        if let accountRow = self.accountRow, let account = self.account {
            details.append(accountRow)
            details.append(Self.makeDetailRow(title: "Institution", value: account.institution))
        } else {
            details.append(Self.makeDetailRow(title: "Account", value: "Not linked"))
            if let institution = self.transaction.sourceInstitution {
                details.append(Self.makeDetailRow(title: "Institution", value: institution))
            }
        }

        var sections: [DetailsSection] = [
            DetailsSection(rows: [self.summaryRow]),
            DetailsSection(header: "Details", rows: details),
        ]

        // With one transaction on record the totals only restate the card above, so
        // the section waits until there is a history to summarise.
        if self.merchantHistory.count > 1 {
            sections.append(
                DetailsSection(
                    header: "This merchant",
                    rows: [
                        Self.makeDetailRow(
                            title: "Transactions",
                            value: self.merchantHistory.count.formatted()
                        ),
                        Self.makeDetailRow(
                            title: "Total",
                            value: ForecastFormatter.signedCurrency(self.merchantHistory.total)
                        ),
                        Self.makeDetailRow(
                            title: "Typical amount",
                            value: ForecastFormatter.signedCurrency(self.merchantHistory.average)
                        ),
                    ],
                    footer: self.merchantHistory.description(of: self.transaction.merchant)
                )
            )
        }

        sections.append(DetailsSection(rows: [self.deleteRow]))
        return sections
    }

    private func deleteTransaction() {
        guard !self.isDeleting else { return }
        self.isDeleting = true
        do {
            try self.transactionStore.delete(id: self.transaction.id)
            if let navigationController = self.navigationController,
               navigationController.viewControllers.first !== self {
                self.onDelete?()
                navigationController.popViewController(animated: true)
            } else {
                // Home presents details in a card. Keep its source row intact
                // until dismissal finishes, then refresh the recent transactions.
                self.dismiss(animated: true, completion: self.onDelete)
            }
        } catch {
            self.isDeleting = false
            let alert = UIAlertController(
                title: "Couldn’t delete transaction", message: error.localizedDescription, preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    private static func makeDetailRow(title: String, value: String) -> UITableViewCell {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        // A long value wraps rather than pushing its title off the row.
        label.numberOfLines = 0
        label.text = value

        return FormRowCell(title: title, control: label, stretchesControl: true)
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
        self.sections[section].footer
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if self.sections[indexPath.section].rows[indexPath.row] === self.deleteRow {
            self.deleteTransaction()
            return
        }

        guard
            let account = self.account,
            self.sections[indexPath.section].rows[indexPath.row] === self.accountRow
        else {
            return
        }

        self.navigationController?.pushViewController(
            ForecastViewController(
                subject: .account(account),
                accountProvider: self.accountProvider,
                transactionProvider: self.transactionProvider
            ),
            animated: true
        )
    }
}

extension TransactionDetailsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.rename(to: textField.text ?? "")
    }
}

/// Everything on record from one merchant, so a single transaction can be read
/// against the rest of them.
private struct MerchantHistory {
    let count: Int
    let total: Decimal
    let average: Decimal
    /// The oldest transaction on record, which is how far back the totals reach.
    let earliest: Date?

    static func make(for merchant: String, in transactions: [Transaction]) -> MerchantHistory {
        let matches = transactions.filter { $0.merchant == merchant }
        let total = matches.reduce(Decimal.zero) { $0 + $1.amount }

        return MerchantHistory(
            count: matches.count,
            total: total,
            average: matches.isEmpty ? 0 : total / Decimal(matches.count),
            earliest: matches.map(\.date).min()
        )
    }

    /// Says what the totals cover, so they aren't read as all time.
    func description(of merchant: String) -> String {
        guard let earliest = self.earliest else {
            return "Every transaction on record from \(merchant)."
        }

        let since = earliest.formatted(.dateTime.month(.wide).year())
        return "Every transaction on record from \(merchant), back to \(since)."
    }
}

/// The headline of the details screen: the merchant, what the transaction did to
/// the balance, and which way the money went.
private final class TransactionSummaryView: UIView {
    private let merchantLabel = UILabel()
    private let amountLabel = UILabel()
    private let directionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // The list cell draws the card background and corners at the system radius.
        self.backgroundColor = .clear

        self.merchantLabel.font = .preferredFont(forTextStyle: .subheadline)
        self.merchantLabel.adjustsFontForContentSizeCategory = true
        self.merchantLabel.textColor = .secondaryLabel
        self.merchantLabel.numberOfLines = 0

        self.amountLabel.font = DesignTokens.tileValueFont
        self.amountLabel.adjustsFontForContentSizeCategory = true
        // One line that shrinks to fit, so a large amount doesn't wrap. Scaling
        // needs a non-zero minimum to engage at all.
        self.amountLabel.numberOfLines = 1
        self.amountLabel.adjustsFontSizeToFitWidth = true
        self.amountLabel.minimumScaleFactor = 0.5

        self.directionLabel.font = .preferredFont(forTextStyle: .footnote)
        self.directionLabel.adjustsFontForContentSizeCategory = true
        self.directionLabel.textColor = .secondaryLabel
        self.directionLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            self.merchantLabel,
            self.amountLabel,
            self.directionLabel,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = DesignTokens.captionSpacing
        stack.setCustomSpacing(DesignTokens.labelSpacing, after: self.merchantLabel)
        self.addSubview(stack)

        self.isAccessibilityElement = true

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ transaction: Transaction) {
        let amount = ForecastFormatter.signedCurrency(transaction.amount)

        self.merchantLabel.text = transaction.displayName
        self.amountLabel.text = amount
        // Money in is picked out the way the forecast picks out a rise. Money out
        // is the ordinary case and stays in the label colour, so a screen of
        // everyday spending isn't a wall of red.
        self.amountLabel.textColor = transaction.isMoneyIn ? .systemTeal : .label
        self.directionLabel.text = transaction.directionDescription

        self.accessibilityLabel =
            "\(transaction.displayName), \(amount), \(transaction.directionDescription)"
    }
}

private struct DetailsSection {
    var header: String?
    var rows: [UITableViewCell] = []
    var footer: String?
}
