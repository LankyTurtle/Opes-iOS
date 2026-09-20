# Opes

Opes is a native iOS application for personal budgeting and payments. This
repository contains the UIKit application foundation with sample data and
locally saved manual and CSV-imported transactions.

## Requirements

- Xcode 16 or newer
- iOS 26 or newer

## Getting started

1. Open `Opes.xcodeproj` in Xcode.
2. Select the `Opes` scheme and an iOS simulator.
3. Build and run with `Command-R`.

## Adding transactions

On Transactions, tap **+** to choose **Add Manually** or **Upload CSV**.
Manual entry supports an AUD amount, money in/out, date, merchant/description,
and an optional account. Saved transactions also appear in Home and the
transaction providers used by forecasts and pay cycles.

For CSVs, select an institution and choose a file from the device's Files picker.
Selecting the file does not parse or import it. Tap **Upload** to validate and
parse, review the first five transactions and total count, then tap **Import**
to save all parsed transactions. Replacing the file or changing the institution
clears the preview. Leaving before Import discards the selection. Processing is
local; there is no server upload.

The initial importer accepts UTF-8 or BOM-marked UTF-16 CSVs up to 10 MB and
20,000 transactions. It requires a header with `Date`, `Description` (or
`Merchant`), and signed `Amount`, or separate positive `Debit` and `Credit`
columns. Dates use `dd/MM/yyyy`, `yyyy-MM-dd`, `dd-MM-yyyy`, or `dd MMM yyyy`.
Amounts are AUD with up to two decimal places. Quoted commas, escaped quotes,
embedded newlines, CRLF, and a UTF-8 BOM are supported. The institution is saved
with each imported transaction; an account is not inferred. This is a common
header-based format, not a set of bank-specific export adapters. Invalid files
are rejected as a whole. Re-importing a file creates new transactions.

## Transaction checks

Run `./Tests/Transactions/run.ps1` with PowerShell and Swift installed. These
checks compile the production Foundation model, amount validation, CSV reader,
parser, and local store. A small account stand-in removes the UIKit dependency;
Windows also stubs security-scoped URL access, which must be checked on iOS.
Build in Xcode and verify the menu, both forms, Files picker cancellation,
Upload/preview/import flow, Dynamic Type, and VoiceOver on a device or simulator.

## Project structure

- `App` contains the app and scene delegates.
- `Enums` contains the app-wide enumerations, including the tab definitions.
- `Navigation` contains the root tab bar controller.
- `Features` contains the home, accounts, transactions, budgets, forecast, pay
  cycle, and profile screens.
- `Resources` contains the asset catalogue.
- `Shared` contains reusable presentation components.
