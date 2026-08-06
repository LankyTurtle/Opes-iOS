import SwiftUI

extension View {

    /// Configures the view's title and toolbar display mode for navigation.
    func pageTitle(
        _ title: String,
        displayMode: ToolbarTitleDisplayMode = .inlineLarge
    ) -> some View {
        self
            .navigationTitle(title)
            .toolbarTitleDisplayMode(displayMode)
    }
}
