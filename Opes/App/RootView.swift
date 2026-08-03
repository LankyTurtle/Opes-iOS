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
            .tag(AppTab.home)

            NavigationStack {
                AccountsView()
            }
            .tag(AppTab.accounts)

            NavigationStack {
                ProfileView()
            }
            .tag(AppTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LiquidGlassTabBar(selection: $selectedTab)
        }
        .tint(.opesPrimary)
    }
}

private enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case accounts
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .accounts: "Accounts"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .accounts: "creditcard.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

private struct LiquidGlassTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var selectionAnimation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selection == tab {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Capsule()
                                            .stroke(.white.opacity(0.55), lineWidth: 0.75)
                                    }
                                    .shadow(
                                        color: Color.opesPrimary.opacity(0.18),
                                        radius: 8,
                                        y: 3
                                    )
                                    .matchedGeometryEffect(
                                        id: "selectedTab",
                                        in: selectionAnimation
                                    )
                            }

                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .symbolEffect(.bounce, value: selection == tab)
                        }
                        .frame(width: 52, height: 32)

                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selection == tab ? Color.opesPrimary : .secondary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(0.4), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}
