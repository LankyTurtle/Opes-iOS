import SwiftUI

/// Coordinates the app's primary tab navigation and presents each feature's root view.
struct PrimaryNavigationView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var dashboardStore: DashboardStore

    @State private var selectedTab = PrimaryTab.home

    private var navigationEnvironment: NavigationEnvironment {
        NavigationEnvironment(
            session: session,
            accountStore: accountStore,
            dashboardStore: dashboardStore
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            tab(.home) { HomeView() }
            tab(.accounts) { AccountsView() }
            tab(.transactions) { TransactionsView() }
            tab(.budgets) { BudgetsView() }
        }
        .tint(.opesPrimary)
    }

    private func tab<Content: View>(
        _ tab: PrimaryTab,
        @ViewBuilder content: @escaping () -> Content
    ) -> some TabContent<PrimaryTab> {
        createTabNavigationStack(
            title: tab.title,
            image: tab.icon,
            tag: tab,
            environment: navigationEnvironment,
            content: content
        )
    }
}
