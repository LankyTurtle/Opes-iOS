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

    func signOut() {
        isAuthenticated = false
    }
}
