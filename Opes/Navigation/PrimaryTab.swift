/// Identifies each destination available from the app's primary tab navigation.
enum PrimaryTab: Hashable {
    case home
    case accounts
    case transactions
    case budgets

    /// The text displayed for this tab in the system tab bar.
    var title: String {
        switch self {
        case .home: "Home"
        case .accounts: "Accounts"
        case .transactions: "Transactions"
        case .budgets: "Budgets"
        }
    }

    /// The SF Symbol name displayed for this tab in the system tab bar.
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .accounts: "wallet.bifold.fill"
        case .transactions: "arrow.left.arrow.right"
        case .budgets: "chart.pie.fill"
        }
    }
}
