# Use Swift Charts for forecast visuals

## Summary

Replace the hand-drawn forecast chart with Swift Charts on both the net worth and account forecast screens. Keep the current static presentation and forecast calculations.

## Implementation changes

- Build a SwiftUI `Chart` from the existing `Forecast.points` and `todayIndex`, plotted by day index so the line spans the full width as it does now.
- Draw history and projection as two `LineMark` series that share the today point, so the solid line hands over to the dashed `[5, 4]` projection without a gap. Use an `AreaMark` with a fading gradient beneath, a `RuleMark` on today (only when there is history), and a dashed `RuleMark` at zero only when the balance crosses it.
- Keep the balance-based vertical scale: set `chartYScale(domain:)` to the series' minimum and maximum (padded when flat, so the line sits mid-plot), and start the `AreaMark` at the domain minimum rather than zero.
- Keep the plot at its fixed 176pt height. Hide the chart's own axes and draw the start, Today and end month labels beneath it, keeping the rule that Today is only labelled when clear of the end labels.
- Keep the warning colours by passing the same `UIColor` accent through `Color(uiColor:)`; dynamic colours then follow dark mode without the trait-change redraw.
- Keep the current placeholder and the single VoiceOver summary: the chart ignores its children for accessibility and carries the existing `chartDescription(for:)` label, rather than exposing each point.
- Host the chart in the table row with `UIHostingConfiguration` as the cell's content configuration, updated when the forecast or horizon changes.
- Remove the Core Animation drawing code in the same change; git history is the fallback. Leave `Forecast`, `BalanceForecaster`, and their data interfaces unchanged.

## Test plan

- There is no Xcode or CI build on this machine; the TestFlight workflow is the only compile, so the chart is checked on device after a push.
- On device, compare net worth and account forecasts across all four horizons. Check forecasts with no history, a flat balance, negative balances, and a line crossing zero. Verify the shared today point, dashed projection, date labels (including Today hiding near the ends), colours, dark mode, Dynamic Type, and VoiceOver.
- Run the transaction checks to confirm the calculation is unchanged; they don't exercise the chart.

## Assumptions

- This change covers the chart on the forecast screens; the Home net worth tile shows text only and has no forecast chart to migrate.
- The chart remains static, as selected. Touch inspection and new forecast calculations are outside this change.
