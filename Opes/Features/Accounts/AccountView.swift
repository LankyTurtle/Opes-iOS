import SwiftUI

struct AccountView: View {
    let account: FinancialAccount

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AccountTile(account: account)

                VStack(spacing: 0) {
                    AccountDetailRow(
                        label: "Institution",
                        value: account.institutionName,
                        icon: account.institutionIcon
                    )
                    Divider().padding(.leading, 48)
                    AccountDetailRow(
                        label: "Account type",
                        value: account.kind.title,
                        icon: account.kind.icon
                    )
                    Divider().padding(.leading, 48)
                    AccountDetailRow(
                        label: "Account number",
                        value: account.maskedNumber,
                        icon: "number"
                    )
                    Divider().padding(.leading, 48)
                    AccountDetailRow(
                        label: "Available balance",
                        value: account.availableBalance.currencyText,
                        icon: "dollarsign.circle"
                    )
                }
                .padding(.horizontal, 16)
                .background(Color.opesSurface, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(account.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AccountDetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.opesPrimary)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 16)
    }
}

#Preview {
    NavigationStack {
        AccountView(account: SampleData.accounts[0])
    }
}
