import UIKit

/// The headline of a forecast screen: what the balance is now, and where the
/// projection lands.
final class ForecastSummaryView: UIView {
    private let titleLabel = UILabel()
    private let balanceLabel = UILabel()
    private let projectionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // The list cell draws the card background and corners at the system radius.
        self.backgroundColor = .clear

        self.titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        self.titleLabel.adjustsFontForContentSizeCategory = true
        self.titleLabel.textColor = .secondaryLabel
        self.titleLabel.numberOfLines = 0

        self.balanceLabel.font = DesignTokens.tileValueFont
        self.balanceLabel.adjustsFontForContentSizeCategory = true
        // One line that shrinks to fit, so a balance carrying a mortgage doesn't
        // wrap. Scaling needs a non-zero minimum to engage at all.
        self.balanceLabel.numberOfLines = 1
        self.balanceLabel.adjustsFontSizeToFitWidth = true
        self.balanceLabel.minimumScaleFactor = 0.5

        self.projectionLabel.font = .preferredFont(forTextStyle: .footnote)
        self.projectionLabel.adjustsFontForContentSizeCategory = true
        self.projectionLabel.textColor = .secondaryLabel
        self.projectionLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            self.titleLabel,
            self.balanceLabel,
            self.projectionLabel,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = DesignTokens.captionSpacing
        stack.setCustomSpacing(DesignTokens.labelSpacing, after: self.titleLabel)
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

    func show(title: String, forecast: Forecast) {
        let balance = ForecastFormatter.currency(forecast.startingBalance)
        let projection = Self.projectionDescription(for: forecast)

        self.titleLabel.text = title
        self.balanceLabel.text = balance
        self.projectionLabel.text = projection

        self.accessibilityLabel = "\(title), \(balance). \(projection)"
    }

    private static func projectionDescription(for forecast: Forecast) -> String {
        guard !forecast.points.isEmpty else {
            return "Not enough information to project a balance yet."
        }

        let projected = ForecastFormatter.currency(forecast.projectedBalance)
        let change = ForecastFormatter.signedCurrency(forecast.change)

        return "\(projected) in \(forecast.horizon.description) · \(change)"
    }
}

/// One place for the two currency shapes the forecast screens use, so a projected
/// figure and the change that produced it always read the same way.
enum ForecastFormatter {
    static func currency(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "AUD"))
    }

    /// Always carries its sign, because a change of zero and a fall of a thousand
    /// have to be told apart at a glance.
    static func signedCurrency(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "AUD").sign(strategy: .always()))
    }
}
