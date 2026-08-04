import SwiftUI

struct SecurityView: View {
    @AppStorage("profile.security.faceID") private var biometricUnlock = true
    @AppStorage("profile.security.twoFactor") private var twoFactorAuthentication = false
    @State private var showingPasswordSheet = false

    var body: some View {
        Form {
            Section {
                Toggle("Face ID", isOn: $biometricUnlock)
                Toggle("Two-factor authentication", isOn: $twoFactorAuthentication)
            } header: {
                Text("Sign in")
            } footer: {
                Text("Two-factor authentication adds an extra verification step when you sign in on a new device.")
            }

            Section {
                Button("Change password") {
                    showingPasswordSheet = true
                }
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPasswordSheet) {
            ChangePasswordView()
        }
    }
}
