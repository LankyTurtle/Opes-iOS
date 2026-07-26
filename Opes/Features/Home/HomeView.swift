import SwiftUI

struct HomeView: View {
    private let accounts = SampleData.accounts
    private let budgets = SampleData.budgets
    private let transactions = SampleData.transactions

    private var totalBalance: Decimal {
        accounts.reduce(0) { $0 + $1.balance }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total balance")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(totalBalance.currencyText)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Across \(accounts.count) accounts")
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

                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Monthly budget")

                    ForEach(budgets) { budget in
                        BudgetRow(budget: budget)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Recent activity")

                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                        if transaction.id != transactions.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Good morning")
        .background(Color(uiColor: .systemGroupedBackground))
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

#Preview {
    NavigationStack { HomeView() }
}
