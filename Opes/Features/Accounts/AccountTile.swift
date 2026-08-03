import SwiftUI

struct AccountTile: View {
    let account: FinancialAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: account.institutionIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.opesPrimary)
                    .frame(width: 48, height: 48)
                    .background(Color.opesPrimary.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(account.institutionName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(account.availableBalance.currencyText)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }

            HStack {
                Label(account.kind.title, systemImage: account.kind.icon)
                Spacer()
                Text(account.maskedNumber)
                    .monospaced()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.opesSurface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AccountTile(account: SampleData.accounts[0])
        .padding()
}
