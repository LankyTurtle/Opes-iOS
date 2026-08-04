import SwiftUI

struct HelpAndSupportView: View {
    @State private var showingContactSheet = false

    var body: some View {
        List {
            Section {
                HelpTopicRow(title: "Getting started", detail: "Set up your accounts and dashboard.", icon: "play.circle")
                HelpTopicRow(title: "Managing budgets", detail: "Keep your monthly spending on track.", icon: "chart.pie")
                HelpTopicRow(title: "Keeping your account secure", detail: "Protect your financial information.", icon: "lock.shield")
            } header: {
                Text("Popular help")
            }

            Section {
                Button {
                    showingContactSheet = true
                } label: {
                    Label("Contact support", systemImage: "envelope")
                }
            } footer: {
                Text("Our local prototype support team usually responds within one business day.")
            }
        }
        .navigationTitle("Help and support")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingContactSheet) {
            ContactSupportView()
        }
    }
}
