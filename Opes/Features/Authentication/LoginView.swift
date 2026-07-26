import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private var canSignIn: Bool {
        email.contains("@") && password.count >= 6
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Spacer(minLength: 36)

                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(Color.opesPrimary)

                        Text("Welcome to Opes")
                            .font(.largeTitle.bold())
                        Text("A clearer view of your money.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 16) {
                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(signIn)
                    }
                    .textFieldStyle(.roundedBorder)

                    Button(action: signIn) {
                        Text("Sign in")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.opesPrimary)
                    .disabled(!canSignIn)

                    Text("For this prototype, use any email address and a password with at least six characters.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func signIn() {
        guard canSignIn else { return }
        focusedField = nil
        session.signIn(email: email, password: password)
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionStore())
}
