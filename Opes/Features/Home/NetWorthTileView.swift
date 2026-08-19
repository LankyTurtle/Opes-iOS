import UIKit

/// Home's net worth summary: every account tallied into one position, with where
/// the projection takes it. Tapping it opens the forecast.
final class NetWorthTileView: UIControl {
    private let headerLabel = UILabel()
    private let valueLabel = UILabel()
    private let projectionLabel = UILabel()
    private let disclosureView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // The list cell draws the card background and corners at the system radius.
        self.backgroundColor = .clear

        self.headerLabel.translatesAutoresizingMaskIntoConstraints = false
        self.headerLabel.font = .preferredFont(forTextStyle: .headline)
        self.headerLabel.adjustsFontForContentSizeCategory = true
        self.headerLabel.numberOfLines = 0
        self.headerLabel.text = "Net Worth"
        self.addSubview(self.headerLabel)

        self.disclosureView.translatesAutoresizingMaskIntoConstraints = false
        self.disclosureView.image = UIImage(systemName: "chevron.right")
        self.disclosureView.tintColor = .tertiaryLabel
        self.disclosureView.setContentHuggingPriority(.required, for: .horizontal)
        self.disclosureView.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.addSubview(self.disclosureView)

        self.valueLabel.translatesAutoresizingMaskIntoConstraints = false
        self.valueLabel.font = DesignTokens.tileValueFont
        self.valueLabel.adjustsFontForContentSizeCategory = true
        // One line that shrinks to fit, so a position carrying a mortgage never
        // wraps and shifts the chevron off centre.
        self.valueLabel.numberOfLines = 1
        self.valueLabel.adjustsFontSizeToFitWidth = true
        self.valueLabel.minimumScaleFactor = 0.5
        self.addSubview(self.valueLabel)

        self.projectionLabel.translatesAutoresizingMaskIntoConstraints = false
        self.projectionLabel.font = .preferredFont(forTextStyle: .footnote)
        self.projectionLabel.adjustsFontForContentSizeCategory = true
        self.projectionLabel.textColor = .secondaryLabel
        self.projectionLabel.numberOfLines = 0
        self.addSubview(self.projectionLabel)

        // The whole tile reads as one button; the labels don't take touches.
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button

        NSLayoutConstraint.activate([
            self.headerLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: DesignTokens.cardPadding),
            self.headerLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.cardPadding),
            self.headerLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.cardPadding),

            self.disclosureView.centerYAnchor.constraint(equalTo: self.valueLabel.centerYAnchor),
            self.disclosureView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.cardPadding),

            self.valueLabel.topAnchor.constraint(equalTo: self.headerLabel.bottomAnchor, constant: DesignTokens.labelSpacing),
            self.valueLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.cardPadding),
            self.valueLabel.trailingAnchor.constraint(
                equalTo: self.disclosureView.leadingAnchor,
                constant: -8
            ),

            self.projectionLabel.topAnchor.constraint(equalTo: self.valueLabel.bottomAnchor, constant: DesignTokens.captionSpacing),
            self.projectionLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.cardPadding),
            self.projectionLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.cardPadding),
            self.projectionLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -DesignTokens.cardPadding),
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

    func show(forecast: Forecast, accountCount: Int) {
        let position = ForecastFormatter.currency(forecast.startingBalance)
        let projection = Self.projectionDescription(for: forecast, accountCount: accountCount)

        self.valueLabel.text = position
        self.projectionLabel.text = projection

        self.accessibilityLabel = "Net Worth, \(position). \(projection)"
        self.accessibilityHint = "Open the net worth forecast"
    }

    private static func projectionDescription(for forecast: Forecast, accountCount: Int) -> String {
        let across = accountCount == 1 ? "1 account" : "\(accountCount) accounts"

        guard !forecast.points.isEmpty else {
            return "Across \(across)"
        }

        let projected = ForecastFormatter.currency(forecast.projectedBalance)
        return "Across \(across) · \(projected) in \(forecast.horizon.description)"
    }
}
