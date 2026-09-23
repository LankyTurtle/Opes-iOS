import Charts
import SwiftUI
import UIKit

/// A balance over time: solid through the history it was reconstructed from,
/// dashed once it crosses into projection, with a fading fill beneath and a marker
/// on today.
///
/// The y-axis is scaled to the series rather than anchored at zero: a net worth
/// carrying a mortgage would otherwise draw as a flat line at the top of a very
/// tall axis.
struct ForecastChart: View {
    let forecast: Forecast
    /// The line's colour. Set by the caller so a projection heading below zero can
    /// be drawn as a warning rather than as good news.
    let accentColor: UIColor
    let placeholder: String
    /// The line is one figure to VoiceOver; the screen around it carries the
    /// numbers, so the caller supplies the summary.
    let accessibilityDescription: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let lineWidth: CGFloat = 2
    private static let plotHeight: CGFloat = 176
    private static let labelSpacing: CGFloat = 6

    /// One day's balance, in the half of the line it's drawn in.
    private struct Sample: Identifiable {
        enum Part {
            case history
            case projection
        }

        let day: Int
        let balance: Double
        let part: Part

        var id: String { "\(self.part)-\(self.day)" }
    }

    var body: some View {
        VStack(spacing: Self.labelSpacing) {
            if self.hasSeries {
                self.chart
                    .frame(height: Self.plotHeight)
            } else {
                Text(self.placeholder)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: Self.plotHeight)
            }

            // Kept when there's no line, so the row doesn't change height as a
            // forecast appears.
            self.dateLabels
                .opacity(self.hasSeries ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(self.accessibilityDescription))
    }

    private var hasSeries: Bool {
        self.forecast.points.count > 1
    }

    private var values: [Double] {
        self.forecast.points.map { NSDecimalNumber(decimal: $0.balance).doubleValue }
    }

    /// Where history stops and the projection starts.
    private var boundary: Int {
        min(max(self.forecast.todayIndex, 0), self.forecast.points.count - 1)
    }

    /// The series' own range, padded when the balance never moves so the line sits
    /// mid-plot rather than along an edge.
    private var yDomain: ClosedRange<Double> {
        let values = self.values
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 0
        return minimum < maximum ? minimum...maximum : (minimum - 1)...(maximum + 1)
    }

    private var chart: some View {
        let values = self.values
        let boundary = self.boundary
        let domain = self.yDomain
        let accent = Color(uiColor: self.accentColor)

        // The two halves share the point on today, so the dash starts where the
        // solid line ends rather than a day after it.
        let line = values.indices.flatMap { day -> [Sample] in
            var samples: [Sample] = []
            if day <= boundary {
                samples.append(Sample(day: day, balance: values[day], part: .history))
            }
            if day >= boundary {
                samples.append(Sample(day: day, balance: values[day], part: .projection))
            }
            return samples
        }
        let crossesZero = (values.min() ?? 0) < 0 && (values.max() ?? 0) > 0

        return Chart {
            // One continuous area rather than one under each half, filled down to
            // the bottom of the plot rather than to zero.
            ForEach(values.indices, id: \.self) { day in
                AreaMark(
                    x: .value("Day", day),
                    yStart: .value("Floor", domain.lowerBound),
                    yEnd: .value("Balance", values[day])
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent.opacity(0.28), accent.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Only worth drawing when the balance actually crosses it.
            if crossesZero {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }

            // A faint upright through today, so the switch from fact to estimate
            // has a place on the axis rather than only a change of stroke.
            if boundary > 0 {
                RuleMark(x: .value("Today", boundary))
                    .foregroundStyle(Color(uiColor: .quaternaryLabel))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }

            // Dashed ahead of today, because everything past that point is an
            // estimate and shouldn't read with the same authority as the statement
            // behind it.
            ForEach(line) { sample in
                LineMark(
                    x: .value("Day", sample.day),
                    y: .value("Balance", sample.balance),
                    series: .value("Part", sample.part == .history ? "History" : "Projection")
                )
                .foregroundStyle(accent)
                .lineStyle(
                    StrokeStyle(
                        lineWidth: Self.lineWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: sample.part == .history ? [] : [5, 4]
                    )
                )
            }
        }
        .chartXScale(domain: 0...(values.count - 1))
        .chartYScale(domain: domain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private var startText: String {
        self.forecast.startDate.map(Self.monthLabel) ?? ""
    }

    private var endText: String {
        self.forecast.endDate.map(Self.monthLabel) ?? ""
    }

    private var dateLabels: some View {
        HStack(spacing: 0) {
            Text(self.startText)
            Spacer(minLength: DesignTokens.labelSpacing)
            Text(self.endText)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        // Moved to wherever today falls, which isn't the middle unless the history
        // and the horizon happen to match.
        .overlay {
            GeometryReader { geometry in
                if let position = self.todayLabelPosition(across: geometry.size.width) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: position, y: geometry.size.height / 2)
                }
            }
        }
    }

    /// Only labelled with clear space either side, so it can't run into the dates
    /// at the ends and read as one of them: "Today Dec 2026".
    private func todayLabelPosition(across width: CGFloat) -> CGFloat? {
        let count = self.forecast.points.count
        let boundary = self.boundary
        guard count > 1, boundary > 0, width > 0 else {
            return nil
        }

        let position = width * CGFloat(boundary) / CGFloat(count - 1)
        let halfWidth = self.textWidth("Today") / 2
        let gap = DesignTokens.labelSpacing * 2
        let clearOfStart = position - halfWidth >= self.textWidth(self.startText) + gap
        let clearOfEnd = position + halfWidth <= width - self.textWidth(self.endText) - gap
        return clearOfStart && clearOfEnd ? position : nil
    }

    /// Measured in the caption font at the reader's text size, to match the labels.
    private func textWidth(_ text: String) -> CGFloat {
        let traits = UITraitCollection(
            preferredContentSizeCategory: UIContentSizeCategory(self.dynamicTypeSize)
        )
        let font = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func monthLabel(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year())
    }
}
