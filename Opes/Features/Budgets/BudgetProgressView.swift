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

/// A budget progress bar with a vertical marker showing how far through the budget
/// period the current system date is. Comparing the fill with the marker reveals
/// whether spending is running ahead of or behind time.
final class BudgetProgressView: UIView {
    private let trackView = UIView()
    private let fillView = UIView()
    private let periodMarkerView = UIView()

    private var spendingProgress: CGFloat = 0
    private var periodProgress: CGFloat = 0

    private static let trackHeight: CGFloat = 6
    private static let markerWidth: CGFloat = 2
    private static let markerHeight: CGFloat = 14

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

        self.periodMarkerView.backgroundColor = .label
        self.periodMarkerView.layer.cornerRadius = Self.markerWidth / 2
        self.addSubview(self.periodMarkerView)
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

        let trackY = (self.bounds.height - Self.trackHeight) / 2
        self.trackView.frame = CGRect(
            x: 0,
            y: trackY,
            width: self.bounds.width,
            height: Self.trackHeight
        )
        self.fillView.frame = CGRect(
            x: 0,
            y: 0,
            width: self.bounds.width * self.spendingProgress,
            height: Self.trackHeight
        )

        let markerX = min(
            max(self.bounds.width * self.periodProgress, Self.markerWidth / 2),
            self.bounds.width - Self.markerWidth / 2
        )
        self.periodMarkerView.bounds = CGRect(
            x: 0,
            y: 0,
            width: Self.markerWidth,
            height: Self.markerHeight
        )
        self.periodMarkerView.center = CGPoint(x: markerX, y: self.bounds.midY)
    }

    func configure(
        spendingProgress: Float,
        periodUnit: BudgetPeriodUnit,
        tintColor: UIColor,
        date: Date = .now
    ) {
        self.spendingProgress = min(max(CGFloat(spendingProgress), 0), 1)
        self.periodProgress = periodUnit.fractionElapsed(at: date)
        self.fillView.backgroundColor = tintColor

        let spendingPercentage = Int((self.spendingProgress * 100).rounded())
        let periodPercentage = Int((self.periodProgress * 100).rounded())
        self.accessibilityLabel = "Budget progress"
        self.accessibilityValue = "\(spendingPercentage) percent spent; \(periodPercentage) percent of the \(periodUnit.unitDescription) elapsed"

        self.setNeedsLayout()
    }
}
