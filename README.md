# Opes

Opes is a native iOS application for personal budgeting and payments. This
repository currently contains the SwiftUI application foundation and uses
local sample data only.

## Requirements

- Xcode 16 or newer
- iOS 17 or newer

## Getting started

1. Open `Opes.xcodeproj` in Xcode.
2. Select the `Opes` scheme and an iOS simulator.
3. Build and run with `Command-R`.

The login screen accepts any valid-looking email address and a password of at
least six characters. Authentication is simulated locally.

## Project structure

- `App` contains the app entry point, session state, and root navigation.
- `Features` contains the login, home, accounts, and profile screens.
- `Models` contains the local domain models and preview data.
- `Shared` contains reusable presentation components.
