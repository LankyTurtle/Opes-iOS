import UIKit

final class TransactionsViewController: TabRootViewController {
    private enum Section {
        case main
    }

    private let transactions = Transaction.sample

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: Self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

    private let emptyLabel = UILabel()
    private let searchBar = UISearchBar()

    /// `UISearchBar` insets its field from its own edges. Cancelling that out lines
    /// the visible pill up with the list cells rather than sitting inside them.
    private static let searchFieldInset: CGFloat = 8

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.titleLabel)

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        // Dismissal is driven from `scrollViewWillBeginDragging` rather than by
        // `keyboardDismissMode`, so scrolling animates the close like every other route.
        self.collectionView.delegate = self
        self.view.addSubview(self.collectionView)

        self.emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        self.emptyLabel.font = .preferredFont(forTextStyle: .body)
        self.emptyLabel.adjustsFontForContentSizeCategory = true
        self.emptyLabel.textColor = .secondaryLabel
        self.emptyLabel.textAlignment = .center
        self.emptyLabel.text = "No matching transactions"
        self.emptyLabel.isHidden = true
        self.view.addSubview(self.emptyLabel)

        // Added last so it stays above the list and the empty state — the user has
        // to be able to reach the field to clear a search that matched nothing.
        self.searchBar.translatesAutoresizingMaskIntoConstraints = false
        self.searchBar.searchBarStyle = .minimal
        self.searchBar.placeholder = "Search"
        self.searchBar.autocorrectionType = .no
        self.searchBar.delegate = self
        self.view.addSubview(self.searchBar)

        let dismissSwipe = UISwipeGestureRecognizer(
            target: self,
            action: #selector(self.handleDismissSwipe)
        )
        dismissSwipe.direction = .down
        self.searchBar.addGestureRecognizer(dismissSwipe)

        let marginsGuide = self.view.layoutMarginsGuide

        NSLayoutConstraint.activate([
            self.titleLabel.topAnchor.constraint(
                equalTo: self.view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            self.titleLabel.leadingAnchor.constraint(equalTo: marginsGuide.leadingAnchor),
            self.titleLabel.trailingAnchor.constraint(equalTo: marginsGuide.trailingAnchor),

            self.collectionView.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 8),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            // Pinned past the safe area so rows scroll under the tab bar.
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.emptyLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.emptyLabel.centerYAnchor.constraint(equalTo: self.collectionView.centerYAnchor),
            self.emptyLabel.leadingAnchor.constraint(equalTo: marginsGuide.leadingAnchor),
            self.emptyLabel.trailingAnchor.constraint(equalTo: marginsGuide.trailingAnchor),

            self.searchBar.leadingAnchor.constraint(
                equalTo: marginsGuide.leadingAnchor,
                constant: -Self.searchFieldInset
            ),
            self.searchBar.trailingAnchor.constraint(
                equalTo: marginsGuide.trailingAnchor,
                constant: Self.searchFieldInset
            ),
            // The keyboard layout guide sits at the safe area bottom — above the tab
            // bar — while the keyboard is down, and rides the keyboard when it's up.
            self.searchBar.bottomAnchor.constraint(
                equalTo: self.view.keyboardLayoutGuide.topAnchor,
                constant: -8
            ),
        ])

        self.apply(query: "", animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Let the last row clear the floating search field.
        let bottomInset = self.searchBar.bounds.height + 8
        if self.collectionView.contentInset.bottom != bottomInset {
            self.collectionView.contentInset.bottom = bottomInset
            self.collectionView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    @objc private func handleDismissSwipe() {
        self.dismissSearchKeyboard()
    }

    /// The single close path — swipe, Search key, and scrolling all land here, so the
    /// keyboard never goes away without the search bar animating back down with it.
    /// The query is deliberately kept; only the keyboard is dismissed.
    private func dismissSearchKeyboard() {
        guard self.searchBar.isFirstResponder else {
            return
        }

        self.searchBar.resignFirstResponder()
        self.animateSearchBarToRest()
    }

    /// The keyboard layout guide already drives the search bar back down, but it
    /// follows the keyboard's own curve. Retargeting it as a spring — from wherever
    /// it currently is — gives the close a bit of settle instead of a flat slide.
    private func animateSearchBarToRest() {
        self.view.setNeedsLayout()

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.view.layoutIfNeeded()
        }
    }

    private func apply(query: String, animated: Bool) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = trimmed.isEmpty
            ? self.transactions
            : self.transactions.filter { $0.merchant.localizedCaseInsensitiveContains(trimmed) }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Transaction>()
        snapshot.appendSections([.main])
        snapshot.appendItems(matches, toSection: .main)
        self.dataSource.apply(snapshot, animatingDifferences: animated)

        self.emptyLabel.isHidden = !matches.isEmpty
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Transaction> {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Transaction> {
            cell, _, transaction in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = transaction.merchant
            content.secondaryText = transaction.formattedDate
            cell.contentConfiguration = content
            cell.accessories = [.label(text: transaction.formattedAmount)]
        }

        return UICollectionViewDiffableDataSource<Section, Transaction>(
            collectionView: self.collectionView
        ) { collectionView, indexPath, transaction in
            collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: transaction
            )
        }
    }
}

extension TransactionsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.apply(query: searchText, animated: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.dismissSearchKeyboard()
    }
}

extension TransactionsViewController: UICollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.dismissSearchKeyboard()
    }
}
