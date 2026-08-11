import UIKit

final class HomeViewController: TabRootViewController {
    private let scrollView = UIScrollView()
    private let contentColumn = UIStackView()
    private let balanceTile = AvailableBalanceTileView()
    private let customTile = AvailableBalanceTileView()

    private let accounts = AccountPreview.sample

    /// Up to this many accounts, the selection card opens at the shorter height.
    private static let mediumSheetAccountLimit = 5
    private static let shortCardHeightFraction: CGFloat = 0.5

    private var accountSelectionTransition: SlideFromSourceTransition?

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

        // Same tile, presented the other way, so the two transitions can be compared
        // side by side.
        self.customTile.headerTitle = "Custom"
        self.customTile.addTarget(
            self,
            action: #selector(self.handleCustomTileTap),
            for: .touchUpInside
        )

        // The title scrolls away with the content rather than staying pinned.
        self.contentColumn.addArrangedSubview(self.titleLabel)
        self.contentColumn.addArrangedSubview(self.balanceTile)
        self.contentColumn.addArrangedSubview(self.customTile)
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

        self.refreshTiles()
    }

    /// Keeps the content inset in step with the system's readable margins, which
    /// vary by device width.
    override func viewLayoutMarginsDidChange() {
        super.viewLayoutMarginsDidChange()

        self.contentColumn.directionalLayoutMargins.leading = self.view.directionalLayoutMargins.leading
        self.contentColumn.directionalLayoutMargins.trailing = self.view.directionalLayoutMargins.trailing
    }

    /// Native sheet: real detents, grabber and drag-to-dismiss, with the zoom
    /// transition growing out of the tile.
    @objc private func handleBalanceTileTap() {
        let navigationController = self.makeAccountSelectionController()
        navigationController.modalPresentationStyle = .pageSheet

        if let sheet = navigationController.sheetPresentationController {
            // A long list needs the height to be usable; a short one shouldn't take
            // over the screen to show a handful of rows.
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = self.accounts.count > Self.mediumSheetAccountLimit
                ? .large
                : .medium
            // Otherwise dragging the list at the medium detent grows the sheet to
            // full height instead of scrolling it. The grabber still expands it.
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersGrabberVisible = true
            // Pinned rather than left to the system default, so the custom card can
            // be given the same value instead of guessing at what the default is.
            sheet.preferredCornerRadius = SlideFromSourceTransition.cardCornerRadius
        }

        navigationController.preferredTransition = .zoom { [weak self] _ in
            self?.balanceTile
        }

        self.present(navigationController, animated: true)
    }

    /// Custom presentation: fixed-height card flying in right to left out of the
    /// tile, at the cost of the grabber and drag-to-dismiss.
    @objc private func handleCustomTileTap() {
        let navigationController = self.makeAccountSelectionController()

        let transition = SlideFromSourceTransition(
            sourceView: self.customTile,
            height: self.accounts.count > Self.mediumSheetAccountLimit
                ? .matchingLargeDetent
                : .fraction(Self.shortCardHeightFraction)
        )
        // `transitioningDelegate` is weak, so the transition has to be held here.
        self.accountSelectionTransition = transition

        navigationController.modalPresentationStyle = .custom
        navigationController.transitioningDelegate = transition

        self.present(navigationController, animated: true)
    }

    private func makeAccountSelectionController() -> UINavigationController {
        let selection = AccountSelectionViewController(
            accounts: self.accounts,
            selectedIDs: self.selectedAccountIDs
        ) { [weak self] selectedIDs in
            self?.selectedAccountIDs = selectedIDs
            self?.refreshTiles()
        }

        return UINavigationController(rootViewController: selection)
    }

    private func refreshTiles() {
        let selected = self.accounts.filter { self.selectedAccountIDs.contains($0.id) }
        let balance = selected.reduce(Decimal.zero) { $0 + $1.balance }

        self.balanceTile.show(balance: balance, accountCount: selected.count)
        self.customTile.show(balance: balance, accountCount: selected.count)
    }

    /// Sorted rather than trusting the sample data's order, so this still holds
    /// once transactions come from a real store.
    private static func recentTransactions() -> [Transaction] {
        Array(Transaction.sample.sorted { $0.date > $1.date }.prefix(5))
    }
}
