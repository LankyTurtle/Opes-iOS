import SwiftUI

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case accounts
    case transactions
    case budgets

    var id: Self {
        self
    }

    var title: String {
        self.rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .accounts:
            return "wallet.pass.fill"
        case .transactions:
            return "arrow.left.arrow.right"
        case .budgets:
            return "chart.pie.fill"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .home:
            HomeView()
        case .accounts:
            AccountsView()
        case .transactions:
            TransactionsView()
        case .budgets:
            BudgetsView()
        }
    }
}