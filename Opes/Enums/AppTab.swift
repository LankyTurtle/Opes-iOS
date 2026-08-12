import UIKit

enum AppTab: String, CaseIterable, Hashable {
    case home
    case accounts
    case transactions
    case budgets

    var title: String {
        self.rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .accounts:
            return "wallet.bifold.fill"
        case .transactions:
            return "arrow.left.arrow.right"
        case .budgets:
            return "chart.pie.fill"
        }
    }

    var image: UIImage? {
        UIImage(systemName: self.icon)
    }

    /// Builds the tab's navigation stack, titled from the tab itself so no screen
    /// has to name itself.
    ///
    /// The bar's own large title isn't used — `TabRootViewController` draws the
    /// title in its content instead — but the title is still set here so pushed
    /// screens show the right one in the bar.
    func makeNavigationController() -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: self.makeDestination())
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    private func makeDestination() -> UIViewController {
        let destination: UIViewController

        switch self {
        case .home:
            destination = HomeViewController()
        case .accounts:
            destination = AccountsViewController()
        case .transactions:
            destination = TransactionsViewController()
        case .budgets:
            destination = BudgetsViewController()
        }

        destination.title = self.title

        return destination
    }
}
