import SwiftUI

/// Coordinates the app's primary tab navigation and presents each feature's root view.
struct PrimaryNavigationView: View {
    @State private var selectedTab = PrimaryTab.home
    @State private var isProfilePresented = false
    @Namespace private var profileTransition

    var body: some View {
        TabView(selection: $selectedTab) {
            createTabNavigationStack(title: PrimaryTab.home.title, image: PrimaryTab.home.icon, tag: PrimaryTab.home)
                {
                    ProfileToolbarContainer(
                        isProfilePresented: $isProfilePresented,
                        profileTransition: profileTransition
                    ) {
                        HomeView()
                    }
                }

            createTabNavigationStack( title: PrimaryTab.accounts.title, image: PrimaryTab.accounts.icon, tag: PrimaryTab.accounts)
                {
                    ProfileToolbarContainer(
                        isProfilePresented: $isProfilePresented,
                        profileTransition: profileTransition
                    ) {
                        AccountsView()
                    }
                }

            createTabNavigationStack(title: PrimaryTab.transactions.title, image: PrimaryTab.transactions.icon, tag: PrimaryTab.transactions)
                {
                    ProfileToolbarContainer(
                        isProfilePresented: $isProfilePresented,
                        profileTransition: profileTransition
                    ) {
                        TransactionsView()
                    }
                }

            createTabNavigationStack(title: PrimaryTab.budgets.title, image: PrimaryTab.budgets.icon, tag: PrimaryTab.budgets)
                {
                    ProfileToolbarContainer(
                        isProfilePresented: $isProfilePresented,
                        profileTransition: profileTransition
                    ) {
                        BudgetsView()
                    }
                }
        }
        .tint(.opesPrimary)
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
