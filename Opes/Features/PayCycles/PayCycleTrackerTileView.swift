import UIKit

/// A compact Home summary. The full list remains available through its tap action,
/// while Home stays bounded to the three nearest enabled cycles.
final class PayCycleTrackerTileView: UIControl {
    private let headerLabel = UILabel()
    private let rowsStack = UIStackView()
    private let emptyLabel = UILabel()
    private let addButton = UIButton(type: .system)
    private let calculator = NextPayDateCalculator()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.headerLabel.font = .preferredFont(forTextStyle: .headline)
        self.headerLabel.adjustsFontForContentSizeCategory = true
        self.headerLabel.text = "Pay Cycles"

        self.rowsStack.axis = .vertical
        self.rowsStack.spacing = 8

        self.emptyLabel.font = .preferredFont(forTextStyle: .body)
        self.emptyLabel.adjustsFontForContentSizeCategory = true
        self.emptyLabel.textColor = .secondaryLabel
        self.emptyLabel.numberOfLines = 0
        self.emptyLabel.text = "Add a pay cycle to see your next pay day."

        var buttonConfiguration = UIButton.Configuration.tinted()
        buttonConfiguration.title = "Add Pay Cycle"
        buttonConfiguration.image = UIImage(systemName: "plus")
        buttonConfiguration.imagePadding = 6
        self.addButton.configuration = buttonConfiguration
        self.addButton.contentHorizontalAlignment = .leading
        self.addButton.addTarget(self, action: #selector(self.handleAddTap), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [self.headerLabel, self.rowsStack, self.emptyLabel, self.addButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = DesignTokens.titleSpacing
        self.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: DesignTokens.cardPadding),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.cardPadding),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.cardPadding),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -DesignTokens.cardPadding),
        ])

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { self.alpha = self.isHighlighted ? 0.6 : 1 }
    }

    func show(cycles: [PayCycle], from date: Date = .now) {
        self.rowsStack.arrangedSubviews.forEach {
            self.rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let upcoming = cycles
            .filter(\.isEnabled)
            .compactMap { cycle -> (PayCycle, PayCycleDateDisplay)? in
                guard let display = self.calculator.display(for: cycle, from: date) else { return nil }
                return (cycle, display)
            }
            .sorted { $0.1.date < $1.1.date }
            .prefix(3)

        self.emptyLabel.isHidden = !upcoming.isEmpty
        self.addButton.isHidden = !upcoming.isEmpty
        guard !upcoming.isEmpty else {
            self.accessibilityLabel = "Pay Cycles. Add a pay cycle to see your next pay day."
            self.accessibilityHint = "Open pay cycle management"
            return
        }

        for (cycle, display) in upcoming {
            self.rowsStack.addArrangedSubview(Self.makeRow(cycle: cycle, display: display))
        }

        let summary = upcoming.map { "\($0.0.name), \($0.1.countdown), \($0.1.date.formatted(date: .abbreviated, time: .omitted))" }
            .joined(separator: ". ")
        self.accessibilityLabel = "Pay Cycles. \(summary)"
        self.accessibilityHint = "Open pay cycle management"
    }

    @objc private func handleAddTap() {
        self.sendActions(for: .touchUpInside)
    }

    private static func makeRow(cycle: PayCycle, display: PayCycleDateDisplay) -> UIView {
        let name = UILabel()
        name.font = .preferredFont(forTextStyle: .body)
        name.adjustsFontForContentSizeCategory = true
        name.text = cycle.name
        name.numberOfLines = 1

        let countdown = UILabel()
        countdown.font = .preferredFont(forTextStyle: .subheadline)
        countdown.adjustsFontForContentSizeCategory = true
        countdown.textColor = .secondaryLabel
        countdown.textAlignment = .right
        countdown.text = display.countdown
        countdown.setContentHuggingPriority(.required, for: .horizontal)

        let date = UILabel()
        date.font = .preferredFont(forTextStyle: .footnote)
        date.adjustsFontForContentSizeCategory = true
        date.textColor = .secondaryLabel
        date.text = display.date.formatted(date: .abbreviated, time: .omitted)

        let titleRow = UIStackView(arrangedSubviews: [name, countdown])
        titleRow.axis = .horizontal
        titleRow.spacing = 12

        let row = UIStackView(arrangedSubviews: [titleRow, date])
        row.axis = .vertical
        row.spacing = 2
        row.isAccessibilityElement = false
        return row
    }
}
