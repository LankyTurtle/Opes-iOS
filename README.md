# Opes

Opes is a native iOS application for personal budgeting and payments. This
repository currently contains the UIKit application foundation and uses
local sample data only.

## Requirements

- Xcode 16 or newer
- iOS 26 or newer

## Getting started

1. Open `Opes.xcodeproj` in Xcode.
2. Select the `Opes` scheme and an iOS simulator.
3. Build and run with `Command-R`.

## Project structure

- `App` contains the app and scene delegates.
- `Enums` contains the app-wide enumerations, including the tab definitions.
- `Navigation` contains the root tab bar controller.
- `Features` contains the home, accounts, transactions, budgets, forecast, pay
  cycle, and profile screens.
- `Resources` contains the asset catalogue.
- `Shared` contains reusable presentation components.
