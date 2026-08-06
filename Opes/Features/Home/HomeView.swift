import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var dashboardStore: DashboardStore
    @State private var showingConfiguration = false

    var body: some View {
        List {
            if dashboardStore.visibleTiles.isEmpty {
                ContentUnavailableView {
                    Label("No dashboard tiles", systemImage: "rectangle.grid.1x2")
                } description: {
                    Text("Choose the information you want to see on your homepage.")
                } actions: {
                    Button("Choose tiles") {
                        showingConfiguration = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.opesPrimary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(dashboardStore.visibleTiles) { tile in
                    DashboardTileView(tile: tile)
                        .listRowInsets(
                            EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onMove(perform: dashboardStore.move)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .pageTitle("Home", displayMode: .inlineLarge)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingConfiguration = true
                } label: {
                    Label("Configure tiles", systemImage: "slider.horizontal.3")
                }

                if !dashboardStore.visibleTiles.isEmpty {
                    EditButton()
                }

            }
        }
        .scrollHidingNavigationHeader()
        .sheet(isPresented: $showingConfiguration) {
            DashboardConfigurationView()
        }
    }
}

private struct DashboardTileView: View {
    let tile: DashboardTile

    @ViewBuilder
    var body: some View {
        switch tile {
        case .totalBalance:
            TotalBalanceTile()
        case .monthlyBudget:
            MonthlyBudgetTile()
        case .recentActivity:
            RecentActivityTile()
        }
    }
}

private struct TotalBalanceTile: View {
    @EnvironmentObject private var accountStore: AccountStore

    private var totalBalance: Decimal {
        accountStore.accounts.reduce(0) { $0 + $1.availableBalance }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Total balance", systemImage: "dollarsign.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(totalBalance.currencyText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Across \(accountStore.accounts.count) accounts")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [.opesPrimary, .opesPrimary.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }
}

private struct MonthlyBudgetTile: View {
    private let budgets = SampleData.budgets

    var body: some View {
        DashboardTileContainer(title: "Monthly budget", icon: "chart.pie.fill") {
            ForEach(budgets) { budget in
                BudgetRow(budget: budget)
            }
        }
    }
}

private struct RecentActivityTile: View {
    private let transactions = SampleData.transactions

    var body: some View {
        DashboardTileContainer(title: "Recent activity", icon: "clock.fill") {
            ForEach(transactions) { transaction in
                TransactionRow(transaction: transaction)
                if transaction.id != transactions.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
    }
}

private struct DashboardTileContainer<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.title3.bold())
                .foregroundStyle(Color.opesPrimary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.opesSurface, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct BudgetRow: View {
    let budget: BudgetCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(budget.name, systemImage: budget.icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(budget.spent.currencyText) of \(budget.limit.currencyText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: budget.progress)
                .tint(budget.progress > 0.85 ? .orange : .opesPrimary)
        }
    }
}

private struct DashboardConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dashboardStore: DashboardStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DashboardTile.allCases) { tile in
                        Toggle(isOn: visibilityBinding(for: tile)) {
                            Label(tile.title, systemImage: tile.icon)
                        }
                    }
                } header: {
                    Text("Visible tiles")
                } footer: {
                    Text("Turn tiles on or off. Use Edit on the homepage to drag them into your preferred order.")
                }
            }
            .navigationTitle("Configure Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func visibilityBinding(for tile: DashboardTile) -> Binding<Bool> {
        Binding(
            get: { dashboardStore.isVisible(tile) },
            set: { dashboardStore.setVisible(tile, isVisible: $0) }
        )
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environmentObject(AccountStore())
        .environmentObject(DashboardStore(defaults: UserDefaults(suiteName: "HomePreview")!))
}
