import UIKit

/// Home's at-a-glance summary of the current monthly budgets.
final class BudgetsTileView: UIView {
    private let headerLabel = UILabel()
    private let remainingLabel = UILabel()
    private let spentLabel = UILabel()
    private let progressView = BudgetProgressView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // The enclosing list cell supplies the grouped-card background and corners.
        self.backgroundColor = .clear

        self.headerLabel.font = .preferredFont(forTextStyle: .headline)
        self.headerLabel.adjustsFontForContentSizeCategory = true
        self.headerLabel.text = "Budgets"

        self.remainingLabel.font = DesignTokens.tileValueFont
        self.remainingLabel.adjustsFontForContentSizeCategory = true
        self.remainingLabel.numberOfLines = 1
        self.remainingLabel.adjustsFontSizeToFitWidth = true
        self.remainingLabel.minimumScaleFactor = 0.5

        self.spentLabel.font = .preferredFont(forTextStyle: .footnote)
        self.spentLabel.adjustsFontForContentSizeCategory = true
        self.spentLabel.textColor = .secondaryLabel
        self.spentLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            self.headerLabel,
            self.remainingLabel,
            self.spentLabel,
            self.progressView,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(DesignTokens.labelSpacing, after: self.headerLabel)
        stack.setCustomSpacing(DesignTokens.captionSpacing, after: self.remainingLabel)
        self.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: DesignTokens.cardPadding),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.cardPadding),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.cardPadding),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -DesignTokens.cardPadding),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(budgets: [BudgetPreview]) {
        let spent = budgets.reduce(Decimal.zero) { $0 + $1.spent }
        let limit = budgets.reduce(Decimal.zero) { $0 + $1.limit }
        let remaining = limit - spent
        let spendingProgress = limit > 0
            ? NSDecimalNumber(decimal: spent / limit).floatValue
            : 0

        let formattedRemaining: String
        if remaining >= 0 {
            formattedRemaining = "\(remaining.formatted(.currency(code: "AUD"))) remaining"
        } else {
            formattedRemaining = "\((-remaining).formatted(.currency(code: "AUD"))) over budget"
        }

        let formattedSpent = spent.formatted(.currency(code: "AUD"))
        let formattedLimit = limit.formatted(.currency(code: "AUD"))

        self.remainingLabel.text = formattedRemaining
        self.remainingLabel.textColor = remaining >= 0 ? .label : .systemRed
        self.spentLabel.text = "\(formattedSpent) spent of \(formattedLimit) this month"
        // The Home summary always uses the plain progress bar. The chart choice on
        // the Budgets screen is a way to interrogate the numbers there, not a
        // preference that should follow the user around the app.
        self.progressView.configure(
            spendingProgress: max(spendingProgress, 0),
            periodUnit: .monthly,
            style: .progress
        )

        self.isAccessibilityElement = true
        self.accessibilityLabel = "Budgets, \(formattedRemaining), \(formattedSpent) spent of \(formattedLimit) this month"
    }
}
