import UIKit

/// Home's summary card of the latest transactions. Tapping a row opens that
/// transaction's details.
final class RecentTransactionsTileView: UIView {
    private let headerLabel = UILabel()
    private let rowsStack = UIStackView()

    /// The tapped transaction, and the row it was tapped in — the card grows out
    /// of the row rather than the whole tile.
    var onSelect: ((Transaction, UIView) -> Void)?

    init(transactions: [Transaction]) {
        super.init(frame: .zero)

        // The list cell draws the card background and corners at the system radius.
        self.backgroundColor = .clear

        self.headerLabel.translatesAutoresizingMaskIntoConstraints = false
        self.headerLabel.font = .preferredFont(forTextStyle: .headline)
        self.headerLabel.adjustsFontForContentSizeCategory = true
        self.headerLabel.text = "Recent Transactions"
        self.addSubview(self.headerLabel)

        self.rowsStack.translatesAutoresizingMaskIntoConstraints = false
        self.rowsStack.axis = .vertical
        self.addSubview(self.rowsStack)

        for (index, transaction) in transactions.enumerated() {
            if index > 0 {
                self.rowsStack.addArrangedSubview(self.makeSeparator())
            }

            let row = TransactionRowControl(transaction: transaction)
            row.addTarget(self, action: #selector(self.handleRowTap), for: .touchUpInside)
            self.rowsStack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            self.headerLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: DesignTokens.cardPadding),
            self.headerLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.cardPadding),
            self.headerLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.cardPadding),

            self.rowsStack.topAnchor.constraint(equalTo: self.headerLabel.bottomAnchor, constant: DesignTokens.titleSpacing),
            self.rowsStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.cardPadding),
            self.rowsStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.cardPadding),
            self.rowsStack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -DesignTokens.titleSpacing),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleRowTap(_ sender: UIControl) {
        guard let row = sender as? TransactionRowControl else {
            return
        }

        self.onSelect?(row.transaction, row)
    }

    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(
            equalToConstant: 1 / max(self.traitCollection.displayScale, 1)
        ).isActive = true
        return separator
    }
}

/// One transaction in the card: the merchant and when it moved, the amount, and
/// the chevron its details are behind.
private final class TransactionRowControl: UIControl {
    let transaction: Transaction

    init(transaction: Transaction) {
        self.transaction = transaction
        super.init(frame: .zero)

        let merchantLabel = UILabel()
        merchantLabel.font = .preferredFont(forTextStyle: .body)
        merchantLabel.adjustsFontForContentSizeCategory = true
        merchantLabel.text = transaction.merchant

        let dateLabel = UILabel()
        dateLabel.font = .preferredFont(forTextStyle: .footnote)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = .secondaryLabel
        dateLabel.text = transaction.formattedDate

        let detailStack = UIStackView(arrangedSubviews: [merchantLabel, dateLabel])
        detailStack.axis = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 2

        let amountLabel = UILabel()
        amountLabel.font = .preferredFont(forTextStyle: .body)
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.textAlignment = .right
        amountLabel.text = transaction.formattedAmount
        // The amount never truncates; the merchant name gives way instead.
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let disclosureView = UIImageView(image: UIImage(systemName: "chevron.right"))
        disclosureView.tintColor = .tertiaryLabel
        disclosureView.setContentHuggingPriority(.required, for: .horizontal)
        disclosureView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [detailStack, amountLabel, disclosureView])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: DesignTokens.rowPadding,
            leading: 0,
            bottom: DesignTokens.rowPadding,
            trailing: 0
        )
        // The row reads as one button; its labels don't take touches.
        row.isUserInteractionEnabled = false
        self.addSubview(row)

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.accessibilityLabel =
            "\(transaction.merchant), \(transaction.formattedAmount), \(transaction.formattedDate)"
        self.accessibilityHint = "Open the transaction's details"

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: self.topAnchor),
            row.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            self.alpha = self.isHighlighted ? 0.6 : 1
        }
    }
}
