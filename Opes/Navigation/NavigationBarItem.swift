import SwiftUI

/// The title and actions displayed in a tab root's top toolbar.
struct NavigationBarConfiguration {
    let title: String
    let items: [NavigationBarItem]

    var signature: String {
        ([title] + items.map(\.id)).joined(separator: "|")
    }
}

/// An action displayed in a tab root's top toolbar.
enum NavigationBarItem: Identifiable {
    case button(NavigationBarButton)
    case zoomingSheet(NavigationBarZoomingSheet)

    var id: String {
        switch self {
        case .button(let button): button.id
        case .zoomingSheet(let sheet): sheet.id
        }
    }
}

struct NavigationBarButton {
    let id: String
    let systemImage: String
    let label: String
    let action: () -> Void
}

struct NavigationBarZoomingSheet {
    let id: String
    let systemImage: String
    let label: String
    let content: () -> AnyView
}
