import Foundation

/// How a budget's spending is drawn against its limit.
enum BudgetChartStyle: String, CaseIterable, Hashable {
    /// The track runs from nothing to the limit, and spending fills it.
    case progress
    /// The limit sits at the centre. The bar runs left while under it, right once over.
    case underOver
    /// The axis grows with overspending, which slides the limit's marker leftwards.
    case scaling

    /// Shown on the selection control.
    var title: String {
        switch self {
        case .progress:
            return "Progress"
        case .underOver:
            return "Diverge"
        case .scaling:
            return "Scale"
        }
    }

    /// Explains the chart beneath it, since none of the three is self-evident.
    var explanation: String {
        switch self {
        case .progress:
            return "The bar fills towards the limit, and the marker shows how far through the period today falls."
        case .underOver:
            return "The centre line is the limit. The bar runs left while spending is under it and right once it goes over."
        case .scaling:
            return "The solid line marks the limit. Spending past it stretches the axis, sliding that line further left."
        }
    }
}
