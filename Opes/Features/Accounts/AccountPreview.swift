import UIKit

struct AccountPreview: Hashable, Identifiable {
    let id: UUID
    let name: String
    /// Positive for credit, negative for debt.
    let balance: Decimal
    let institution: String
    let institutionLogo: UIImage

    var formattedBalance: String {
        self.balance.formatted(.currency(code: "AUD"))
    }
}

extension AccountPreview {
    /// Local sample data, until accounts come from a real store.
    static let sample: [AccountPreview] = [
        .makeSample(
            name: "Everyday Access",
            institution: "Commonwealth Bank",
            cents: 248_162,
            symbolName: "building.columns.fill"
        ),
        .makeSample(
            name: "Bills",
            institution: "Commonwealth Bank",
            cents: 41_055,
            symbolName: "building.columns.fill"
        ),
        .makeSample(
            name: "Savings Maximiser",
            institution: "ING",
            cents: 1_820_430,
            symbolName: "banknote.fill"
        ),
        .makeSample(
            name: "Spending",
            institution: "Up",
            cents: 32_618,
            symbolName: "arrow.up.circle.fill"
        ),
        .makeSample(
            name: "Offset",
            institution: "Macquarie",
            cents: 2_490_000,
            symbolName: "chart.line.uptrend.xyaxis"
        ),
        .makeSample(
            name: "Platinum Card",
            institution: "American Express",
            cents: -128_476,
            symbolName: "creditcard.fill"
        ),
        .makeSample(
            name: "Home Loan",
            institution: "Westpac",
            cents: -41_265_000,
            symbolName: "house.fill"
        ),
    ]

    private static func makeSample(
        name: String,
        institution: String,
        cents: Int,
        symbolName: String
    ) -> AccountPreview {
        AccountPreview(
            id: UUID(),
            name: name,
            // Built from whole cents so the sample balances stay exact.
            balance: Decimal(cents) / 100,
            institution: institution,
            // Standing in for real institution artwork. Falling back rather than
            // force unwrapping means a bad symbol name shows a blank logo instead
            // of taking the list down.
            institutionLogo: UIImage(systemName: symbolName) ?? UIImage()
        )
    }
}
