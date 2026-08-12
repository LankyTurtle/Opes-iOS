import UIKit

/// The calendar unit a budget resets against.
enum BudgetPeriodUnit: String, Hashable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    fileprivate var calendarComponent: Calendar.Component {
        switch self {
        case .daily:
            return .day
        case .weekly:
            return .weekOfYear
        case .monthly:
            return .month
        case .yearly:
            return .year
        }
    }

    fileprivate var unitDescription: String {
        switch self {
        case .daily:
            return "day"
        case .weekly:
            return "week"
        case .monthly:
            return "month"
        case .yearly:
            return "year"
        }
    }

    /// Uses the system calendar and time zone, so a day includes the correct number
    /// of hours across daylight-saving changes and a month uses its actual length.
    func fractionElapsed(
        at date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> CGFloat {
        guard
            let interval = calendar.dateInterval(of: self.calendarComponent, for: date),
            interval.duration > 0
        else {
            return 0
        }

        let elapsed = date.timeIntervalSince(interval.start) / interval.duration
        return min(max(elapsed, 0), 1)
    }
}

/// Draws a budget's spending against its limit in one of three ways, chosen by
/// `BudgetChartStyle`.
///
/// Two vertical markers can appear: a solid one for the limit, and a fainter one for
/// how far through the period today falls. Which are shown depends on the style —
/// the limit is implicit at the end of the track under `.progress`, and elapsed time
/// has no meaningful position on the `.underOver` axis.
final class BudgetProgressView: UIView {
    private let trackView = UIView()
    private let fillView = UIView()
    private let periodMarkerView = UIView()
    private let limitMarkerView = UIView()

    private var spendingProgress: CGFloat = 0
    private var periodProgress: CGFloat = 0
    private var style: BudgetChartStyle = .progress

    private static let trackHeight: CGFloat = 6
    private static let markerWidth: CGFloat = 2
    private static let markerHeight: CGFloat = 14
    /// Two-and-a-half percentage points on either side of elapsed time is considered on pace.
    private static let onPaceTolerance: CGFloat = 0.025

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.markerHeight)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isAccessibilityElement = true

        self.trackView.backgroundColor = .tertiarySystemFill
        self.trackView.layer.cornerRadius = Self.trackHeight / 2
        self.trackView.clipsToBounds = true
        self.addSubview(self.trackView)

        self.fillView.layer.cornerRadius = Self.trackHeight / 2
        self.trackView.addSubview(self.fillView)

        // Fainter than the limit marker, so that where the two appear together the
        // money line reads as the primary one and time as secondary.
        self.periodMarkerView.backgroundColor = .secondaryLabel
        self.periodMarkerView.layer.cornerRadius = Self.markerWidth / 2
        self.addSubview(self.periodMarkerView)

        self.limitMarkerView.backgroundColor = .label
        self.limitMarkerView.layer.cornerRadius = Self.markerWidth / 2
        self.addSubview(self.limitMarkerView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard self.bounds.width > 0 else {
            return
        }

        let width = self.bounds.width
        self.trackView.frame = CGRect(
            x: 0,
            y: (self.bounds.height - Self.trackHeight) / 2,
            width: width,
            height: Self.trackHeight
        )

        switch self.style {
        case .progress:
            self.fillView.frame = self.trackRect(from: 0, to: min(self.spendingProgress, 1) * width)
            self.place(self.periodMarkerView, atX: self.periodProgress * width)

        case .underOver:
            // The limit is the centre, and one half-width represents a whole limit's
            // worth of over- or underspend, so the bar saturates at double or nothing.
            let centre = width / 2
            let difference = min(max(self.spendingProgress - 1, -1), 1)
            let extent = abs(difference) * centre
            self.fillView.frame = self.trackRect(
                from: difference >= 0 ? centre : centre - extent,
                to: difference >= 0 ? centre + extent : centre
            )
            self.place(self.limitMarkerView, atX: centre)

        case .scaling:
            // Overspending extends the axis past the limit, so the limit's own marker
            // slides left as the overspend grows.
            let axisMaximum = max(self.spendingProgress, 1)
            self.fillView.frame = self.trackRect(from: 0, to: self.spendingProgress / axisMaximum * width)
            self.place(self.limitMarkerView, atX: width / axisMaximum)
            self.place(self.periodMarkerView, atX: self.periodProgress / axisMaximum * width)
        }

        self.periodMarkerView.isHidden = self.style == .underOver
        self.limitMarkerView.isHidden = self.style == .progress
    }

    private func trackRect(from startX: CGFloat, to endX: CGFloat) -> CGRect {
        CGRect(x: startX, y: 0, width: max(endX - startX, 0), height: Self.trackHeight)
    }

    /// Clamped so a marker at either extreme stays wholly on the track.
    private func place(_ marker: UIView, atX x: CGFloat) {
        marker.bounds = CGRect(x: 0, y: 0, width: Self.markerWidth, height: Self.markerHeight)
        marker.center = CGPoint(
            x: min(max(x, Self.markerWidth / 2), self.bounds.width - Self.markerWidth / 2),
            y: self.bounds.midY
        )
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()

        self.updateFillColor()
    }

    func configure(
        spendingProgress: Float,
        periodUnit: BudgetPeriodUnit,
        style: BudgetChartStyle,
        date: Date = .now
    ) {
        // Retain values above 100% for pace, scaling and accessibility. Only the
        // rendered fill is clipped to the track in `layoutSubviews`.
        self.spendingProgress = max(CGFloat(spendingProgress), 0)
        self.periodProgress = periodUnit.fractionElapsed(at: date)
        self.style = style
        self.updateFillColor()

        self.accessibilityLabel = "Budget \(style.title)"
        self.accessibilityValue = self.accessibilityValue(for: periodUnit)

        self.setNeedsLayout()
    }

    private func accessibilityValue(for periodUnit: BudgetPeriodUnit) -> String {
        let spendingPercentage = Int((self.spendingProgress * 100).rounded())
        let periodPercentage = Int((self.periodProgress * 100).rounded())

        switch self.style {
        case .progress, .scaling:
            return "\(spendingPercentage) percent spent; \(periodPercentage) percent of the \(periodUnit.unitDescription) elapsed; \(self.paceDescription)"

        case .underOver:
            let difference = Int((abs(self.spendingProgress - 1) * 100).rounded())
            return self.spendingProgress > 1
                ? "\(difference) percent over the limit"
                : "\(difference) percent under the limit"
        }
    }

    private var paceDifference: CGFloat {
        self.spendingProgress - self.periodProgress
    }

    private var paceDescription: String {
        if self.paceDifference > Self.onPaceTolerance {
            return "spending is ahead of pace"
        }

        if self.paceDifference < -Self.onPaceTolerance {
            return "spending is behind pace"
        }

        return "spending is on pace"
    }

    private func updateFillColor() {
        switch self.style {
        case .progress, .scaling:
            if self.paceDifference > Self.onPaceTolerance {
                self.fillView.backgroundColor = .systemRed
            } else if self.paceDifference < -Self.onPaceTolerance {
                self.fillView.backgroundColor = .systemGreen
            } else {
                self.fillView.backgroundColor = self.tintColor
            }

        case .underOver:
            // This axis is about the limit rather than the pace, so the colour
            // follows which side of the centre line the bar sits on.
            self.fillView.backgroundColor = self.spendingProgress > 1 ? .systemRed : .systemGreen
        }
    }
}
