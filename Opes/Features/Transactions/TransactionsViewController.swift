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
    private let searchBackground = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemChromeMaterial)
    )
    private let searchBar = UISearchBar()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.titleLabel)

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        self.collectionView.keyboardDismissMode = .onDrag
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
        self.searchBackground.translatesAutoresizingMaskIntoConstraints = false
        self.searchBackground.clipsToBounds = true
        self.searchBackground.layer.cornerCurve = .continuous
        self.view.addSubview(self.searchBackground)

        self.searchBar.translatesAutoresizingMaskIntoConstraints = false
        self.searchBar.searchBarStyle = .minimal
        self.searchBar.placeholder = "Search transactions"
        self.searchBar.autocorrectionType = .no
        self.searchBar.delegate = self
        // The blur capsule is the field's background, so drop the search bar's own.
        self.searchBar.searchTextField.backgroundColor = .clear
        self.searchBackground.contentView.addSubview(self.searchBar)

        let marginsGuide = self.view.layoutMarginsGuide
        let searchContent = self.searchBackground.contentView

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

            self.searchBackground.leadingAnchor.constraint(equalTo: marginsGuide.leadingAnchor),
            self.searchBackground.trailingAnchor.constraint(equalTo: marginsGuide.trailingAnchor),
            // The keyboard layout guide sits at the safe area bottom — above the tab
            // bar — while the keyboard is down, and rides the keyboard when it's up.
            self.searchBackground.bottomAnchor.constraint(
                equalTo: self.view.keyboardLayoutGuide.topAnchor,
                constant: -8
            ),

            self.searchBar.topAnchor.constraint(equalTo: searchContent.topAnchor),
            self.searchBar.leadingAnchor.constraint(equalTo: searchContent.leadingAnchor),
            self.searchBar.trailingAnchor.constraint(equalTo: searchContent.trailingAnchor),
            self.searchBar.bottomAnchor.constraint(equalTo: searchContent.bottomAnchor),
        ])

        self.apply(query: "", animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let searchHeight = self.searchBackground.bounds.height
        self.searchBackground.layer.cornerRadius = searchHeight / 2

        // Let the last row clear the floating search field.
        let bottomInset = searchHeight + 16
        if self.collectionView.contentInset.bottom != bottomInset {
            self.collectionView.contentInset.bottom = bottomInset
            self.collectionView.verticalScrollIndicatorInsets.bottom = bottomInset
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
        searchBar.resignFirstResponder()
    }
}
