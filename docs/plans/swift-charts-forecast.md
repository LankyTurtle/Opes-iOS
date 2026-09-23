# Use Swift Charts for forecast visuals

## Summary

Replace the hand-drawn forecast chart with Swift Charts on both the net worth and account forecast screens. Keep the current static presentation and forecast calculations.

## Implementation changes

- Build a SwiftUI `Chart` from the existing `Forecast.points` and `todayIndex`. Use an `AreaMark` for the fading fill, solid and dashed `LineMark`s for history and projection, and `RuleMark`s for today and for zero when the balance crosses it. Preserve the current date labels, warning colors, and balance-based vertical scale.
- Embed the chart in the existing UIKit table row with a child `UIHostingController`. Update its root view when the forecast or horizon changes, while retaining the current placeholder and single VoiceOver summary.
- Remove the Core Animation drawing code after the replacement is verified. Leave `Forecast`, `BalanceForecaster`, and their data interfaces unchanged.

## Test plan

- Build the iOS app in Xcode or CI, then compare net worth and account forecasts across all four horizons.
- Check forecasts with no history, a flat balance, negative balances, and a line crossing zero. Verify the shared today point, dashed projection, date labels, colors, dark mode, Dynamic Type, and VoiceOver.
- Run the existing forecast-related transaction checks to confirm the calculation remains unchanged.

## Assumptions

- This change covers the chart on the forecast screens; the Home summary tile has no forecast chart to migrate.
- The chart remains static, as selected. Touch inspection and new forecast calculations are outside this change.
