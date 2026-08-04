import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var isAuthenticated = true
    @Published private(set) var user = UserProfile.sample

    func signIn(email: String, password: String) {
        user = UserProfile(
            name: "Alex Morgan",
            email: email,
            initials: "AM"
        )
        isAuthenticated = true
    }

    func updateProfile(name: String, email: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        user = UserProfile(
            name: trimmedName,
            email: trimmedEmail,
            initials: Self.initials(for: trimmedName)
        )
    }

    func signOut() {
        isAuthenticated = false
    }

    private static func initials(for name: String) -> String {
        let components = name.split(whereSeparator: { $0.isWhitespace })
        let initials = components.prefix(2).compactMap(\.first)
        return initials.isEmpty ? "OP" : String(initials).uppercased()
    }
}
