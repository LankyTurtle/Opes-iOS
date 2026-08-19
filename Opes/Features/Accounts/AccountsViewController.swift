import UIKit

final class AccountsViewController: TabRootViewController {
    private enum Section {
        case main
    }

    private let accountProvider: any AccountProviding
    private let accounts: [AccountPreview]

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: Self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

    init(accountProvider: any AccountProviding = SampleAccountProvider()) {
        self.accountProvider = accountProvider
        self.accounts = accountProvider.accounts()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        self.collectionView.delegate = self
        self.view.addSubview(self.collectionView)

        NSLayoutConstraint.activate([
            self.collectionView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            // Pinned past the safe area so rows scroll under the tab bar.
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])

        self.apply(accounts: self.accounts)
    }

    private func apply(accounts: [AccountPreview]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AccountPreview>()
        snapshot.appendSections([.main])
        snapshot.appendItems(accounts, toSection: .main)
        self.dataSource.apply(snapshot, animatingDifferences: false)
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, AccountPreview> {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, AccountPreview> {
            cell, _, account in
            var content = UIListContentConfiguration.subtitleCell()
            content.image = account.institutionLogo
            content.text = account.name
            content.secondaryText = account.institution
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
