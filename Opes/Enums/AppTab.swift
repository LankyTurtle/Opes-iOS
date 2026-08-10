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
            return "wallet.pass.fill"
        case .transactions:
            return "arrow.left.arrow.right"
        case .budgets:
            return "chart.pie.fill"
        }
    }

    var image: UIImage? {
        UIImage(systemName: self.icon)
    }

    /// Builds the tab's navigation stack, titled and configured from the tab itself
    /// so no screen has to describe how it is presented.
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
        destination.navigationItem.largeTitleDisplayMode = .always

        return destination
    }
}
