import UIKit

/// Base for a tab's root screen.
///
/// The navigation bar draws the large title, so it collapses into an inline title
/// on scroll and cross-fades on push the way the system does. Screens pin their
/// scroll view to the view's own top edge rather than the safe area, so content
/// passes under the bar and drives that collapse.
class TabRootViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemBackground
        self.navigationItem.largeTitleDisplayMode = .always
    }
}
