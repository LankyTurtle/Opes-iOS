import UIKit

final class AccountsViewController: TabRootViewController {
    private enum Section {
        case main
    }

    private let accountProvider: any AccountProviding
    private let accountStore: AccountStore
    private let transactionStore: TransactionStore

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

    /// Every account, before the filter is applied.
    private var accounts: [AccountPreview] = []
    private var filter = AccountFilter()
    private lazy var filterItem: UIBarButtonItem = {
        // Rebuilt each time it opens, so its checkmarks and options always
        // reflect the current accounts and filter.
        let menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.makeFilterMenuElements() ?? [])
            },
        ])
        let item = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease"), menu: menu)
        item.accessibilityLabel = "Filter accounts"
        return item
    }()

    init(
        accountProvider: (any AccountProviding)? = nil,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared
    ) {
        self.accountProvider = accountProvider ?? accountStore
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // The first item sits at the trailing edge, keeping + in its usual place.
        self.navigationItem.rightBarButtonItems = [
            AppBarButtonItem.add(
                target: self,
                action: #selector(self.addAccount),
                accessibilityLabel: "Add account"
            ),
            self.filterItem,
        ]

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        self.collectionView.delegate = self
        self.view.addSubview(self.collectionView)
        // Keep the account list connected to the navigation bar when switching
        // between the empty state and populated rows.
        self.setContentScrollView(self.collectionView, for: .top)

        NSLayoutConstraint.activate([
            self.collectionView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            // Pinned past the safe area so rows scroll under the tab bar.
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])

        self.reloadAccounts()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.reloadAccounts()
    }

    @objc private func addAccount() {
        let editor = AccountEditorViewController(store: self.accountStore) { [weak self] _ in
            self?.reloadAccounts()
        }
        self.navigationController?.pushViewController(editor, animated: true)
    }

    private func reloadAccounts() {
        self.accounts = self.accountProvider.accounts()
        self.applyFilter()
    }

    private func applyFilter(animated: Bool = false, completion: (() -> Void)? = nil) {
        self.filter.removeUnavailable(
            types: Set(self.accounts.map(\.type)), institutions: self.accounts.map(\.institution)
        )
        let matches = self.accounts.filter { self.filter.matches(type: $0.type, institution: $0.institution) }
        var snapshot = NSDiffableDataSourceSnapshot<Section, AccountPreview>()
        snapshot.appendSections([.main])
        snapshot.appendItems(matches, toSection: .main)
        self.dataSource.apply(snapshot, animatingDifferences: animated, completion: completion)

        var empty = UIContentUnavailableConfiguration.empty()
        if self.accounts.isEmpty {
            empty.image = UIImage(systemName: "wallet.bifold")
            empty.text = "No accounts"
            empty.secondaryText = "Tap + to add an account."
        } else {
            empty.image = UIImage(systemName: "line.3.horizontal.decrease")
            empty.text = "No matching accounts"
            empty.secondaryText = "Try different filters."
            empty.button.title = "Clear Filters"
            empty.buttonProperties.primaryAction = UIAction { [weak self] _ in self?.clearFilter() }
        }
        self.contentUnavailableConfiguration = matches.isEmpty ? empty : nil

        // A tinted button shows at a glance that some accounts are hidden.
        self.filterItem.isHidden = self.accounts.isEmpty
        self.filterItem.style = self.filter.isActive ? .prominent : .plain
        self.filterItem.accessibilityValue = self.filter.isActive
            ? "Showing \(matches.count) of \(self.accounts.count) accounts"
            : nil
    }

    private func clearFilter() {
        self.filter = AccountFilter()
        self.applyFilter(animated: true)
    }

    private func makeFilterMenuElements() -> [UIMenuElement] {
        // Only offer choices some account has; an option that could only ever
        // produce an empty list is noise.
        let typeActions = AccountType.allCases
            .filter { type in self.accounts.contains { $0.type == type } }
            .map { type in
                UIAction(title: type.title, state: self.filter.types.contains(type) ? .on : .off) { [weak self] _ in
                    self?.filter.toggle(type)
                    self?.applyFilter(animated: true)
                }
            }
        var seenInstitutions = Set<String>()
        let institutionActions = self.accounts.map(\.institution)
            .filter { seenInstitutions.insert(AccountFilter.institutionKey($0)).inserted }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { institution in
                UIAction(
                    title: institution, state: self.filter.contains(institution: institution) ? .on : .off
                ) { [weak self] _ in
                    self?.filter.toggle(institution: institution)
                    self?.applyFilter(animated: true)
                }
            }
        var elements: [UIMenuElement] = [
            UIMenu(title: "Type", options: .displayInline, children: typeActions),
            UIMenu(title: "Institution", options: .displayInline, children: institutionActions),
        ]
        if self.filter.isActive {
            elements.append(UIMenu(options: .displayInline, children: [
                UIAction(title: "Clear Filters", image: UIImage(systemName: "xmark.circle")) { [weak self] _ in
                    self?.clearFilter()
                },
            ]))
        }
        return elements
    }

    private func makeLayout() -> UICollectionViewLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let account = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                guard let self else { completion(false); return }
                do {
                    try self.accountStore.delete(id: account.id, transactionStore: self.transactionStore)
                    self.accounts.removeAll { $0.id == account.id }
                    self.applyFilter(animated: true) { completion(true) }
                } catch {
                    completion(false)
                    let alert = UIAlertController(
                        title: "Couldn’t delete account", message: error.localizedDescription, preferredStyle: .alert
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

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, AccountPreview> {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, AccountPreview> {
            cell, _, account in
            var content = UIListContentConfiguration.subtitleCell()
            content.image = account.institutionLogo
            content.text = account.name
            content.secondaryText = account.subtitle
            cell.contentConfiguration = content
            // The balance, then the chevron the row's forecast is behind.
            cell.accessories = [.label(text: account.formattedBalance), .disclosureIndicator()]
        }

        return UICollectionViewDiffableDataSource<Section, AccountPreview>(
            collectionView: self.collectionView
        ) { collectionView, indexPath, account in
            collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: account
            )
        }
    }
}

extension AccountsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let account = self.dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        self.navigationController?.pushViewController(
            ForecastViewController(subject: .account(account), accountProvider: self.accountProvider),
            animated: true
        )
    }
}
