import SwiftUI

/// Presents the user's profile from a primary navigation toolbar.
struct ProfileToolbarButton: View {
    @Binding private var isProfilePresented: Bool

    init(isProfilePresented: Binding<Bool>) {
        _isProfilePresented = isProfilePresented
    }

    var body: some View {
        Button {
            isProfilePresented = true
        } label: {
            Label(
                "Profile",
                systemImage: "person.crop.circle.fill"
            )
        }
        .accessibilityHint("View your profile and settings")
    }
}
