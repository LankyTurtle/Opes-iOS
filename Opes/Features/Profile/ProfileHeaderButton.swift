import SwiftUI

/// The profile button, which presents the profile sheet by zooming out of the
/// button itself.
///
/// Now that the button is a SwiftUI view in the page header rather than a bar
/// button item, the zoom is expressed in SwiftUI too: a bar button item could
/// not be a matched transition source, which was the only reason the
/// presentation ever needed to be performed by UIKit.
struct ProfileHeaderButton: View {
    @State private var isProfilePresented = false
    @Namespace private var profileTransition

    var body: some View {
        Button {
            isProfilePresented = true
        } label: {
            Label("Profile", systemImage: "person.crop.circle.fill")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityHint("View your profile and settings")
        .matchedTransitionSource(id: "profile", in: profileTransition)
        .sheet(isPresented: $isProfilePresented) {
            NavigationStack {
                ProfileView()
            }
            .navigationTransition(
                .zoom(sourceID: "profile", in: profileTransition)
            )
            .presentationDetents([.large])
        }
    }
}
