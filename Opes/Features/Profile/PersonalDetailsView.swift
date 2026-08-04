import SwiftUI

struct PersonalDetailsView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@")
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Text(session.user.initials)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.opesPrimary, in: Circle())
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Your details") {
                TextField("Full name", text: $name)
                    .textContentType(.name)
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Text("Your name and email are only used to personalise this local prototype.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Personal details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    session.updateProfile(name: name, email: email)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            name = session.user.name
            email = session.user.email
        }
    }
}
