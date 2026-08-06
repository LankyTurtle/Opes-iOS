import SwiftUI

struct ProfileToolbarContext {
    let isProfilePresented: Binding<Bool>
    let transitionID: AnyHashable
    let namespace: Namespace.ID
}

private struct ProfileToolbarContextKey: EnvironmentKey {
    static let defaultValue: ProfileToolbarContext? = nil
}

extension EnvironmentValues {
    var profileToolbarContext: ProfileToolbarContext? {
        get { self[ProfileToolbarContextKey.self] }
        set { self[ProfileToolbarContextKey.self] = newValue }
    }
}
