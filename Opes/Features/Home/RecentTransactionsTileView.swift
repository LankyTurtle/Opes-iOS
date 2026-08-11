import UIKit

/// Home's summary card of the latest transactions.
final class RecentTransactionsTileView: UIView {
    private let headerLabel = UILabel()
    private let rowsStack = UIStackView()

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

            self.rowsStack.addArrangedSubview(Self.makeRow(for: transaction))
        }

        NSLayoutConstraint.activate([
            self.headerLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
            self.headerLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            self.headerLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),

            self.rowsStack.topAnchor.constraint(equalTo: self.headerLabel.bottomAnchor, constant: 8),
            self.rowsStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            self.rowsStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            self.rowsStack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeRow(for transaction: Transaction) -> UIView {
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

        let row = UIStackView(arrangedSubviews: [detailStack, amountLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 10,
            leading: 0,
            bottom: 10,
            trailing: 0
        )
        return row
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
