import UIKit

/// Draws a balance over time: solid through the history it was reconstructed from,
/// dashed once it crosses into projection, with a fading fill beneath and a marker
/// on today.
///
/// Hand-drawn because the app is UIKit, so there's no chart to lay a series on.
/// The y-axis is scaled to the series rather than anchored at zero: a net worth
/// carrying a mortgage would otherwise draw as a flat line at the top of a very
/// tall axis.
final class ForecastChartView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let areaMaskLayer = CAShapeLayer()
    private let historyLineLayer = CAShapeLayer()
    private let projectionLineLayer = CAShapeLayer()
    private let todayLineLayer = CAShapeLayer()
    private let zeroLineLayer = CAShapeLayer()

    private let startLabel = UILabel()
    private let todayLabel = UILabel()
    private let endLabel = UILabel()
    private let placeholderLabel = UILabel()

    private var points: [ForecastPoint] = []
    /// Where history stops and the projection starts.
    private var todayIndex = 0

    /// Moved to wherever today falls, which isn't the middle unless the history and
    /// the horizon happen to match.
    private lazy var todayLabelCentre = self.todayLabel.centerXAnchor.constraint(
        equalTo: self.leadingAnchor
    )

    /// The line's colour. Set by the caller so a projection heading below zero can
    /// be drawn as a warning rather than as good news.
    var accentColor: UIColor = .systemTeal {
        didSet { self.setNeedsLayout() }
    }

    private static let lineWidth: CGFloat = 2
    private static let plotHeight: CGFloat = 176
    private static let labelSpacing: CGFloat = 6
    /// How far from either edge today has to fall before its label is worth showing
    /// rather than colliding with the dates at the ends.
    private static let todayLabelMargin: CGFloat = 0.18

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.gradientLayer.mask = self.areaMaskLayer
        self.layer.addSublayer(self.gradientLayer)

        self.zeroLineLayer.fillColor = nil
        self.zeroLineLayer.lineWidth = 1
        self.zeroLineLayer.lineDashPattern = [3, 3]
        self.layer.addSublayer(self.zeroLineLayer)

        self.todayLineLayer.fillColor = nil
        self.todayLineLayer.lineWidth = 1
        self.layer.addSublayer(self.todayLineLayer)

        for line in [self.historyLineLayer, self.projectionLineLayer] {
            line.fillColor = nil
            line.lineWidth = Self.lineWidth
            line.lineJoin = .round
            line.lineCap = .round
            self.layer.addSublayer(line)
        }

        // Dashed ahead of today, because everything past that point is an estimate
        // and shouldn't read with the same authority as the statement behind it.
        self.projectionLineLayer.lineDashPattern = [5, 4]

        for label in [self.startLabel, self.todayLabel, self.endLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .preferredFont(forTextStyle: .caption1)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            self.addSubview(label)
        }
        self.endLabel.textAlignment = .right
        self.todayLabel.text = "Today"

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
            self.todayLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.todayLabelCentre,
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
        self.todayIndex = forecast.todayIndex
        self.placeholderLabel.text = placeholder

        self.startLabel.text = forecast.startDate.map(Self.monthLabel)
        self.endLabel.text = forecast.endDate.map(Self.monthLabel)

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

    private static func monthLabel(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year())
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
        self.historyLineLayer.isHidden = !hasSeries
        self.projectionLineLayer.isHidden = !hasSeries
        self.gradientLayer.isHidden = !hasSeries
        self.todayLineLayer.isHidden = true
        self.todayLabel.isHidden = true
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

        func path(over range: Range<Int>) -> UIBezierPath {
            let line = UIBezierPath()

            for index in range {
                let point = CGPoint(x: x(at: index), y: y(for: values[index]))
                if index == range.lowerBound {
                    line.move(to: point)
                } else {
                    line.addLine(to: point)
                }
            }

            return line
        }

        // The two halves share the point on today, so the dash starts where the
        // solid line ends rather than a day after it.
        let boundary = min(max(self.todayIndex, 0), values.count - 1)
        let history = path(over: 0..<(boundary + 1))
        let projection = path(over: boundary..<values.count)

        // One continuous path rather than the two stroked halves joined, so the fill
        // closes down to the baseline instead of across each half.
        let area = path(over: 0..<values.count)
        area.addLine(to: CGPoint(x: x(at: values.count - 1), y: plot.maxY))
        area.addLine(to: CGPoint(x: x(at: 0), y: plot.maxY))
        area.close()

        let accent = self.accentColor.resolvedColor(with: self.traitCollection)

        self.historyLineLayer.path = history.cgPath
        self.historyLineLayer.strokeColor = accent.cgColor
        self.projectionLineLayer.path = projection.cgPath
        self.projectionLineLayer.strokeColor = accent.cgColor

        self.areaMaskLayer.path = area.cgPath
        self.areaMaskLayer.frame = self.bounds
        self.gradientLayer.frame = self.bounds
        self.gradientLayer.colors = [
            accent.withAlphaComponent(0.28).cgColor,
            accent.withAlphaComponent(0).cgColor,
        ]

        self.drawTodayMarker(at: x(at: boundary), in: plot, hasHistory: boundary > 0)
        self.drawZeroLine(in: plot, y: y(for: 0), minimum: minimum, maximum: maximum)
    }

    /// A faint upright through today, so the switch from fact to estimate has a
    /// place on the axis rather than only a change of stroke.
    private func drawTodayMarker(at position: CGFloat, in plot: CGRect, hasHistory: Bool) {
        guard hasHistory, plot.width > 0 else {
            return
        }

        let marker = UIBezierPath()
        marker.move(to: CGPoint(x: position, y: plot.minY))
        marker.addLine(to: CGPoint(x: position, y: plot.maxY))

        self.todayLineLayer.path = marker.cgPath
        self.todayLineLayer.strokeColor = UIColor.quaternaryLabel
            .resolvedColor(with: self.traitCollection)
            .cgColor
        self.todayLineLayer.isHidden = false

        // Only labelled when it isn't about to sit on top of the dates at the ends.
        let share = position / plot.width
        self.todayLabel.isHidden = share < Self.todayLabelMargin
            || share > 1 - Self.todayLabelMargin

        if self.todayLabelCentre.constant != position {
            self.todayLabelCentre.constant = position
        }
    }

    /// Only worth drawing when the balance actually crosses it.
    private func drawZeroLine(in plot: CGRect, y: CGFloat, minimum: Double, maximum: Double) {
        guard minimum < 0, maximum > 0 else {
            return
        }

        let zeroLine = UIBezierPath()
        zeroLine.move(to: CGPoint(x: plot.minX, y: y))
        zeroLine.addLine(to: CGPoint(x: plot.maxX, y: y))

        self.zeroLineLayer.path = zeroLine.cgPath
        self.zeroLineLayer.strokeColor = UIColor.tertiaryLabel
            .resolvedColor(with: self.traitCollection)
            .cgColor
        self.zeroLineLayer.isHidden = false
    }
}
