import SwiftUI
import UIKit

/// A navigation stack backed by `UINavigationController`, so that the bar, the
/// items in it, its Liquid Glass treatment and its hide-on-swipe behaviour are
/// all built and animated by UIKit rather than described to SwiftUI.
struct UIKitNavigationStack<Root: View>: UIViewControllerRepresentable {
    let environment: NavigationEnvironment
    @ViewBuilder let root: () -> Root

    func makeUIViewController(context: Context) -> UINavigationController {
        let host = NavigationBarHost(environment: environment)

        let rootController = UIHostingController(
            rootView: environment
                .decorate(root())
                .environment(\.navigationBarHost, host)
        )

        // Content stops at the bar rather than running beneath it, so that
        // scrolling pushes the bar up and out of the way instead of sliding
        // the view under a bar it stays visible through.
        rootController.edgesForExtendedLayout = []

        let navigationController = UINavigationController(
            rootViewController: rootController
        )
        host.attach(to: navigationController, rootItem: rootController.navigationItem)

        context.coordinator.host = host

        return navigationController
    }

    func updateUIViewController(
        _ controller: UINavigationController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Holds the host for as long as the stack is on screen. Everything else
    /// refers to it weakly.
    @MainActor
    final class Coordinator {
        var host: NavigationBarHost?
    }
}

private struct NavigationBarHostKey: EnvironmentKey {
    static let defaultValue: NavigationBarHost? = nil
}

extension EnvironmentValues {

    /// The UIKit owner of the surrounding stack's navigation bar, used to
    /// describe the bar and to push onto the stack.
    var navigationBarHost: NavigationBarHost? {
        get { self[NavigationBarHostKey.self] }
        set { self[NavigationBarHostKey.self] = newValue }
    }
}

private struct NavigationBarViewModifier: ViewModifier {
    let configuration: NavigationBarConfiguration

    @Environment(\.navigationBarHost) private var host

    func body(content: Content) -> some View {
        content
            .onChange(of: configuration.signature, initial: true) { _, _ in
                host?.apply(configuration)
            }
    }
}

extension View {

    /// Describes this screen's navigation bar for UIKit to build.
    /// - Parameters:
    ///   - title: The title pinned to the leading edge of the bar.
    ///   - items: The bar's items, ordered leading to trailing.
    /// - Returns: A view that keeps the surrounding bar in step with its state.
    func navigationBar(
        title: String,
        items: [NavigationBarItem] = []
    ) -> some View {
        modifier(
            NavigationBarViewModifier(
                configuration: NavigationBarConfiguration(title: title, items: items)
            )
        )
    }
}
