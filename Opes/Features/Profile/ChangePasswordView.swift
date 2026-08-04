import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var didUpdatePassword = false

    private var canUpdate: Bool {
        currentPassword.count >= 6 && newPassword.count >= 6 && newPassword == confirmation
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Password") {
                    SecureField("Current password", text: $currentPassword)
                    SecureField("New password", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("Confirm new password", text: $confirmation)
                        .textContentType(.newPassword)
                }
                if didUpdatePassword {
                    Section {
                        Label("Password updated for this session.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.opesPrimary)
                    }
                }
            }
            .navigationTitle("Change password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") { didUpdatePassword = true }
                        .disabled(!canUpdate)
                }
            }
        }
    }
}
