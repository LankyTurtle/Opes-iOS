import SwiftUI

extension Color {
    static let opesPrimary = Color(red: 0.12, green: 0.38, blue: 0.32)
    static let opesSurface = Color(uiColor: .secondarySystemBackground)
}

extension Decimal {
    var currencyText: String {
        formatted(.currency(code: Locale.current.currency?.identifier ?? "AUD"))
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.opesPrimary)
                .frame(width: 40, height: 40)
                .background(Color.opesPrimary.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant)
                    .font(.body.weight(.semibold))
                Text(transaction.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(transaction.amount.currencyText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(transaction.amount >= 0 ? Color.opesPrimary : .primary)
        }
        .padding(.vertical, 4)
    }
}
