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

Tap the filter button beside **+** to show only certain account types or
institutions. Choose more than one option to combine them: choices within Type
or Institution widen the list (Transaction or Savings), while choices across
both narrow it (Transaction accounts at Macquarie). Institutions match
regardless of case. The button is tinted while a filter is on; choose **Clear
Filters** in the menu, or in the empty list, to show every account again.
Filters reset when the app relaunches.

On Transactions, tap **+** to choose **Add Manually** or **Upload CSV**.
Manual entry supports an AUD amount, money in/out, date and time, description,
and a required account. If that account is deleted while the screen is open,
**Save** says so, clears the account (keeping everything else entered), and
offers **Add New Account** or **Choose Another Account**. Saved transactions also appear in Home and the
transaction providers used by forecasts and pay cycles.

Swipe left on a transaction to reveal **Delete**, or swipe fully to delete it.
Deletion works within search results and persists across launches.
Home and forecasts use the updated history when reopened.
The bottom of the transaction detail screen also offers **Delete Transaction**.
Deleting there returns to the list or closes the Home detail card and refreshes
the visible history.

The top of transaction details shows **Debit** or **Credit**, the amount without
a sign, and when it happened (`Tue 22 Sep 2026, 3:45 pm`). CSV imports carry
no time, so they show only the date, here and in lists.

Below that, details show a **Summary**, the original
**Description**, and the **Reference** ("None" when the transaction has none).
The summary starts as the description; edit it to change how the
transaction is shown in lists, Home, pay cycles, and the details title. Clearing
it goes back to the description, which is never changed. Search matches the
summary, description, or reference.

For CSVs, select an account and choose a file from the device's Files picker.
Both transaction forms offer **Add New Account…** in the account menu. Enter a
name, type, institution, and number to save an account locally and select it
immediately. Types are Transaction, Savings, Credit Card, Charge Card, Personal
Loan, Home Loan, and Investment Loan. A six-digit BSB, entered between institution and number, is required for every
type except credit and charge cards, which have none; the hyphen is added as you
type the fourth digit.
New accounts also appear in Accounts, Home, forecasts, and pay-cycle selectors.
Their current balance starts at zero; importing history does not derive a balance.
Selecting the file does not parse or import it. Tap **Upload** to validate and
parse, review the first five transactions and total count, then tap **Import**
to save all parsed transactions linked to that account. Replacing the file or changing the account
clears the preview. If the selected account is deleted while the screen is open,
**Upload** and **Import** say so, clear the account and preview (keeping the
file), and offer **Add New Account** or **Choose Another Account**. Leaving
before Import discards the selection. Processing is
local; there is no server upload.

The initial importer accepts UTF-8 or BOM-marked UTF-16 CSVs up to 10 MB and
20,000 transactions. It requires a header with `Date`, `Description` (or
`Merchant`), and signed `Amount`, or separate positive `Debit` and `Credit`
columns. An optional `Reference` (or `Ref`, `Transaction Reference`, `Receipt
Number`) column is saved with each transaction; blank cells mean no reference.
Dates use `dd/MM/yyyy`, `yyyy-MM-dd`, `dd-MM-yyyy`, or `dd MMM yyyy`.
Amounts are AUD with up to two decimal places. Quoted commas, escaped quotes,
embedded newlines, CRLF, and a UTF-8 BOM are supported. The institution is saved
with each imported transaction alongside the selected account's stable identifier. This is a common
header-based format, not a set of bank-specific export adapters. Invalid files
are rejected as a whole. Re-importing a file creates new transactions.
Every transaction belongs to an account.

During development, saved data is neither versioned nor migrated: a model change
can leave existing accounts, transactions, or pay cycles unreadable, and they
need to be entered again.

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
