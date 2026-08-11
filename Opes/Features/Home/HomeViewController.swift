import UIKit

final class HomeViewController: TabRootViewController {
    private let customiseButton = UIButton(type: .system)

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: Self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

    private let balanceTile = AvailableBalanceTileView()
    private let customTile = AvailableBalanceTileView()
    private lazy var recentTile = RecentTransactionsTileView(
        transactions: Self.recentTransactions()
    )

    private var tileOrder = HomeTileOrder.load()

    private let accounts = AccountPreview.sample

    private var accountSelectionTransition: SlideFromSourceTransition?

    /// Defaults to the accounts holding money — debt would otherwise read as an
    /// "available balance" of hundreds of thousands in the negative.
    private lazy var selectedAccountIDs: Set<AccountPreview.ID> = Set(
        self.accounts.filter { $0.balance > 0 }.map(\.id)
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.titleLabel)

        var customiseConfiguration = UIButton.Configuration.plain()
        customiseConfiguration.image = UIImage(systemName: "ellipsis.circle")
        self.customiseButton.configuration = customiseConfiguration
        self.customiseButton.translatesAutoresizingMaskIntoConstraints = false
        self.customiseButton.accessibilityLabel = "Customise Home"
        self.customiseButton.setContentHuggingPriority(.required, for: .horizontal)
        self.customiseButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.customiseButton.addTarget(
            self,
            action: #selector(self.handleCustomiseTap),
            for: .touchUpInside
        )
        self.view.addSubview(self.customiseButton)

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        self.collectionView.delegate = self
        self.view.addSubview(self.collectionView)

        self.balanceTile.addTarget(
            self,
            action: #selector(self.handleBalanceTileTap),
            for: .touchUpInside
        )

        // Same tile, presented the other way, so the two transitions can be compared
        // side by side.
        self.customTile.headerTitle = HomeTile.custom.title
        self.customTile.addTarget(
            self,
            action: #selector(self.handleCustomTileTap),
            for: .touchUpInside
        )

        let marginsGuide = self.view.layoutMarginsGuide

        NSLayoutConstraint.activate([
            self.titleLabel.topAnchor.constraint(
                equalTo: self.view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            self.titleLabel.leadingAnchor.constraint(equalTo: marginsGuide.leadingAnchor),
            self.titleLabel.trailingAnchor.constraint(
                equalTo: self.customiseButton.leadingAnchor,
                constant: -8
            ),

            self.customiseButton.centerYAnchor.constraint(equalTo: self.titleLabel.centerYAnchor),
            self.customiseButton.trailingAnchor.constraint(equalTo: marginsGuide.trailingAnchor),

            self.collectionView.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 8),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            // Pinned past the safe area so tiles scroll under the tab bar.
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])

        self.apply(order: self.tileOrder, animated: false)
        self.refreshTiles()
    }

    @objc private func handleCustomiseTap() {
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

    /// Native sheet: grabber and drag-to-dismiss, with the zoom transition growing
    /// out of the tile.
    @objc private func handleBalanceTileTap() {
        let navigationController = Self.makeSheet(for: self.makeAccountSelection())

        navigationController.preferredTransition = .zoom { [weak self] _ in
            self?.balanceTile
        }

        self.present(navigationController, animated: true)
    }

    /// Custom presentation: fixed-height card flying in right to left out of the
    /// tile, at the cost of the grabber and drag-to-dismiss.
    @objc private func handleCustomTileTap() {
        let navigationController = UINavigationController(rootViewController: self.makeAccountSelection())

        let transition = SlideFromSourceTransition(sourceView: self.customTile)
        // `transitioningDelegate` is weak, so the transition has to be held here.
        self.accountSelectionTransition = transition

        navigationController.modalPresentationStyle = .custom
        navigationController.transitioningDelegate = transition

        self.present(navigationController, animated: true)
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

        self.balanceTile.show(balance: balance, accountCount: selected.count)
        self.customTile.show(balance: balance, accountCount: selected.count)
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
        case .balance:
            return self.balanceTile
        case .custom:
            return self.customTile
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
