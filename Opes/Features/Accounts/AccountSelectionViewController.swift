import UIKit

/// Multi-select list of accounts, presented as a sheet, reporting each change back
/// as it happens so the caller stays in step without waiting for a dismissal.
final class AccountSelectionViewController: UIViewController {
    private enum Section {
        case main
    }

    private let accounts: [AccountPreview]
    private var selectedIDs: Set<AccountPreview.ID>
    private let onChange: (Set<AccountPreview.ID>) -> Void

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: Self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

    init(
        accounts: [AccountPreview],
        selectedIDs: Set<AccountPreview.ID>,
        onChange: @escaping (Set<AccountPreview.ID>) -> Void
    ) {
        self.accounts = accounts
        self.selectedIDs = selectedIDs
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Include Accounts"
        self.view.backgroundColor = .systemGroupedBackground
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(self.handleDone)
        )

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        self.collectionView.delegate = self
        // Keeps the list draggable at either detent even when the accounts don't
        // fill the sheet, so it never reads as a fixed pane.
        self.collectionView.alwaysBounceVertical = true
        self.view.addSubview(self.collectionView)

        NSLayoutConstraint.activate([
            self.collectionView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])

        var snapshot = NSDiffableDataSourceSnapshot<Section, AccountPreview>()
        snapshot.appendSections([.main])
        snapshot.appendItems(self.accounts, toSection: .main)
        self.dataSource.apply(snapshot, animatingDifferences: false)
    }

    @objc private func handleDone() {
        self.dismiss(animated: true)
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, AccountPreview> {
        // Weak, because the data source outlives this closure's use and holding
        // `self` strongly here would close the loop back through the collection view.
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, AccountPreview> {
            [weak self] cell, _, account in
            var content = UIListContentConfiguration.subtitleCell()
            content.image = account.institutionLogo
            content.text = account.name
            content.secondaryText = account.institution
            cell.contentConfiguration = content

            var accessories: [UICellAccessory] = [.label(text: account.formattedBalance)]
            if self?.selectedIDs.contains(account.id) == true {
                accessories.append(.checkmark())
            }
            cell.accessories = accessories
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

extension AccountSelectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let account = self.dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        if self.selectedIDs.contains(account.id) {
            self.selectedIDs.remove(account.id)
        } else {
            self.selectedIDs.insert(account.id)
        }

        var snapshot = self.dataSource.snapshot()
        snapshot.reconfigureItems([account])
        self.dataSource.apply(snapshot, animatingDifferences: true)

        self.onChange(self.selectedIDs)
    }
}
