import SwiftUI

struct TransactionsView: View {
    private let transactions = SampleData.transactions

    var body: some View {
        List {
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
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfilePresentationButton()
            }
        }
        .scrollHidingNavigationHeader()
    }
}

#Preview {
    NavigationStack {
        TransactionsView()
    }
}
