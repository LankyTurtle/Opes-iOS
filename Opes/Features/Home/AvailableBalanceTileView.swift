import UIKit

/// Home's balance summary. Tapping it chooses which accounts feed the total.
final class AvailableBalanceTileView: UIControl {
    private let headerLabel = UILabel()
    private let balanceLabel = UILabel()
    private let disclosureView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = .secondarySystemGroupedBackground
        self.layer.cornerRadius = 12
        self.layer.cornerCurve = .continuous

        self.headerLabel.translatesAutoresizingMaskIntoConstraints = false
        self.headerLabel.font = .preferredFont(forTextStyle: .subheadline)
        self.headerLabel.adjustsFontForContentSizeCategory = true
        self.headerLabel.textColor = .secondaryLabel
        self.headerLabel.numberOfLines = 0
        self.addSubview(self.headerLabel)

        self.disclosureView.translatesAutoresizingMaskIntoConstraints = false
        self.disclosureView.image = UIImage(systemName: "chevron.right")
        self.disclosureView.tintColor = .tertiaryLabel
        self.disclosureView.setContentHuggingPriority(.required, for: .horizontal)
        self.disclosureView.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.addSubview(self.disclosureView)

        self.balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        self.balanceLabel.font = UIFontMetrics(forTextStyle: .title1)
            .scaledFont(for: .systemFont(ofSize: 28, weight: .bold))
        self.balanceLabel.adjustsFontForContentSizeCategory = true
        self.balanceLabel.numberOfLines = 0
        self.addSubview(self.balanceLabel)

        // The whole tile reads as one button; the labels don't take touches.
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button

        NSLayoutConstraint.activate([
            self.headerLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
            self.headerLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            self.headerLabel.trailingAnchor.constraint(
                equalTo: self.disclosureView.leadingAnchor,
                constant: -8
            ),

            self.disclosureView.centerYAnchor.constraint(equalTo: self.headerLabel.centerYAnchor),
            self.disclosureView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),

            self.balanceLabel.topAnchor.constraint(equalTo: self.headerLabel.bottomAnchor, constant: 4),
            self.balanceLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            self.balanceLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            self.balanceLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16),
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

    func show(balance: Decimal, accountCount: Int) {
        let accountsDescription = accountCount == 1 ? "1 account" : "\(accountCount) accounts"
        let formattedBalance = balance.formatted(.currency(code: "AUD"))

        self.headerLabel.text = "Available Balance (\(accountsDescription))"
        self.balanceLabel.text = formattedBalance

        self.accessibilityLabel = "Available balance, \(formattedBalance), from \(accountsDescription)"
        self.accessibilityHint = "Choose which accounts to include"
    }
}
