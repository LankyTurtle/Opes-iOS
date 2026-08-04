import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.opesPrimary)
                    Text("Opes")
                        .font(.title2.bold())
                    Text("A clearer view of your money.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowBackground(Color.clear)
            }

            Section("App") {
                LabeledContent("Version", value: appVersion)
                LabeledContent(
                    "Build",
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
                )
            }

            Section("Privacy") {
                Text("Opes uses local sample data in this prototype. No financial information is sent from the app.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About Opes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
