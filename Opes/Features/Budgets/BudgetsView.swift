import SwiftUI

struct BudgetsView: View {
    private let budgets = SampleData.budgets

    private var totalSpent: Decimal {
        budgets.reduce(0) { $0 + $1.spent }
    }

    private var totalLimit: Decimal {
        budgets.reduce(0) { $0 + $1.limit }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spent this month")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(totalSpent.currencyText)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))

                    Text("of \(totalLimit.currencyText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressView(
                        value: decimalDouble(totalSpent),
                        total: decimalDouble(totalLimit)
                    )
                    .tint(.opesPrimary)
                }
                .padding(.vertical, 8)
            }

            Section {
                ForEach(budgets) { budget in
                    BudgetCategoryRow(budget: budget)
                }
            } header: {
                Text("Categories")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileNavigationButton()
            }
        }
        .scrollHidingNavigationHeader()
    }

    private func decimalDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

private struct BudgetCategoryRow: View {
    let budget: BudgetCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: budget.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.opesPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.opesPrimary.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(budget.name)
                        .font(.body.weight(.semibold))
                    Text("\(budget.spent.currencyText) of \(budget.limit.currencyText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(budget.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold))
            }

            ProgressView(value: budget.progress)
                .tint(budget.progress > 0.85 ? .orange : .opesPrimary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        BudgetsView()
    }
}
