import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.isAuthenticated)
    }
}

private struct MainTabView: View {
    @State private var selectedTab = AppTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.icon)
            }
            .tag(AppTab.home)

            NavigationStack {
                AccountsView()
            }
            .tabItem {
                Label(AppTab.accounts.title, systemImage: AppTab.accounts.icon)
            }
            .tag(AppTab.accounts)

            NavigationStack {
                TransactionsView()
            }
            .tabItem {
                Label(AppTab.transactions.title, systemImage: AppTab.transactions.icon)
            }
            .tag(AppTab.transactions)

            NavigationStack {
                BudgetsView()
            }
            .tabItem {
                Label(AppTab.budgets.title, systemImage: AppTab.budgets.icon)
            }
            .tag(AppTab.budgets)
        }
        .tint(.opesPrimary)
    }
}

private enum AppTab: Hashable {
    case home
    case accounts
    case transactions
    case budgets

    var title: String {
        switch self {
        case .home: "Home"
        case .accounts: "Accounts"
        case .transactions: "Transactions"
        case .budgets: "Budgets"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .accounts: "creditcard.fill"
        case .transactions: "arrow.left.arrow.right"
        case .budgets: "chart.pie.fill"
        }
    }
}
