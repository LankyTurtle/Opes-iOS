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

    /// Pins the profile button to the trailing edge of the top toolbar.
    /// - Parameter
    ///     - isProfilePresented: A binding to a Boolean value that determines whether the profile sheet is presented.
    /// - Returns: A view with the profile button added to the toolbar.
    func addProfileButtonToToolbar(isProfilePresented: Binding<Bool>) -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileButton(isProfilePresented: isProfilePresented)
            }
        }
    }

    /// Pins the profile button to the specified placement in the toolbar.
    /// - Parameter
    ///     - isProfilePresented: A binding to a Boolean value that determines whether the profile sheet is presented.
    ///     - placement: The placement for the toolbar item.
    ///     - preButtonSpacer: An optional spacer to add before the profile button.
    ///     - postButtonSpacer: An optional spacer to add after the profile button.
    /// - Returns: A view with the profile button added to the toolbar.
    func addProfileButtonToToolbar(
        isProfilePresented: Binding<Bool>,
        placement: ToolbarItemPlacement,
        preButtonSpacer: SpacerSizing? = nil,
        postButtonSpacer: SpacerSizing? = nil
    ) -> some View {
        self.toolbar {
            if let preButtonSpacer {
                ToolbarSpacer(preButtonSpacer, placement: placement)
            }

            ToolbarItem(placement: placement) {
                ProfileButton(isProfilePresented: isProfilePresented)
            }

            if let postButtonSpacer {
                ToolbarSpacer(postButtonSpacer, placement: placement)
            }
        }
    }

    func profileToolbar<Content: ToolbarContent>(
        isProfilePresented: Binding<Bool>,
        placement: ToolbarItemPlacement = .topBarTrailing,
        preButtonSpacer: SpacerSizing? = nil,
        postButtonSpacer: SpacerSizing? = nil,
        @ToolbarContentBuilder content: () -> Content
    ) -> some View {
        self.toolbar {
            content()

            if let preButtonSpacer {
                ToolbarSpacer(preButtonSpacer, placement: placement)
            }

            ToolbarItem(placement: placement) {
                ProfileButton(isProfilePresented: isProfilePresented)
            }

            if let postButtonSpacer {
                ToolbarSpacer(postButtonSpacer, placement: placement)
            }
        }
    }
}
