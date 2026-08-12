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
    private let searchControl = UIStackView()
    private let searchBar = UISearchBar()
    private let closeButton = UIButton(type: .system)

    private var compactSearchCenterConstraint: NSLayoutConstraint!
    private var compactSearchWidthConstraint: NSLayoutConstraint!
    private var expandedSearchLeadingConstraint: NSLayoutConstraint!
    private var expandedSearchTrailingConstraint: NSLayoutConstraint!
    private var isSearchExpanded = false

    private static let compactSearchWidth: CGFloat = 152
    private static let compactPlaceholder = "Search"
    private static let expandedPlaceholder = "Search transactions"

    /// The pill has to grow with the placeholder it holds, or "Search" clips at the
    /// larger accessibility text sizes.
    private var scaledCompactSearchWidth: CGFloat {
        UIFontMetrics(forTextStyle: .body).scaledValue(for: Self.compactSearchWidth)
    }

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
        self.searchControl.translatesAutoresizingMaskIntoConstraints = false
        self.searchControl.axis = .horizontal
        self.searchControl.alignment = .center
        self.searchControl.spacing = 4
        self.view.addSubview(self.searchControl)

        self.searchBar.searchBarStyle = .minimal
        self.searchBar.placeholder = Self.compactPlaceholder
        self.searchBar.autocorrectionType = .no
        self.searchBar.delegate = self
        // The field yields; the close button keeps its size. Without this the search
        // bar's intrinsic width argues with the compact pill's fixed width.
        self.searchBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        self.searchBar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.searchControl.addArrangedSubview(self.searchBar)

        var closeConfiguration = UIButton.Configuration.plain()
        closeConfiguration.image = UIImage(systemName: "xmark")
        closeConfiguration.baseForegroundColor = .secondaryLabel
        closeConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 14,
            leading: 14,
            bottom: 14,
            trailing: 14
        )
        self.closeButton.configuration = closeConfiguration
        self.closeButton.accessibilityLabel = "Close search"
        self.closeButton.isHidden = true
        self.closeButton.setContentHuggingPriority(.required, for: .horizontal)
        self.closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.closeButton.addTarget(
            self,
            action: #selector(self.handleCloseSearch),
            for: .touchUpInside
        )
        self.searchControl.addArrangedSubview(self.closeButton)

        let dismissSwipe = UISwipeGestureRecognizer(
            target: self,
            action: #selector(self.handleDismissSwipe)
        )
        dismissSwipe.direction = .down
        self.searchBar.addGestureRecognizer(dismissSwipe)

        let marginsGuide = self.view.layoutMarginsGuide

        self.compactSearchCenterConstraint = self.searchControl.centerXAnchor.constraint(
            equalTo: self.view.centerXAnchor
        )
        self.compactSearchWidthConstraint = self.searchControl.widthAnchor.constraint(
            equalToConstant: self.scaledCompactSearchWidth
        )
        self.expandedSearchLeadingConstraint = self.searchControl.leadingAnchor.constraint(
            equalTo: marginsGuide.leadingAnchor,
            constant: -DesignTokens.searchFieldInset
        )
        // Mirrors the leading inset. The close button's own content insets then sit
        // its glyph just inside the margin, matching where the field's text starts.
        self.expandedSearchTrailingConstraint = self.searchControl.trailingAnchor.constraint(
            equalTo: marginsGuide.trailingAnchor,
            constant: DesignTokens.searchFieldInset
        )

        NSLayoutConstraint.activate([
            self.titleLabel.topAnchor.constraint(
                equalTo: self.view.safeAreaLayoutGuide.topAnchor,
                constant: DesignTokens.titleTopInset
            ),
            self.titleLabel.leadingAnchor.constraint(equalTo: marginsGuide.leadingAnchor),
            self.titleLabel.trailingAnchor.constraint(equalTo: marginsGuide.trailingAnchor),

            self.collectionView.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: DesignTokens.titleSpacing),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            // Pinned past the safe area so rows scroll under the tab bar.
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.emptyLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.emptyLabel.centerYAnchor.constraint(equalTo: self.collectionView.centerYAnchor),
            self.emptyLabel.leadingAnchor.constraint(equalTo: marginsGuide.leadingAnchor),
            self.emptyLabel.trailingAnchor.constraint(equalTo: marginsGuide.trailingAnchor),

            self.compactSearchCenterConstraint,
            self.compactSearchWidthConstraint,
            // The keyboard layout guide sits at the safe area bottom — above the tab
            // bar — while the keyboard is down, and rides the keyboard when it's up.
            self.searchControl.bottomAnchor.constraint(
                equalTo: self.view.keyboardLayoutGuide.topAnchor,
                constant: -8
            ),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleContentSizeCategoryChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )

        self.apply(query: "", animated: false)
    }

    @objc private func handleContentSizeCategoryChange() {
        self.compactSearchWidthConstraint.constant = self.scaledCompactSearchWidth
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Let the last row clear the floating search field.
        let bottomInset = self.searchControl.bounds.height + 8
        if self.collectionView.contentInset.bottom != bottomInset {
            self.collectionView.contentInset.bottom = bottomInset
            self.collectionView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    @objc private func handleDismissSwipe() {
        self.dismissSearchKeyboard()
    }

    @objc private func handleCloseSearch() {
        self.searchBar.text = ""
        self.apply(query: "", animated: true)
        self.searchBar.searchTextField.resignFirstResponder()
        self.setSearchExpanded(false, animated: true)
    }

    /// The single close path — swipe, Search key, and scrolling all land here, so the
    /// keyboard never goes away without the search bar animating back down with it.
    /// The query is deliberately kept; only the keyboard is dismissed.
    private func dismissSearchKeyboard() {
        guard self.searchBar.searchTextField.isFirstResponder else {
            self.collapseSearchIfEmpty()
            return
        }

        self.searchBar.searchTextField.resignFirstResponder()

        // Collapsing already animates the whole layout, so the rest animation would
        // be a second spring retargeting the same constraints on a different curve.
        // Calling this here rather than trusting `searchBarTextDidEndEditing` also
        // means the collapse doesn't hinge on the search bar forwarding its text
        // field's end-editing callback; the call is idempotent either way.
        if !self.collapseSearchIfEmpty() {
            self.animateSearchBarToRest()
        }
    }

    /// Returns whether the search is collapsed — true when the query is empty, even
    /// if it was already collapsed — so callers know an animation is under way.
    @discardableResult
    private func collapseSearchIfEmpty() -> Bool {
        let query = self.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard query.isEmpty else {
            return false
        }

        self.setSearchExpanded(false, animated: true)
        return true
    }

    private func setSearchExpanded(_ expanded: Bool, animated: Bool) {
        guard self.isSearchExpanded != expanded else {
            return
        }

        self.view.layoutIfNeeded()
        self.isSearchExpanded = expanded

        if expanded {
            NSLayoutConstraint.deactivate([
                self.compactSearchCenterConstraint,
                self.compactSearchWidthConstraint,
            ])
            NSLayoutConstraint.activate([
                self.expandedSearchLeadingConstraint,
                self.expandedSearchTrailingConstraint,
            ])
        } else {
            // Shorten the placeholder before the pill shrinks around it, so the long
            // string is never rendered into a field too narrow to hold it.
            self.searchBar.placeholder = Self.compactPlaceholder
            NSLayoutConstraint.deactivate([
                self.expandedSearchLeadingConstraint,
                self.expandedSearchTrailingConstraint,
            ])
            NSLayoutConstraint.activate([
                self.compactSearchCenterConstraint,
                self.compactSearchWidthConstraint,
            ])
        }
        self.closeButton.isHidden = !expanded

        // Conversely, the long placeholder waits until there's room for it.
        let finish = {
            if expanded {
                self.searchBar.placeholder = Self.expandedPlaceholder
            }
        }

        guard animated else {
            self.view.layoutIfNeeded()
            finish()
            return
        }

        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: {
                self.view.layoutIfNeeded()
            },
            completion: { _ in
                finish()
            }
        )
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
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        self.setSearchExpanded(true, animated: true)
        return true
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if !searchText.isEmpty {
            self.setSearchExpanded(true, animated: true)
        }
        self.apply(query: searchText, animated: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.dismissSearchKeyboard()
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.collapseSearchIfEmpty()
    }
}

extension TransactionsViewController: UICollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.dismissSearchKeyboard()
    }
}
