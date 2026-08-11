import UIKit

/// Reorderable list of Home's tiles.
///
/// Home gives every tile its own section so each draws as a separate grouped card,
/// and sections can't be dragged — only items can. So the reordering happens here
/// instead, on a plain single-section list where it's the native behaviour, and Home
/// re-lays its sections out from the result.
final class CustomiseHomeViewController: UIViewController {
    private enum Section {
        case main
    }

    private var order: [HomeTile]
    private let onChange: ([HomeTile]) -> Void

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: Self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

    init(order: [HomeTile], onChange: @escaping ([HomeTile]) -> Void) {
        self.order = order
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Customise Home"
        self.view.backgroundColor = .systemGroupedBackground
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(self.handleDone)
        )

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        // Editing mode alongside an always-displayed handle, so the grip shows and
        // drags without the caller having to toggle anything.
        self.collectionView.isEditing = true
        self.view.addSubview(self.collectionView)

        NSLayoutConstraint.activate([
            self.collectionView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])

        self.configureReordering()
        self.apply(order: self.order, animated: false)
    }

    @objc private func handleDone() {
        self.dismiss(animated: true)
    }

    private func configureReordering() {
        self.dataSource.reorderingHandlers.canReorderItem = { _ in
            true
        }

        self.dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            guard let self else {
                return
            }

            self.order = transaction.finalSnapshot.itemIdentifiers
            self.onChange(self.order)
        }
    }

    private func apply(order: [HomeTile], animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, HomeTile>()
        snapshot.appendSections([.main])
        snapshot.appendItems(order, toSection: .main)
        self.dataSource.apply(snapshot, animatingDifferences: animated)
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, HomeTile> {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, HomeTile> {
            cell, _, tile in
            var content = UIListContentConfiguration.cell()
            content.text = tile.title
            cell.contentConfiguration = content
            cell.accessories = [.reorder(displayed: .always)]
        }

        return UICollectionViewDiffableDataSource<Section, HomeTile>(
            collectionView: self.collectionView
        ) { collectionView, indexPath, tile in
            collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: tile
            )
        }
    }
}
