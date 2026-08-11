import UIKit

/// Home's balance summary. Tapping it chooses which accounts feed the total.
final class AvailableBalanceTileView: UIControl {
    /// Leading half of the header, ahead of the account count.
    var headerTitle = "Available Balance"

    private let headerLabel = UILabel()
    private let balanceLabel = UILabel()
    private let countLabel = UILabel()
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
        // One line that shrinks to fit, so a long balance never wraps and shifts the
        // chevron off centre. Scaling needs a non-zero minimum to engage at all.
        self.balanceLabel.numberOfLines = 1
        self.balanceLabel.adjustsFontSizeToFitWidth = true
        self.balanceLabel.minimumScaleFactor = 0.5
        self.addSubview(self.balanceLabel)

        self.countLabel.translatesAutoresizingMaskIntoConstraints = false
        self.countLabel.font = .preferredFont(forTextStyle: .footnote)
        self.countLabel.adjustsFontForContentSizeCategory = true
        self.countLabel.textColor = .secondaryLabel
        self.countLabel.numberOfLines = 0
        self.addSubview(self.countLabel)

        // The whole tile reads as one button; the labels don't take touches.
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button

        NSLayoutConstraint.activate([
            self.headerLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
            self.headerLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            self.headerLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),

            self.disclosureView.centerYAnchor.constraint(equalTo: self.balanceLabel.centerYAnchor),
            self.disclosureView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),

            self.balanceLabel.topAnchor.constraint(equalTo: self.headerLabel.bottomAnchor, constant: 4),
            self.balanceLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            self.balanceLabel.trailingAnchor.constraint(
                equalTo: self.disclosureView.leadingAnchor,
                constant: -8
            ),

            self.countLabel.topAnchor.constraint(equalTo: self.balanceLabel.bottomAnchor, constant: 2),
            self.countLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            self.countLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            self.countLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16),
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
        let accountsDescription = Self.accountsDescription(for: accountCount)
        let formattedBalance = balance.formatted(.currency(code: "AUD"))

        self.headerLabel.text = self.headerTitle
        self.balanceLabel.text = formattedBalance
        self.countLabel.text = accountsDescription

        self.accessibilityLabel = "\(self.headerTitle), \(formattedBalance), \(accountsDescription)"
        self.accessibilityHint = "Choose which accounts to include"
    }

    private static func accountsDescription(for count: Int) -> String {
        switch count {
        case 0:
            return "No accounts selected"
        case 1:
            return "Across 1 account"
        default:
            return "Across \(count) accounts"
        }
    }
}
