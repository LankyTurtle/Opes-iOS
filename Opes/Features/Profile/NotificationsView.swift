import SwiftUI

struct NotificationsView: View {
    @AppStorage("profile.notifications.transactions") private var transactionAlerts = true
    @AppStorage("profile.notifications.budgets") private var budgetAlerts = true
    @AppStorage("profile.notifications.insights") private var weeklyInsights = false

    var body: some View {
        Form {
            Section {
                Toggle("Transaction alerts", isOn: $transactionAlerts)
                Toggle("Budget updates", isOn: $budgetAlerts)
                Toggle("Weekly insights", isOn: $weeklyInsights)
            } footer: {
                Text("Choose which updates Opes can send. System notification permissions are managed in Settings.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}
