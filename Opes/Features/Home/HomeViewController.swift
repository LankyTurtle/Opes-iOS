import UIKit

final class HomeViewController: TabRootViewController {
    private let scrollView = UIScrollView()
    private let contentColumn = UIStackView()
    private let balanceTile = AvailableBalanceTileView()

    private let accounts = AccountPreview.sample

    /// Defaults to the accounts holding money — debt would otherwise read as an
    /// "available balance" of hundreds of thousands in the negative.
    private lazy var selectedAccountIDs: Set<AccountPreview.ID> = Set(
        self.accounts.filter { $0.balance > 0 }.map(\.id)
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.scrollView)

        self.contentColumn.translatesAutoresizingMaskIntoConstraints = false
        self.contentColumn.axis = .vertical
        self.contentColumn.spacing = 16
        self.contentColumn.isLayoutMarginsRelativeArrangement = true
        self.contentColumn.directionalLayoutMargins.top = 8
        self.contentColumn.directionalLayoutMargins.bottom = 16
        self.scrollView.addSubview(self.contentColumn)

        self.balanceTile.addTarget(
            self,
            action: #selector(self.handleBalanceTileTap),
            for: .touchUpInside
        )

        // The title scrolls away with the content rather than staying pinned.
        self.contentColumn.addArrangedSubview(self.titleLabel)
        self.contentColumn.addArrangedSubview(self.balanceTile)
        self.contentColumn.addArrangedSubview(
            RecentTransactionsTileView(transactions: Self.recentTransactions())
        )

        let contentLayoutGuide = self.scrollView.contentLayoutGuide
        let frameLayoutGuide = self.scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.contentColumn.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            self.contentColumn.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            self.contentColumn.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            self.contentColumn.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            self.contentColumn.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
        ])

        self.refreshBalanceTile()
    }

    /// Keeps the content inset in step with the system's readable margins, which
    /// vary by device width.
    override func viewLayoutMarginsDidChange() {
        super.viewLayoutMarginsDidChange()

        self.contentColumn.directionalLayoutMargins.leading = self.view.directionalLayoutMargins.leading
        self.contentColumn.directionalLayoutMargins.trailing = self.view.directionalLayoutMargins.trailing
    }

    @objc private func handleBalanceTileTap() {
        let selection = AccountSelectionViewController(
            accounts: self.accounts,
            selectedIDs: self.selectedAccountIDs
        ) { [weak self] selectedIDs in
            self?.selectedAccountIDs = selectedIDs
            self?.refreshBalanceTile()
        }

        let navigationController = UINavigationController(rootViewController: selection)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        self.present(navigationController, animated: true)
    }

    private func refreshBalanceTile() {
        let selected = self.accounts.filter { self.selectedAccountIDs.contains($0.id) }

        self.balanceTile.show(
            balance: selected.reduce(Decimal.zero) { $0 + $1.balance },
            accountCount: selected.count
        )
    }

    /// Sorted rather than trusting the sample data's order, so this still holds
    /// once transactions come from a real store.
    private static func recentTransactions() -> [Transaction] {
        Array(Transaction.sample.sorted { $0.date > $1.date }.prefix(5))
    }
}
