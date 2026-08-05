import SwiftUI

private enum AppTransition {
    static let profile = "profile"
}

/// Coordinates the app's primary tab navigation and presents each feature's root view.
struct PrimaryNavigationView: View {
    @State private var selectedTab = PrimaryTab.home
    @State private var isProfilePresented = false
    @Namespace private var profileTransition

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isProfilePresented = true
                } label: {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .accessibilityHint("View your profile and settings")
                .matchedTransitionSource(
                    id: AppTransition.profile,
                    in: profileTransition
                )
            }
        }
        .sheet(isPresented: $isProfilePresented) {
            NavigationStack {
                ProfileView()
                    .navigationTransition(
                        .zoom(
                            sourceID: AppTransition.profile,
                            in: profileTransition
                        )
                    )
            }
            .presentationDetents([.large])
        }
    }
}
