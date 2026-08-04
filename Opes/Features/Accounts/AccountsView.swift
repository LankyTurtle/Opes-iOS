import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @AppStorage("accounts.sortOption") private var sortOptionRawValue =
        AccountSortOption.displayName.rawValue
    @State private var editorContext: AccountEditorContext?
    @State private var accountPendingRemoval: FinancialAccount?
    @State private var showingRemovalConfirmation = false

    private var sortedAccounts: [FinancialAccount] {
        accountStore.accounts.sorted(by: sortOption.areInIncreasingOrder)
    }

    private var sortOption: AccountSortOption {
        AccountSortOption(rawValue: sortOptionRawValue) ?? .displayName
    }

    var body: some View {
        List {
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
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(sortedAccounts) { account in
                        NavigationLink {
                            AccountView(account: account)
                        } label: {
                            AccountTile(account: account)
                        }
                        .listRowInsets(
                            EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 12)
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                requestRemoval(of: account)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }

                            Button {
                                editorContext = .edit(account)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.opesPrimary)
                        }
                    }
                } footer: {
                    Text("Sorted by \(sortOption.title.lowercased()).")
                }

            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort accounts", selection: $sortOptionRawValue) {
                        ForEach(AccountSortOption.allCases) { option in
                            Label(option.title, systemImage: option.icon)
                                .tag(option.rawValue)
                        }
                    }
                } label: {
                    Label("Sort accounts", systemImage: "arrow.up.arrow.down")
                }

                Button {
                    editorContext = .add
                } label: {
                    Label("Add account", systemImage: "plus")
                }

                ProfileNavigationButton()
            }
        }
        .scrollHidingNavigationHeader()
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
            Text("\(account.displayName) will be removed from Opes.")
        }
    }

    private func requestRemoval(of account: FinancialAccount) {
        accountPendingRemoval = account
        showingRemovalConfirmation = true
    }
}

private enum AccountSortOption: String, CaseIterable, Hashable, Identifiable {
    case displayName
    case institution
    case accountType
    case balanceHighToLow
    case balanceLowToHigh

    var id: Self { self }

    var title: String {
        switch self {
        case .displayName: "Display name (A–Z)"
        case .institution: "Institution (A–Z)"
        case .accountType: "Account type (A–Z)"
        case .balanceHighToLow: "Balance (high to low)"
        case .balanceLowToHigh: "Balance (low to high)"
        }
    }

    var icon: String {
        switch self {
        case .displayName, .institution, .accountType: "textformat.abc"
        case .balanceHighToLow: "arrow.down"
        case .balanceLowToHigh: "arrow.up"
        }
    }

    func areInIncreasingOrder(
        _ lhs: FinancialAccount,
        _ rhs: FinancialAccount
    ) -> Bool {
        switch self {
        case .displayName:
            alphabetical(lhs.displayName, rhs.displayName)
        case .institution:
            alphabetical(
                lhs.institutionName,
                rhs.institutionName,
                fallbackLeft: lhs.displayName,
                fallbackRight: rhs.displayName
            )
        case .accountType:
            alphabetical(
                lhs.kind.title,
                rhs.kind.title,
                fallbackLeft: lhs.displayName,
                fallbackRight: rhs.displayName
            )
        case .balanceHighToLow:
            lhs.availableBalance == rhs.availableBalance
                ? alphabetical(lhs.displayName, rhs.displayName)
                : lhs.availableBalance > rhs.availableBalance
        case .balanceLowToHigh:
            lhs.availableBalance == rhs.availableBalance
                ? alphabetical(lhs.displayName, rhs.displayName)
                : lhs.availableBalance < rhs.availableBalance
        }
    }

    private func alphabetical(
        _ lhs: String,
        _ rhs: String,
        fallbackLeft: String? = nil,
        fallbackRight: String? = nil
    ) -> Bool {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        if comparison == .orderedSame,
           let fallbackLeft,
           let fallbackRight {
            return fallbackLeft.localizedCaseInsensitiveCompare(fallbackRight) == .orderedAscending
        }
        return comparison == .orderedAscending
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
    @State private var displayName: String
    @State private var institutionName: String
    @State private var institutionIcon: String
    @State private var lastFourDigits: String
    @State private var availableBalance: String
    @State private var kind: FinancialAccount.Kind

    private let account: FinancialAccount?
    private let onSave: (FinancialAccount) -> Void
    private let institutionIcons = [
        InstitutionIconOption(title: "Bank", icon: "building.columns.fill"),
        InstitutionIconOption(title: "Digital bank", icon: "building.columns.circle.fill"),
        InstitutionIconOption(title: "Credit union", icon: "person.2.fill"),
        InstitutionIconOption(title: "Wallet", icon: "wallet.bifold.fill")
    ]

    init(
        account: FinancialAccount?,
        onSave: @escaping (FinancialAccount) -> Void
    ) {
        self.account = account
        self.onSave = onSave
        _displayName = State(initialValue: account?.displayName ?? "")
        _institutionName = State(initialValue: account?.institutionName ?? "")
        _institutionIcon = State(
            initialValue: account?.institutionIcon ?? "building.columns.fill"
        )
        _lastFourDigits = State(initialValue: account.map {
            String($0.maskedNumber.suffix(4))
        } ?? "")
        _availableBalance = State(initialValue: account.map {
            NSDecimalNumber(decimal: $0.availableBalance).stringValue
        } ?? "")
        _kind = State(initialValue: account?.kind ?? .everyday)
    }

    private var parsedBalance: Decimal? {
        Decimal(string: availableBalance)
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && lastFourDigits.count == 4
            && lastFourDigits.allSatisfy(\.isNumber)
            && parsedBalance != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account details") {
                    TextField("Display name", text: $displayName)
                        .textInputAutocapitalization(.words)

                    TextField("Institution name", text: $institutionName)
                        .textInputAutocapitalization(.words)

                    Picker("Institution icon", selection: $institutionIcon) {
                        ForEach(institutionIcons) { option in
                            Label(option.title, systemImage: option.icon)
                                .tag(option.icon)
                        }
                    }

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

                    TextField("Available balance", text: $availableBalance)
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
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionName: institutionName.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionIcon: institutionIcon,
            maskedNumber: "•••• \(lastFourDigits)",
            availableBalance: parsedBalance,
            kind: kind
        )
        onSave(updatedAccount)
        dismiss()
    }
}

private struct InstitutionIconOption: Identifiable {
    let title: String
    let icon: String

    var id: String { icon }
}

#Preview {
    NavigationStack { AccountsView() }
        .environmentObject(AccountStore())
}
