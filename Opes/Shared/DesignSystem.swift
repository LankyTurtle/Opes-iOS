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

enum AppTransition {
    static let profile = "profile"
}

struct ProfilePresentationButton: View {
    @Namespace private var profileTransition
    @State private var isProfilePresented = false

    var body: some View {
        Button {
            isProfilePresented = true
        } label: {
            Label("Profile", systemImage: "person.crop.circle.fill")
        }
        .accessibilityHint("View your profile and settings")
        .matchedTransitionSource(id: AppTransition.profile, in: profileTransition)
        .sheet(isPresented: $isProfilePresented) {
            NavigationStack {
                ProfileView()
                    .navigationTransition(
                        .zoom(sourceID: AppTransition.profile, in: profileTransition)
                    )
            }
            .presentationDetents([.large])
        }
    }
}

private struct ScrollHidingNavigationHeader: ViewModifier {
    @State private var isHeaderHidden = false

    func body(content: Content) -> some View {
        content
            .toolbar(isHeaderHidden ? .hidden : .visible, for: .navigationBar)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldOffset, newOffset in
                guard abs(newOffset - oldOffset) > 8 else { return }

                if newOffset <= 0 {
                    isHeaderHidden = false
                } else {
                    isHeaderHidden = newOffset > oldOffset
                }
            }
    }
}

extension View {
    /// Hides the navigation header while scrolling down and reveals it while scrolling up.
    func scrollHidingNavigationHeader() -> some View {
        modifier(ScrollHidingNavigationHeader())
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
