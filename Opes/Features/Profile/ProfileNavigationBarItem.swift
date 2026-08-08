import SwiftUI

extension NavigationBarItem {

    /// The profile button and the sheet it presents from the top toolbar.
    static var profile: NavigationBarItem {
        .zoomingSheet(
            NavigationBarZoomingSheet(
                id: "profile",
                systemImage: "person.crop.circle.fill",
                label: "Profile",
                content: {
                    AnyView(
                        NavigationStack {
                            ProfileView()
                        }
                    )
                }
            )
        )
    }
}
