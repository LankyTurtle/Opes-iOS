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

    func makeDestination() -> UIViewController {
        switch self {
        case .home:
            return HomeViewController()
        case .accounts:
            return AccountsViewController()
        case .transactions:
            return TransactionsViewController()
        case .budgets:
            return BudgetsViewController()
        }
    }
}
