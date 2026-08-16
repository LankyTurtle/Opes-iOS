import UIKit

final class HomeViewController: TabRootViewController {
    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: Self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

    private let availableBalanceTile = AvailableBalanceTileView()
    private let payCycleTrackerTile = PayCycleTrackerTileView()
    private let budgetsTile = BudgetsTileView()
    private lazy var recentTile = RecentTransactionsTileView(
        transactions: Self.recentTransactions()
    )

    private var tileOrder = HomeTileOrder.load()

    private let accounts = AccountPreview.sample
    private let payCycleStore = PayCycleStore.shared
    private let transactionProvider: any TransactionProviding = SampleTransactionProvider()

    private var accountSelectionTransition: SlideFromSourceTransition?

    private lazy var customiseItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            style: .plain,
            target: self,
            action: #selector(self.handleCustomiseTap)
        )
        item.accessibilityLabel = "Customise Home"
        return item
    }()

    /// Defaults to the accounts holding money — debt would otherwise read as an
    /// "available balance" of hundreds of thousands in the negative.
    private lazy var selectedAccountIDs: Set<AccountPreview.ID> = Set(
        self.accounts.filter { $0.balance > 0 }.map(\.id)
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        // A real bar button item, so the bar supplies its material, metrics and
        // press behaviour rather than this screen reproducing them.
        self.navigationItem.rightBarButtonItem = self.customiseItem

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        self.collectionView.delegate = self
        self.view.addSubview(self.collectionView)

        self.availableBalanceTile.addTarget(
            self,
            action: #selector(self.handleAvailableBalanceTileTap),
            for: .touchUpInside
        )
        self.payCycleTrackerTile.addTarget(
            self,
            action: #selector(self.handlePayCycleTrackerTap),
            for: .touchUpInside
        )

        NSLayoutConstraint.activate([
            self.collectionView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            // Pinned past the safe area so tiles scroll under the tab bar.
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])

        self.apply(order: self.tileOrder, animated: false)
        self.refreshTiles()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleAppDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Refreshing here moves the budget-period marker to the current system date
        // whenever Home is revisited or the app returns to the foreground.
        self.refreshTiles()
    }

    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        self.refreshTiles()
    }

    @objc private func handleCustomiseTap() {
        // The account card covers this button while it is on screen and on its way
        // out. Refusing the action keeps the ellipsis inert for that whole window
        // without disabling it — `isEnabled` cross-fades the button, which reads as
        // the ellipsis animating the moment the card's Done button is pressed.
        guard self.presentedViewController == nil, self.accountSelectionTransition == nil else {
            return
        }

        let customise = CustomiseHomeViewController(
            order: self.tileOrder
        ) { [weak self] order in
            guard let self else {
                return
            }

            self.tileOrder = order
            HomeTileOrder.save(order)
            self.apply(order: order, animated: true)
        }

        self.present(Self.makeSheet(for: customise), animated: true)
    }

    /// Custom presentation: fixed-height card flying in right to left out of the
    /// tile, with a hand-drawn grabber because system sheet chrome is unavailable.
    @objc private func handleAvailableBalanceTileTap() {
        guard self.presentedViewController == nil else {
            return
        }

        let accountSelection = self.makeAccountSelection()

        let transition = SlideFromSourceTransition(
            sourceView: self.availableBalanceTile
        ) { [weak self] in
            // The transitioning delegate is weak and must stay alive until the
            // animator has formally completed. Holding it also marks the card as
            // still on its way out, which `handleCustomiseTap` reads.
            self?.accountSelectionTransition = nil
        }
        // `transitioningDelegate` is weak, so the transition has to be held here.
        self.accountSelectionTransition = transition

        accountSelection.modalPresentationStyle = .custom
        accountSelection.transitioningDelegate = transition

        self.present(accountSelection, animated: true)
    }

    @objc private func handlePayCycleTrackerTap() {
        guard self.presentedViewController == nil else {
            return
        }

        let payCycles = PayCyclesViewController(
            store: self.payCycleStore,
            transactionProvider: self.transactionProvider
        ) { [weak self] in
            self?.refreshTiles()
        }
        self.present(Self.makeSheet(for: payCycles), animated: true)
    }

    private func makeAccountSelection() -> AccountSelectionViewController {
        AccountSelectionViewController(
            accounts: self.accounts,
            selectedIDs: self.selectedAccountIDs
        ) { [weak self] selectedIDs in
            self?.selectedAccountIDs = selectedIDs
            self?.refreshTiles()
        }
    }

    private static func makeSheet(for content: UIViewController) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: content)
        navigationController.modalPresentationStyle = .pageSheet

        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        return navigationController
    }

    private func refreshTiles() {
        let selected = self.accounts.filter { self.selectedAccountIDs.contains($0.id) }
        let balance = selected.reduce(Decimal.zero) { $0 + $1.balance }

        self.availableBalanceTile.show(balance: balance, accountCount: selected.count)
        self.payCycleTrackerTile.show(
            cycles: self.payCycleStore.load(),
            transactions: self.transactionProvider.transactions()
        )
        self.budgetsTile.show(budgets: BudgetPreview.sample)
    }

    /// One section per tile, so each draws as its own grouped card.
    private func apply(order: [HomeTile], animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<HomeTile, HomeTile>()
        snapshot.appendSections(order)

        for tile in order {
            snapshot.appendItems([tile], toSection: tile)
        }

        self.dataSource.apply(snapshot, animatingDifferences: animated)
    }

    private func tileView(for tile: HomeTile) -> UIView {
        switch tile {
        case .availableBalance:
            return self.availableBalanceTile
        case .payCycleTracker:
            return self.payCycleTrackerTile
        case .budgets:
            return self.budgetsTile
        case .recentTransactions:
            return self.recentTile
        }
    }

    private static func makeLayout() -> UICollectionViewLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        // Each section holds one self-contained card, so there's nothing to divide.
        configuration.showsSeparators = false
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<HomeTile, HomeTile> {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, HomeTile> {
            [weak self] cell, _, tile in
            guard let self else {
                return
            }

            // The tile views are long-lived — they're updated in place as accounts are
            // selected — so they're moved between cells rather than rebuilt.
            let tileView = self.tileView(for: tile)

            guard tileView.superview !== cell.contentView else {
                return
            }

            tileView.removeFromSuperview()
            tileView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(tileView)

            NSLayoutConstraint.activate([
                tileView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                tileView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                tileView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                tileView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            ])
        }

        return UICollectionViewDiffableDataSource<HomeTile, HomeTile>(
            collectionView: self.collectionView
        ) { collectionView, indexPath, tile in
            collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: tile
            )
        }
    }

    /// Sorted rather than trusting the sample data's order, so this still holds
    /// once transactions come from a real store.
    private static func recentTransactions() -> [Transaction] {
        Array(Transaction.sample.sorted { $0.date > $1.date }.prefix(5))
    }
}

extension HomeViewController: UICollectionViewDelegate {
    /// The tiles handle their own taps; a cell selection highlight on top of that
    /// would fight the control's own highlighting.
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        false
    }
}
