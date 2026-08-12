import UIKit

final class BudgetsViewController: TabRootViewController {
    private enum Section {
        case overview
        case categories
    }

    private enum Item: Hashable {
        case overview
        case budget(BudgetPreview)
    }

    private let budgets = BudgetPreview.sample

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: Self.makeLayout()
    )

    private lazy var dataSource = self.makeDataSource()

    private var periodRefreshTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.titleLabel)

        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.backgroundColor = .clear
        self.collectionView.delegate = self
        self.view.addSubview(self.collectionView)

        let marginsGuide = self.view.layoutMarginsGuide

        NSLayoutConstraint.activate([
            self.titleLabel.topAnchor.constraint(
                equalTo: self.view.safeAreaLayoutGuide.topAnchor,
                constant: DesignTokens.titleTopInset
            ),
            self.titleLabel.leadingAnchor.constraint(equalTo: marginsGuide.leadingAnchor),
            self.titleLabel.trailingAnchor.constraint(equalTo: marginsGuide.trailingAnchor),

            self.collectionView.topAnchor.constraint(
                equalTo: self.titleLabel.bottomAnchor,
                constant: DesignTokens.titleSpacing
            ),
            self.collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])

        self.applySnapshot()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleSystemTimeChange(_:)),
            name: UIApplication.significantTimeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleSystemTimeChange(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.refreshPeriodTrackers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.startPeriodRefreshTimer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.periodRefreshTimer?.invalidate()
        self.periodRefreshTimer = nil
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.overview, .categories])
        snapshot.appendItems([.overview], toSection: .overview)
        snapshot.appendItems(self.budgets.map(Item.budget), toSection: .categories)
        self.dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func startPeriodRefreshTimer() {
        self.periodRefreshTimer?.invalidate()

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshPeriodTrackers()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.periodRefreshTimer = timer
    }

    /// Reconfiguring obtains a fresh `Date.now` for every visible tracker without
    /// changing the list's identity or animating its rows.
    private func refreshPeriodTrackers() {
        var snapshot = self.dataSource.snapshot()
        let items = snapshot.itemIdentifiers

        guard !items.isEmpty else {
            return
        }

        snapshot.reconfigureItems(items)
        self.dataSource.apply(snapshot, animatingDifferences: false)
    }

    @objc private func handleSystemTimeChange(_ notification: Notification) {
        self.refreshPeriodTrackers()
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
            [weak self] cell, _, item in
            guard let self else {
                return
            }

            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            cell.accessories = []

            let hostedView: UIView

            switch item {
            case .overview:
                let summaryView = BudgetSummaryView()
                summaryView.configure(with: self.budgets)
                hostedView = summaryView
            case let .budget(budget):
                let rowView = BudgetCategoryRowView()
                rowView.configure(with: budget)
                hostedView = rowView
            }

            hostedView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(hostedView)

            NSLayoutConstraint.activate([
                hostedView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                hostedView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                hostedView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            ])
        }

        return UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: self.collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: item
            )
        }
    }
}

extension BudgetsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        false
    }
}

private final class BudgetSummaryView: UIView {
    private let periodLabel = UILabel()
    private let remainingLabel = UILabel()
    private let spentLabel = UILabel()
    private let progressView = BudgetProgressView()
    private let explanationLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.periodLabel.font = .preferredFont(forTextStyle: .headline)
        self.periodLabel.adjustsFontForContentSizeCategory = true

        self.remainingLabel.font = DesignTokens.tileValueFont
        self.remainingLabel.adjustsFontForContentSizeCategory = true
        self.remainingLabel.numberOfLines = 0

        self.spentLabel.font = .preferredFont(forTextStyle: .subheadline)
        self.spentLabel.adjustsFontForContentSizeCategory = true
        self.spentLabel.textColor = .secondaryLabel
        self.spentLabel.numberOfLines = 0

        self.explanationLabel.font = .preferredFont(forTextStyle: .footnote)
        self.explanationLabel.adjustsFontForContentSizeCategory = true
        self.explanationLabel.textColor = .secondaryLabel
        self.explanationLabel.numberOfLines = 0
        self.explanationLabel.text = "The marker shows where today falls in the month. Spending updates automatically as transactions are categorised."

        let stack = UIStackView(arrangedSubviews: [
            self.periodLabel,
            self.remainingLabel,
            self.spentLabel,
            self.progressView,
            self.explanationLabel,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(DesignTokens.labelSpacing, after: self.remainingLabel)
        stack.setCustomSpacing(12, after: self.progressView)
        self.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: DesignTokens.cardPadding),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.cardPadding),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.cardPadding),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -DesignTokens.cardPadding),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with budgets: [BudgetPreview]) {
        let spent = budgets.reduce(Decimal.zero) { $0 + $1.spent }
        let limit = budgets.reduce(Decimal.zero) { $0 + $1.limit }
        let remaining = limit - spent
        let ratio = limit > 0
            ? NSDecimalNumber(decimal: spent / limit).floatValue
            : 0

        self.periodLabel.text = Date.now.formatted(.dateTime.month(.wide).year())
        self.remainingLabel.text = remaining >= 0
            ? "\(remaining.formatted(.currency(code: "AUD"))) remaining"
            : "\((-remaining).formatted(.currency(code: "AUD"))) over budget"
        self.remainingLabel.textColor = remaining >= 0 ? .label : .systemRed
        self.spentLabel.text = "\(spent.formatted(.currency(code: "AUD"))) spent of \(limit.formatted(.currency(code: "AUD")))"
        self.progressView.configure(
            spendingProgress: max(ratio, 0),
            periodUnit: .monthly
        )
    }
}

private final class BudgetCategoryRowView: UIView {
    private let iconView = UIImageView()
    private let categoryLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressView = BudgetProgressView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.iconView.contentMode = .scaleAspectFit
        self.iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)

        self.categoryLabel.font = .preferredFont(forTextStyle: .body)
        self.categoryLabel.adjustsFontForContentSizeCategory = true

        self.detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        self.detailLabel.adjustsFontForContentSizeCategory = true
        self.detailLabel.textColor = .secondaryLabel

        self.statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        self.statusLabel.adjustsFontForContentSizeCategory = true
        self.statusLabel.textAlignment = .right
        self.statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        self.statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let labelStack = UIStackView(arrangedSubviews: [self.categoryLabel, self.detailLabel])
        labelStack.axis = .vertical
        labelStack.spacing = DesignTokens.captionSpacing

        let headingStack = UIStackView(arrangedSubviews: [
            self.iconView,
            labelStack,
            self.statusLabel,
        ])
        headingStack.axis = .horizontal
        headingStack.alignment = .center
        headingStack.spacing = 12

        let stack = UIStackView(arrangedSubviews: [headingStack, self.progressView])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10
        self.addSubview(stack)

        NSLayoutConstraint.activate([
            self.iconView.widthAnchor.constraint(equalToConstant: 28),
            self.iconView.heightAnchor.constraint(equalToConstant: 28),

            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DesignTokens.cardPadding),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DesignTokens.cardPadding),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with budget: BudgetPreview) {
        self.iconView.image = UIImage(systemName: budget.category.symbolName)
        self.iconView.tintColor = budget.statusColor
        self.categoryLabel.text = budget.category.rawValue
        self.detailLabel.text = "\(budget.formattedSpent) of \(budget.formattedLimit) · \(budget.periodUnit.rawValue)"
        self.statusLabel.text = budget.formattedStatus
        self.statusLabel.textColor = budget.statusColor
        self.progressView.configure(
            spendingProgress: budget.progress,
            periodUnit: budget.periodUnit
        )
    }
}
