import SwiftUI

extension View {

    /// Configures the view's title for the purposes of navigation.
    /// - Parameters:
    ///   - title: The title to display in the navigation bar.
    /// - Returns: A view with the specified navigation title.
    func setViewTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
    }

    /// Configures the view's navigation for the purposes of navigation.
    /// - Parameters:
    ///   - title: The title to display in the navigation bar.
    ///   - displayMode: The display mode for the navigation bar title.
    /// - Returns: A view configured with the specified navigation title and display mode.
    func setViewTitle(_ title: String, displayMode: ToolbarTitleDisplayMode) -> some View {
        self
            .navigationTitle(title)
            .toolbarTitleDisplayMode(displayMode)
    }
}