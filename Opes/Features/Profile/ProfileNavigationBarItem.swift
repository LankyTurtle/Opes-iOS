import SwiftUI

extension NavigationBarItem {

    /// The profile button, which presents the profile sheet by zooming out of
    /// the button itself.
    ///
    /// The sheet's content is left undressed: the navigation host puts the
    /// app's stores back on it as it crosses into UIKit.
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
