import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @State private var showingPayment = false
    @State private var editorContext: AccountEditorContext?
    @State private var accountPendingRemoval: FinancialAccount?
    @State private var showingRemovalConfirmation = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if accountStore.accounts.isEmpty {
                    ContentUnavailableView {
                        Label("No accounts", systemImage: "creditcard")
                    } description: {
                        Text("Add an account to start tracking your balance.")
                    } actions: {
                        Button("Add account") {
                            editorContext = .add
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.opesPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(accountStore.accounts) { account in
                        AccountCard(
                            account: account,
                            onEdit: { editorContext = .edit(account) },
                            onRemove: { requestRemoval(of: account) }
                        )
                    }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorContext = .add
                } label: {
                    Label("Add account", systemImage: "plus")
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showingPayment) {
            PaymentView()
        }
        .sheet(item: $editorContext) { context in
            AccountEditorView(account: context.account) { account in
                if context.account == nil {
                    accountStore.add(account)
                } else {
                    accountStore.update(account)
                }
            }
        }
        .alert(
            "Remove account?",
            isPresented: $showingRemovalConfirmation,
            presenting: accountPendingRemoval
        ) { account in
            Button("Remove", role: .destructive) {
                accountStore.remove(account)
                accountPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                accountPendingRemoval = nil
            }
        } message: { account in
            Text("\(account.name) will be removed from Opes.")
        }
    }

    private func requestRemoval(of account: FinancialAccount) {
        accountPendingRemoval = account
        showingRemovalConfirmation = true
    }
}

private struct AccountCard: View {
    let account: FinancialAccount
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label(account.name, systemImage: account.kind.icon)
                    .font(.headline)
                Spacer()
                Menu {
                    Button(action: onEdit) {
                        Label("Edit account", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove account", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
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

private struct AccountEditorContext: Identifiable {
    let id = UUID()
    let account: FinancialAccount?

    static var add: Self {
        AccountEditorContext(account: nil)
    }

    static func edit(_ account: FinancialAccount) -> Self {
        AccountEditorContext(account: account)
    }
}

private struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var lastFourDigits: String
    @State private var balance: String
    @State private var kind: FinancialAccount.Kind

    private let account: FinancialAccount?
    private let onSave: (FinancialAccount) -> Void

    init(
        account: FinancialAccount?,
        onSave: @escaping (FinancialAccount) -> Void
    ) {
        self.account = account
        self.onSave = onSave
        _name = State(initialValue: account?.name ?? "")
        _lastFourDigits = State(initialValue: account.map {
            String($0.maskedNumber.suffix(4))
        } ?? "")
        _balance = State(initialValue: account.map {
            NSDecimalNumber(decimal: $0.balance).stringValue
        } ?? "")
        _kind = State(initialValue: account?.kind ?? .everyday)
    }

    private var parsedBalance: Decimal? {
        Decimal(string: balance)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && lastFourDigits.count == 4
            && lastFourDigits.allSatisfy(\.isNumber)
            && parsedBalance != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account details") {
                    TextField("Account name", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("Account type", selection: $kind) {
                        ForEach(FinancialAccount.Kind.allCases) { kind in
                            Label(kind.title, systemImage: kind.icon)
                                .tag(kind)
                        }
                    }

                    TextField("Last 4 digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFourDigits) { _, newValue in
                            lastFourDigits = String(newValue.filter(\.isNumber).prefix(4))
                        }

                    TextField("Current balance", text: $balance)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Text("Account changes are kept locally for the current session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(account == nil ? "Add account" : "Edit account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let parsedBalance else { return }

        let updatedAccount = FinancialAccount(
            id: account?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            maskedNumber: "•••• \(lastFourDigits)",
            balance: parsedBalance,
            kind: kind
        )
        onSave(updatedAccount)
        dismiss()
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
        .environmentObject(AccountStore())
}
