import SwiftUI

/// Coordinates the app's primary tab navigation and presents each feature's root view.
struct PrimaryNavigationView: View {
    @State private var selectedTab = PrimaryTab.home
    @State private var isProfilePresented = false
    @Namespace private var profileTransition

    var body: some View {
        TabView(selection: $selectedTab) {
            profileTab(.home) { HomeView() }
            profileTab(.accounts) { AccountsView() }
            profileTab(.transactions) { TransactionsView() }
            profileTab(.budgets) { BudgetsView() }
        }
        .tint(.opesPrimary)
        .sheet(isPresented: $isProfilePresented) {
            NavigationStack {
                ProfileView()
            }
            .navigationTransition(
                .zoom(
                    sourceID: selectedTab,
                    in: profileTransition
                )
            )
            .presentationDetents([.large])
        }
    }

    private func profileTab<Content: View>(
        _ tab: PrimaryTab,
        @ViewBuilder content: @escaping () -> Content
    ) -> some TabContent<PrimaryTab> {
        createTabNavigationStack(title: tab.title, image: tab.icon, tag: tab) {
            content()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProfileToolbarButton(isProfilePresented: $isProfilePresented)
                            .matchedTransitionSource(id: tab, in: profileTransition)
                    }
                }
            }
    }
}
