import SwiftUI

/// View that presents a button to open the profile sheet.
struct ProfileButton: View {
    @Binding private var isProfilePresented: Bool

    init(isProfilePresented: Binding<Bool>) {
        _isProfilePresented = isProfilePresented
    }

    var body: some View {
        Button {
            isProfilePresented = true
        }
        label: {
            Label(
                "Profile",
                systemImage: "person.crop.circle.fill"
            )
        }
        .accessibilityHint("View your profile and settings")
    }
}

extension View {

    /// Adds the profile button as an independent trailing toolbar item.
    func addProfileButtonToToolbar(isProfilePresented: Binding<Bool>) -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileButton(isProfilePresented: isProfilePresented)
            }
        }
    }
}
