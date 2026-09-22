import UIKit

final class TransactionsViewController: TabRootViewController {
    private enum Section {
        case main
    }

    private let accountProvider: any AccountProviding
    private let transactionProvider: any TransactionProviding
    private var transactions: [Transaction]
    private let transactionStore: TransactionStore

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

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

    init(
        accountProvider: any AccountProviding = AccountStore.shared,
        transactionProvider: any TransactionProviding = TransactionStore.shared,
        transactionStore: TransactionStore = .shared
    ) {
        self.accountProvider = accountProvider
        self.transactionProvider = transactionProvider
        self.transactionStore = transactionStore
        self.transactions = transactionProvider.transactions()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = AppBarButtonItem.add(
            menu: UIMenu(children: [
                UIAction(title: "Add Manually", image: UIImage(systemName: "square.and.pencil")) { [weak self] _ in
                    self?.showManualEntry()
                },
                UIAction(title: "Upload CSV", image: UIImage(systemName: "doc.badge.arrow.up")) { [weak self] _ in
                    self?.showCSVUpload()
                },
            ]),
            accessibilityLabel: "Add transaction"
        )

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        // Dismissal is driven from `scrollViewWillBeginDragging` rather than by
        // `keyboardDismissMode`, so scrolling animates the close like every other route.
        self.collectionView.delegate = self
        self.view.addSubview(self.collectionView)
        // Identify the list explicitly so the floating search control doesn't
        // interfere with the navigation bar's scroll-edge behavior.
        self.setContentScrollView(self.collectionView, for: .top)

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
            self.collectionView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            // Pinned past the safe area so rows scroll under the tab bar.
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.transactions = self.transactionProvider.transactions()
        self.apply(query: self.searchBar.text ?? "", animated: false)
    }

    private func showManualEntry() {
        self.dismissSearchKeyboard()
        let editor = TransactionEditorViewController(accounts: self.accountProvider.accounts()) { [weak self] transaction in
            guard let self else { return }
            try self.transactionStore.save(transaction)
            self.transactions.insert(transaction, at: 0)
            self.transactions.sort { $0.date > $1.date }
            self.apply(query: self.searchBar.text ?? "", animated: true)
        }
        self.navigationController?.pushViewController(editor, animated: true)
    }

    private func showCSVUpload() {
        self.dismissSearchKeyboard()
        self.navigationController?.pushViewController(
            TransactionCSVUploadViewController(accounts: self.accountProvider.accounts()) { [weak self] transactions in
                guard let self else { return }
                try self.transactionStore.save(transactions)
                self.transactions.append(contentsOf: transactions)
                self.transactions.sort { $0.date > $1.date }
                self.apply(query: self.searchBar.text ?? "", animated: true)
            },
            animated: true
        )
    }

    @objc private func handleContentSizeCategoryChange() {
        self.compactSearchWidthConstraint.constant = self.scaledCompactSearchWidth
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Let the last row clear the floating search field.
        let bottomInset: CGFloat = self.searchControl.isHidden ? 0 : self.searchControl.bounds.height + 8
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

    private func apply(query: String, animated: Bool, completion: (() -> Void)? = nil) {
        self.searchControl.isHidden = self.transactions.isEmpty
        if self.transactions.isEmpty {
            self.searchBar.text = ""
            self.searchBar.searchTextField.resignFirstResponder()
            self.setSearchExpanded(false, animated: false)
        }
        self.view.setNeedsLayout()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = trimmed.isEmpty
            ? self.transactions
            : self.transactions.filter { transaction in
                [transaction.summary, transaction.description, transaction.reference ?? ""]
                    .contains { $0.localizedCaseInsensitiveContains(trimmed) }
            }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Transaction>()
        snapshot.appendSections([.main])
        snapshot.appendItems(matches, toSection: .main)
        self.dataSource.apply(snapshot, animatingDifferences: animated, completion: completion)

        var empty = UIContentUnavailableConfiguration.empty()
        if self.transactions.isEmpty {
            empty.image = UIImage(systemName: "arrow.left.arrow.right")
            empty.text = "No transactions"
            empty.secondaryText = "Tap + to add a transaction or upload a CSV."
        } else {
            empty.image = UIImage(systemName: "magnifyingglass")
            empty.text = "No matching transactions"
            empty.secondaryText = "Try a different search."
        }
        self.contentUnavailableConfiguration = matches.isEmpty ? empty : nil
        // Keep search accessible above the system empty-state view.
        self.view.bringSubviewToFront(self.searchControl)
    }

    private func makeLayout() -> UICollectionViewLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let transaction = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            // Capture the transaction's identity from the displayed snapshot,
            // including when search has filtered or reordered the visible rows.
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                guard let self else {
                    completion(false)
                    return
                }
                do {
                    try self.transactionStore.delete(id: transaction.id)
                    self.transactions.removeAll { $0.id == transaction.id }
                    self.apply(query: self.searchBar.text ?? "", animated: true) {
                        completion(true)
                    }
                } catch {
                    completion(false)
                    let alert = UIAlertController(
                        title: "Couldn’t delete transaction", message: error.localizedDescription, preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
            delete.image = UIImage(systemName: "trash")
            let actions = UISwipeActionsConfiguration(actions: [delete])
            actions.performsFirstActionWithFullSwipe = true
            return actions
        }
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Transaction> {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Transaction> {
            cell, _, transaction in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = transaction.summary
            content.secondaryText = transaction.formattedDate
            cell.contentConfiguration = content
            // The amount, then the chevron the row's details are behind.
            cell.accessories = [
                .label(text: transaction.formattedAmount),
                .disclosureIndicator(),
            ]
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
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let transaction = self.dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        // The keyboard would otherwise still be up under the details screen, and
        // ride back into view on the way here.
        self.dismissSearchKeyboard()

        self.navigationController?.pushViewController(
            TransactionDetailsViewController(
                transaction: transaction,
                accountProvider: self.accountProvider,
                transactionProvider: self.transactionProvider,
                transactionStore: self.transactionStore
            ),
            animated: true
        )
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.dismissSearchKeyboard()
    }
}
