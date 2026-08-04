import SwiftUI

/// Coordinates the app's primary tab navigation and presents each feature's root view.
struct PrimaryNavigationView: View {
    @State private var selectedTab = PrimaryTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            createTabNavigationStack(title: PrimaryTab.home.title, image: PrimaryTab.home.icon, tag: PrimaryTab.home)
                { HomeView() }

            createTabNavigationStack( title: PrimaryTab.accounts.title, image: PrimaryTab.accounts.icon, tag: PrimaryTab.accounts)
                { AccountsView() }

            createTabNavigationStack(title: PrimaryTab.transactions.title, image: PrimaryTab.transactions.icon, tag: PrimaryTab.transactions)
                { TransactionsView() }

            createTabNavigationStack(title: PrimaryTab.budgets.title, image: PrimaryTab.budgets.icon, tag: PrimaryTab.budgets)
                { BudgetsView() }
        }
        .tint(.opesPrimary)
    }
}
