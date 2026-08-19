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

/// Screens depend on this small read interface instead of a particular local
/// store. A backend implementation can replace the sample provider later.
protocol AccountProviding {
    func accounts() -> [AccountPreview]
}

struct SampleAccountProvider: AccountProviding {
    func accounts() -> [AccountPreview] {
        AccountPreview.sample
    }
}

extension AccountPreview {
    /// Local sample data, until accounts come from a real store. Each is named so
    /// sample transactions and pay cycles can point at one.
    static let everydayAccess = AccountPreview.makeSample(
        seed: 1,
        name: "Everyday Access",
        institution: "Commonwealth Bank",
        cents: 248_162,
        symbolName: "building.columns.fill"
    )
    static let bills = AccountPreview.makeSample(
        seed: 2,
        name: "Bills",
        institution: "Commonwealth Bank",
        cents: 41_055,
        symbolName: "building.columns.fill"
    )
    static let savingsMaximiser = AccountPreview.makeSample(
        seed: 3,
        name: "Savings Maximiser",
        institution: "ING",
        cents: 1_820_430,
        symbolName: "banknote.fill"
    )
    static let spending = AccountPreview.makeSample(
        seed: 4,
        name: "Spending",
        institution: "Up",
        cents: 32_618,
        symbolName: "arrow.up.circle.fill"
    )
    static let offset = AccountPreview.makeSample(
        seed: 5,
        name: "Offset",
        institution: "Macquarie",
        cents: 2_490_000,
        symbolName: "chart.line.uptrend.xyaxis"
    )
    static let platinumCard = AccountPreview.makeSample(
        seed: 6,
        name: "Platinum Card",
        institution: "American Express",
        cents: -128_476,
        symbolName: "creditcard.fill"
    )
    static let homeLoan = AccountPreview.makeSample(
        seed: 7,
        name: "Home Loan",
        institution: "Westpac",
        cents: -41_265_000,
        symbolName: "house.fill"
    )

    static let sample: [AccountPreview] = [
        .everydayAccess,
        .bills,
        .savingsMaximiser,
        .spending,
        .offset,
        .platinumCard,
        .homeLoan,
    ]

    private static func makeSample(
        seed: Int,
        name: String,
        institution: String,
        cents: Int,
        symbolName: String
    ) -> AccountPreview {
        AccountPreview(
            // Stable sample IDs keep a locally saved pay-cycle link valid across app
            // launches, and let sample transactions name the account they moved
            // through, until a backend supplies real account IDs.
            id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%012X", seed))!,
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
