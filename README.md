# Opes

Opes is a native iOS application for personal budgeting and payments. This
repository contains the UIKit application foundation with locally saved accounts
and manual and CSV-imported transactions. Account and transaction lists start empty
on a fresh install; existing user-created records are preserved on upgrade.

## Requirements

- Xcode 16 or newer
- iOS 26 or newer

## Getting started

1. Open `Opes.xcodeproj` in Xcode.
2. Select the `Opes` scheme and an iOS simulator.
3. Build and run with `Command-R`.

## Adding transactions

On Accounts, tap **+** to add an account. Swipe left on an account to reveal
**Delete**, or swipe fully to delete it and all linked transactions. Deletions
persist across launches. Other accounts and
their history are preserved.

On Transactions, tap **+** to choose **Add Manually** or **Upload CSV**.
Manual entry supports an AUD amount, money in/out, date, merchant/description,
and a required account. Saved transactions also appear in Home and the
transaction providers used by forecasts and pay cycles.

Swipe left on a transaction to reveal **Delete**, or swipe fully to delete it.
Deletion works within search results and persists across launches.
Home and forecasts use the updated history when reopened.
The bottom of the transaction detail screen also offers **Delete Transaction**.
Deleting there returns to the list or closes the Home detail card and refreshes
the visible history.

For CSVs, select an account and choose a file from the device's Files picker.
Both transaction forms offer **Add New Account…** in the account menu. Enter a
name, type, number, and institution to save an account locally and select it
immediately. Types are Transaction, Savings, Credit Card, Charge Card, Personal
Loan, Home Loan, and Investment Loan. An optional six-digit BSB can be entered
for every type except credit and charge cards. Accounts saved before these
fields existed load as Transaction accounts with no number.
New accounts also appear in Accounts, Home, forecasts, and pay-cycle selectors.
Their current balance starts at zero; importing history does not derive a balance.
Selecting the file does not parse or import it. Tap **Upload** to validate and
parse, review the first five transactions and total count, then tap **Import**
to save all parsed transactions linked to that account. Replacing the file or changing the account
clears the preview. Leaving before Import discards the selection. Processing is
local; there is no server upload.

The initial importer accepts UTF-8 or BOM-marked UTF-16 CSVs up to 10 MB and
20,000 transactions. It requires a header with `Date`, `Description` (or
`Merchant`), and signed `Amount`, or separate positive `Debit` and `Credit`
columns. Dates use `dd/MM/yyyy`, `yyyy-MM-dd`, `dd-MM-yyyy`, or `dd MMM yyyy`.
Amounts are AUD with up to two decimal places. Quoted commas, escaped quotes,
embedded newlines, CRLF, and a UTF-8 BOM are supported. The institution is saved
with each imported transaction alongside the selected account's stable identifier. This is a common
header-based format, not a set of bank-specific export adapters. Invalid files
are rejected as a whole. Re-importing a file creates new transactions.
New transactions cannot be saved without an account. Previously saved unlinked
history remains readable; this change does not guess accounts for legacy records.

## Transaction checks

Run `./Tests/Transactions/run.ps1` with PowerShell and Swift installed. These
checks compile the production Foundation model, amount validation, CSV reader,
parser, account persistence, and transaction store. A small account-preview stand-in removes the UIKit dependency;
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
