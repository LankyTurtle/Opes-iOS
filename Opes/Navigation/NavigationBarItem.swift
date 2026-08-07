import SwiftUI

/// Everything a screen wants in its navigation bar, declared in SwiftUI and
/// built in UIKit by `NavigationBarHost`.
struct NavigationBarConfiguration {
    let title: String
    let items: [NavigationBarItem]

    /// Everything about the bar that can change without the closures changing.
    /// The host rebuilds its items whenever this differs, which covers a title
    /// change, a toggle flipping and a menu's selection moving.
    var signature: String {
        ([title] + items.map(\.signature)).joined(separator: "|")
    }
}

/// A single item in the navigation bar, ordered leading to trailing.
enum NavigationBarItem: Identifiable {
    /// A button that runs an action when tapped.
    case button(NavigationBarButton)

    /// A button whose title flips between two states as it drives a flag.
    case toggle(NavigationBarToggle)

    /// A button that opens a menu of mutually exclusive options.
    case menu(NavigationBarMenu)

    /// A button that presents content, zooming out of the button itself.
    case zoomingSheet(NavigationBarZoomingSheet)

    var id: String {
        switch self {
        case .button(let button): button.id
        case .toggle(let toggle): toggle.id
        case .menu(let menu): menu.id
        case .zoomingSheet(let sheet): sheet.id
        }
    }

    var signature: String {
        switch self {
        case .button, .zoomingSheet: id
        case .toggle(let toggle): "\(id):\(toggle.isActive.wrappedValue)"
        case .menu(let menu): "\(id):\(menu.selection.wrappedValue)"
        }
    }
}

struct NavigationBarButton {
    let id: String
    let systemImage: String
    let label: String
    let action: () -> Void
}

struct NavigationBarToggle {
    let id: String
    let label: String
    let activeLabel: String
    let isActive: Binding<Bool>
}

struct NavigationBarMenu {
    let id: String
    let systemImage: String
    let label: String
    let options: [Option]
    let selection: Binding<String>

    struct Option: Identifiable {
        let id: String
        let title: String
        let systemImage: String
    }
}

struct NavigationBarZoomingSheet {
    let id: String
    let systemImage: String
    let label: String
    let content: () -> AnyView
}
