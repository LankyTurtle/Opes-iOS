import UIKit

/// Draws a forecast as a single line with a fading fill beneath it, plus a dashed
/// zero line when the projection crosses into the negative.
///
/// Hand-drawn because the app is UIKit, so there's no chart to lay a series on.
/// The y-axis is scaled to the series rather than anchored at zero: a net worth
/// carrying a mortgage would otherwise draw as a flat line at the top of a very
/// tall axis.
final class ForecastChartView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let areaMaskLayer = CAShapeLayer()
    private let lineLayer = CAShapeLayer()
    private let zeroLineLayer = CAShapeLayer()

    private let startLabel = UILabel()
    private let endLabel = UILabel()
    private let placeholderLabel = UILabel()

    private var points: [ForecastPoint] = []

    /// The line's colour. Set by the caller so a projection heading below zero can
    /// be drawn as a warning rather than as good news.
    var accentColor: UIColor = .systemTeal {
        didSet { self.setNeedsLayout() }
    }

    private static let lineWidth: CGFloat = 2
    private static let plotHeight: CGFloat = 176
    private static let labelSpacing: CGFloat = 6

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.gradientLayer.mask = self.areaMaskLayer
        self.layer.addSublayer(self.gradientLayer)

        self.zeroLineLayer.fillColor = nil
        self.zeroLineLayer.lineWidth = 1
        self.zeroLineLayer.lineDashPattern = [3, 3]
        self.layer.addSublayer(self.zeroLineLayer)

        self.lineLayer.fillColor = nil
        self.lineLayer.lineWidth = Self.lineWidth
        self.lineLayer.lineJoin = .round
        self.lineLayer.lineCap = .round
        self.layer.addSublayer(self.lineLayer)

        for label in [self.startLabel, self.endLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .preferredFont(forTextStyle: .caption1)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            self.addSubview(label)
        }
        self.endLabel.textAlignment = .right

        self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        self.placeholderLabel.font = .preferredFont(forTextStyle: .footnote)
        self.placeholderLabel.adjustsFontForContentSizeCategory = true
        self.placeholderLabel.textColor = .secondaryLabel
        self.placeholderLabel.textAlignment = .center
        self.placeholderLabel.numberOfLines = 0
        self.placeholderLabel.isHidden = true
        self.addSubview(self.placeholderLabel)

        // The line is one figure to VoiceOver; the screen around it carries the
        // numbers, so the caller supplies the summary.
        self.isAccessibilityElement = true

        NSLayoutConstraint.activate([
            self.startLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.startLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.endLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.endLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.endLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: self.startLabel.trailingAnchor,
                constant: DesignTokens.labelSpacing
            ),
            self.placeholderLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.placeholderLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.placeholderLabel.topAnchor.constraint(equalTo: self.topAnchor),
            self.placeholderLabel.bottomAnchor.constraint(equalTo: self.startLabel.topAnchor),
        ])

        // `CGColor` doesn't follow a trait change on its own, so the layers are
        // redrawn when the interface style flips.
        self.registerForTraitChanges(
            [UITraitUserInterfaceStyle.self]
        ) { (view: Self, _: UITraitCollection) in
            view.setNeedsLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: Self.plotHeight + Self.labelSpacing + ceil(self.startLabel.intrinsicContentSize.height)
        )
    }

    func show(_ forecast: Forecast, placeholder: String) {
        self.points = forecast.points
        self.placeholderLabel.text = placeholder

        self.startLabel.text = "Today"
        self.endLabel.text = forecast.endDate.map {
            $0.formatted(.dateTime.month(.abbreviated).year())
        }

        self.invalidateIntrinsicContentSize()
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Paths are set outside the animation UIKit has open during layout, so the
        // line snaps to its new shape rather than sweeping across the view.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.redraw()
        CATransaction.commit()
    }

    private func redraw() {
        let labelHeight = ceil(self.startLabel.intrinsicContentSize.height)
        let plot = CGRect(
            x: 0,
            y: 0,
            width: self.bounds.width,
            height: max(self.bounds.height - labelHeight - Self.labelSpacing, 0)
        )

        let hasSeries = self.points.count > 1 && plot.width > 0 && plot.height > 0
        self.placeholderLabel.isHidden = hasSeries
        self.startLabel.isHidden = !hasSeries
        self.endLabel.isHidden = !hasSeries
        self.lineLayer.isHidden = !hasSeries
        self.gradientLayer.isHidden = !hasSeries
        self.zeroLineLayer.isHidden = true

        guard hasSeries else {
            return
        }

        let values = self.points.map { NSDecimalNumber(decimal: $0.balance).doubleValue }
        // Stroke width is kept inside the plot so the line's ends aren't clipped.
        let usable = plot.insetBy(dx: 0, dy: Self.lineWidth)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 0
        let span = maximum - minimum

        func y(for value: Double) -> CGFloat {
            guard span > 0 else {
                return usable.midY
            }

            return usable.maxY - CGFloat((value - minimum) / span) * usable.height
        }

        func x(at index: Int) -> CGFloat {
            plot.minX + plot.width * CGFloat(index) / CGFloat(self.points.count - 1)
        }

        let line = UIBezierPath()
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: x(at: index), y: y(for: value))
            if index == 0 {
                line.move(to: point)
            } else {
                line.addLine(to: point)
            }
        }

        let area = UIBezierPath(cgPath: line.cgPath)
        area.addLine(to: CGPoint(x: x(at: values.count - 1), y: plot.maxY))
        area.addLine(to: CGPoint(x: x(at: 0), y: plot.maxY))
        area.close()

        let accent = self.accentColor.resolvedColor(with: self.traitCollection)

        self.lineLayer.path = line.cgPath
        self.lineLayer.strokeColor = accent.cgColor

        self.areaMaskLayer.path = area.cgPath
        self.areaMaskLayer.frame = self.bounds
        self.gradientLayer.frame = self.bounds
        self.gradientLayer.colors = [
            accent.withAlphaComponent(0.28).cgColor,
            accent.withAlphaComponent(0).cgColor,
        ]

        // Only worth drawing when the projection actually crosses it.
        if minimum < 0, maximum > 0 {
            let zeroLine = UIBezierPath()
            zeroLine.move(to: CGPoint(x: plot.minX, y: y(for: 0)))
            zeroLine.addLine(to: CGPoint(x: plot.maxX, y: y(for: 0)))
            self.zeroLineLayer.path = zeroLine.cgPath
            self.zeroLineLayer.strokeColor = UIColor.tertiaryLabel
                .resolvedColor(with: self.traitCollection)
                .cgColor
            self.zeroLineLayer.isHidden = false
        }
    }
}
