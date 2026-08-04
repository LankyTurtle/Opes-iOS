import SwiftUI

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                } header: {
                    Text("How can we help?")
                }
                if didSend {
                    Section {
                        Label("Your message has been sent.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.opesPrimary)
                    }
                }
            }
            .navigationTitle("Contact support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { didSend = true }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
