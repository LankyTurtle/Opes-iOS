import SwiftUI

struct TransactionsView: View {
    private let transactions = SampleData.transactions

    var body: some View {
        List {
            PageHeaderRow(title: "Transactions", horizontalInset: 20)

            Section {
                ForEach(transactions) { transaction in
                    TransactionRow(transaction: transaction)
                        .listRowInsets(
                            EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
                        )
                }
            } header: {
                Text("Recent activity")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBackTitle("Transactions")
    }
}

#Preview {
    NavigationStack {
        TransactionsView()
    }
}
