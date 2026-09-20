import UIKit

/// Creates navigation-bar add buttons with one consistent SF Symbol treatment.
enum AppBarButtonItem {
    private static let addImage = UIImage(systemName: "plus")

    static func add(
        target: Any?,
        action: Selector,
        accessibilityLabel: String
    ) -> UIBarButtonItem {
        let item = UIBarButtonItem(
            image: Self.addImage,
            style: .plain,
            target: target,
            action: action
        )
        item.accessibilityLabel = accessibilityLabel
        return item
    }

    static func add(menu: UIMenu, accessibilityLabel: String) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: Self.addImage, menu: menu)
        item.accessibilityLabel = accessibilityLabel
        return item
    }
}
