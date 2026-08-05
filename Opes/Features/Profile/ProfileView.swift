import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @State private var showingSignOutConfirmation = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    PersonalDetailsView()
                } label: {
                    ProfileHeader(user: session.user)
                }
                .padding(.vertical, 8)
            } footer: {
                Text("Manage the details connected to your Opes account.")
            }

            Section {
                NavigationLink {
                    PersonalDetailsView()
                } label: {
                    Label("Personal details", systemImage: "person.text.rectangle")
                }

                NavigationLink {
                    NotificationsView()
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }

                NavigationLink {
                    SecurityView()
                } label: {
                    Label("Security", systemImage: "lock.shield")
                }
            } header: {
                Text("Account")
            }

            Section {
                NavigationLink {
                    HelpAndSupportView()
                } label: {
                    Label("Help and support", systemImage: "questionmark.circle")
                }
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About Opes", systemImage: "info.circle")
                }
            } header: {
                Text("Support")
            }

            Section {
                Button("Sign out", role: .destructive) {
                    showingSignOutConfirmation = true
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            Button(role: .close) {
                dismiss()
            }
        }
        .confirmationDialog("Sign out of Opes?", isPresented: $showingSignOutConfirmation) {
            Button("Sign out", role: .destructive) {
                session.signOut()
            }
        } message: {
            Text("You can sign back in at any time.")
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environmentObject(SessionStore())
}
