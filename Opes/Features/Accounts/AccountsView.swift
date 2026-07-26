import SwiftUI

struct AccountsView: View {
    @State private var showingPayment = false
    private let accounts = SampleData.accounts

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(accounts) { account in
                    AccountCard(account: account)
                }

                Button {
                    showingPayment = true
                } label: {
                    Label("Make a payment", systemImage: "arrow.up.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.opesPrimary)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Recent transactions")
                    ForEach(SampleData.transactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Accounts")
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showingPayment) {
            PaymentView()
        }
    }
}

private struct AccountCard: View {
    let account: FinancialAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label(account.name, systemImage: account.kind.icon)
                    .font(.headline)
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(account.balance.currencyText)
                    .font(.title.bold())
                Text(account.maskedNumber)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color.opesSurface, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recipient = ""
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment details") {
                    TextField("Recipient", text: $recipient)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Text("Payments are not submitted in this prototype.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Review") { dismiss() }
                        .disabled(recipient.isEmpty || amount.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { AccountsView() }
}
