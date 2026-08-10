import UIKit

final class AccountsViewController: TabRootViewController {
    private enum Section {
        case main
    }

    private let accounts = AccountPreview.sample

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: Self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.titleLabel)

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        self.view.addSubview(self.collectionView)

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
            cell.accessories = [.label(text: account.formattedBalance)]
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
