import UIKit

/// Net worth, or one account's balance, projected forward from the user's pay
/// cycles and their recent spending.
///
/// Both subjects are the same screen because they answer the same question with
/// the same arithmetic — only the balance being carried forward, the income
/// counted, and the transactions averaged differ.
final class ForecastViewController: UITableViewController {
    enum Subject {
        /// Every account tallied into one position.
        case netWorth
        case account(AccountPreview)

        var title: String {
            switch self {
            case .netWorth: "Net Worth"
            case .account(let account): account.name
            }
        }

        var summaryTitle: String {
            switch self {
            case .netWorth: "Total across all accounts"
            case .account(let account): account.institution
            }
        }
    }

    private let subject: Subject
    private let accountProvider: any AccountProviding
    private let transactionProvider: any TransactionProviding
    private let payCycleStore: PayCycleStore
    private let forecaster = BalanceForecaster()

    private var horizon = ForecastHorizon.default
    private var forecast = Forecast.empty(horizon: .default)
    private var sections: [ForecastSection] = []

    private let summaryView = ForecastSummaryView()
    private let chartView = ForecastChartView()
    private let horizonControl = UISegmentedControl(
        items: ForecastHorizon.allCases.map(\.title)
    )

    private let incomeLabel = ForecastViewController.makeValueLabel()
    private let spendingLabel = ForecastViewController.makeValueLabel()
    private let netLabel = ForecastViewController.makeValueLabel()

    private lazy var summaryRow = FormHostCell(view: self.summaryView)
    private lazy var chartRow = FormHostCell(view: self.chartView)
    private lazy var horizonControlView = FormControlView(control: self.horizonControl)

    private lazy var incomeRow = FormRowCell(
        title: "Expected pay",
        control: self.incomeLabel,
        stretchesControl: true
    )
    private lazy var spendingRow = FormRowCell(
        title: "Average spending",
        control: self.spendingLabel,
        stretchesControl: true
    )
    private lazy var netRow = FormRowCell(
        title: "Net each month",
        control: self.netLabel,
        stretchesControl: true
    )

    /// Built once: the accounts a net worth forecast is made of, each a way into
    /// its own forecast.
    private lazy var accountRows: [(cell: UITableViewCell, account: AccountPreview)] =
        self.accountProvider.accounts().map { account in
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            var content = UIListContentConfiguration.valueCell()
            content.text = account.name
            content.secondaryText = account.formattedBalance
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return (cell, account)
        }

    init(
        subject: Subject,
        accountProvider: any AccountProviding = SampleAccountProvider(),
        transactionProvider: any TransactionProviding = SampleTransactionProvider(),
        payCycleStore: PayCycleStore = .shared
    ) {
        self.subject = subject
        self.accountProvider = accountProvider
        self.transactionProvider = transactionProvider
        self.payCycleStore = payCycleStore
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = self.subject.title

        self.horizonControl.selectedSegmentIndex =
            ForecastHorizon.allCases.firstIndex(of: self.horizon) ?? 0
        self.horizonControl.addAction(
            UIAction { [weak self] _ in
                self?.horizonChanged()
            },
            for: .valueChanged
        )

        // The forecast first, so the sections are built against numbers that are
        // already in place rather than reloaded a moment later.
        self.updateForecast()
        self.buildSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // A pay cycle edited elsewhere changes the projection, so it is recomputed
        // on the way back in rather than held from when the screen was built.
        self.updateForecast()
    }

    private func buildSections() {
        var sections: [ForecastSection] = [
            ForecastSection(rows: [self.summaryRow]),
            ForecastSection(header: "Forecast", control: self.horizonControlView),
            ForecastSection(rows: [self.chartRow]),
            ForecastSection(
                header: "Assumptions",
                rows: [self.incomeRow, self.spendingRow, self.netRow],
                carriesAssumptionsFooter: true
            ),
        ]

        if case .netWorth = self.subject {
            sections.append(
                ForecastSection(header: "Accounts", rows: self.accountRows.map(\.cell))
            )
        }

        self.sections = sections
        self.tableView.reloadData()
    }

    private func horizonChanged() {
        self.horizon = ForecastHorizon.allCases[self.horizonControl.selectedSegmentIndex]
        self.updateForecast()
    }

    /// Recomputes from whatever the stores hold now and pushes the result into the
    /// long-lived views, so nothing but the assumptions footer needs reloading.
    private func updateForecast() {
        let transactions = self.transactionProvider.transactions()
        let cycles = self.payCycleStore.load()

        let startingBalance: Decimal
        let spending: SpendingPattern
        let payCycles: [PayCycle]

        switch self.subject {
        case .netWorth:
            startingBalance = self.accountProvider.accounts()
                .reduce(Decimal.zero) { $0 + $1.balance }
            spending = SpendingPattern.make(from: transactions)
            payCycles = cycles

        case .account(let account):
            startingBalance = account.balance
            spending = SpendingPattern.make(from: transactions, for: account.id)
            // Only the pay the user has told us lands here. A cycle with no account
            // set feeds the net worth forecast but no single account's.
            payCycles = cycles.filter { $0.accountID == account.id }
        }

        self.forecast = self.forecaster.forecast(
            startingBalance: startingBalance,
            payCycles: payCycles,
            spending: spending,
            over: self.horizon
        )

        self.summaryView.show(title: self.subject.summaryTitle, forecast: self.forecast)

        self.chartView.accentColor = Self.accentColor(for: self.forecast)
        self.chartView.show(self.forecast, placeholder: "Not enough information to draw a forecast yet.")
        self.chartView.accessibilityLabel = Self.chartDescription(for: self.forecast)

        self.incomeLabel.text = ForecastFormatter.currency(self.forecast.monthlyIncome)
        self.spendingLabel.text = ForecastFormatter.currency(self.forecast.monthlySpending)
        self.netLabel.text = ForecastFormatter.signedCurrency(self.forecast.monthlyNet)
        self.netLabel.textColor = self.forecast.monthlyNet < 0 ? .systemRed : .systemTeal

        self.reloadAssumptionsFooter()
    }

    /// The footer is the only part that isn't a long-lived view, so it is the only
    /// part a horizon change has to reload.
    private func reloadAssumptionsFooter() {
        guard
            let section = self.sections.firstIndex(where: \.carriesAssumptionsFooter),
            self.tableView.numberOfSections > section
        else {
            return
        }

        self.tableView.reloadSections(IndexSet(integer: section), with: .none)
    }

    private static func accentColor(for forecast: Forecast) -> UIColor {
        if forecast.shortfallDate != nil {
            return .systemRed
        }

        return forecast.change < 0 ? .systemOrange : .systemTeal
    }

    private static func chartDescription(for forecast: Forecast) -> String {
        guard !forecast.points.isEmpty else {
            return "Forecast chart. Not enough information to draw a forecast yet."
        }

        return """
            Forecast chart. From \(ForecastFormatter.currency(forecast.startingBalance)) today \
            to \(ForecastFormatter.currency(forecast.projectedBalance)) in \(forecast.horizon.description).
            """
    }

    /// Says what the projection rests on, so the numbers above it can be judged.
    private var assumptionsFooter: String {
        var notes: [String] = []

        if self.forecast.spending.hasHistory {
            let days = self.forecast.spending.observedDays
            notes.append(
                "Spending is the daily average of the last \(days) \(days == 1 ? "day" : "days") of transactions, carried forward."
            )
        } else {
            notes.append("No spending recorded yet, so the projection moves on pay alone.")
        }

        if self.forecast.expectedIncome == 0 {
            switch self.subject {
            case .netWorth:
                notes.append("Add a pay cycle to include income.")
            case .account:
                notes.append("No pay cycle is paid into this account, so no income is counted.")
            }
        }

        if let shortfall = self.forecast.shortfallDate {
            notes.append(
                "At this rate the balance falls below zero on \(shortfall.formatted(date: .abbreviated, time: .omitted))."
            )
        }

        return notes.joined(separator: " ")
    }

    private static func makeValueLabel() -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.sections[section].rows.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        self.sections[indexPath.section].rows[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        self.sections[section].header
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        self.sections[section].carriesAssumptionsFooter ? self.assumptionsFooter : nil
    }

    /// A section carrying a control has no rows, so its footer is where the control
    /// lands: on the background, directly under its own header.
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        self.sections[section].control
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = self.sections[indexPath.section].rows[indexPath.row]
        guard let account = self.accountRows.first(where: { $0.cell === row })?.account else {
            return
        }

        self.navigationController?.pushViewController(
            ForecastViewController(
                subject: .account(account),
                accountProvider: self.accountProvider,
                transactionProvider: self.transactionProvider,
                payCycleStore: self.payCycleStore
            ),
            animated: true
        )
    }
}

private struct ForecastSection {
    var header: String?
    var rows: [UITableViewCell] = []
    /// Shown under the header on the plain background, in place of any rows.
    var control: UIView?
    /// The footer explaining what the projection assumes, which changes with the
    /// horizon and so is built when the table asks for it.
    var carriesAssumptionsFooter = false
}
