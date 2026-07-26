import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var notificationsEnabled = true

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Text(session.user.initials)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.opesPrimary, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.user.name)
                            .font(.headline)
                        Text(session.user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Preferences") {
                NavigationLink {
                    PlaceholderDetailView(title: "Personal details")
                } label: {
                    Label("Personal details", systemImage: "person.text.rectangle")
                }

                Toggle(isOn: $notificationsEnabled) {
                    Label("Notifications", systemImage: "bell")
                }

                NavigationLink {
                    PlaceholderDetailView(title: "Security")
                } label: {
                    Label("Security", systemImage: "lock.shield")
                }
            }

            Section("Support") {
                NavigationLink {
                    PlaceholderDetailView(title: "Help and support")
                } label: {
                    Label("Help and support", systemImage: "questionmark.circle")
                }
                HStack {
                    Label("App version", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Sign out", role: .destructive) {
                    session.signOut()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Profile")
    }
}

private struct PlaceholderDetailView: View {
    let title: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "hammer",
            description: Text("This section is ready for a future iteration.")
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environmentObject(SessionStore())
}
