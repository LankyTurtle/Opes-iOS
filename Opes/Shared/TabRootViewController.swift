import UIKit

/// Base for a screen that draws its own large title at the top of its content,
/// the way Music and the App Store do.
///
/// The navigation bar's large title always reserves a 44pt band for bar button
/// items above itself, which sits the title lower on the screen than we want.
/// So while this screen is the root of its stack the bar is hidden and the title
/// is drawn as ordinary content. Anything pushed on top gets the bar — and its
/// back button — back.
class TabRootViewController: UIViewController {
    /// Positioned by the subclass, so a scrolling screen can let its title scroll away.
    let titleLabel = UILabel()

    /// Only the root of a stack draws its own title; a pushed screen keeps the bar.
    var drawsOwnTitle: Bool {
        self.navigationController?.viewControllers.first === self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemBackground

        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.font = DesignTokens.largeTitleFont
        self.titleLabel.adjustsFontForContentSizeCategory = true
        self.titleLabel.numberOfLines = 0
        self.titleLabel.text = self.title
        self.titleLabel.isHidden = !self.drawsOwnTitle
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.drawsOwnTitle {
            self.navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Restore the bar only when something is being pushed over us. Leaving a
        // tab keeps it hidden, so returning to the tab doesn't flash a bar in.
        if self.navigationController?.topViewController !== self {
            self.navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }
}
