import SwiftUI

@main
struct OpesApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var accountStore = AccountStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(accountStore)
        }
    }
}
