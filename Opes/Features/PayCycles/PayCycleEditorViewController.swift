import UIKit

final class PayCycleEditorViewController: UIViewController {
    private let existingCycle: PayCycle?
    private let onSave: (PayCycle) -> Void
    private let calculator = NextPayDateCalculator()

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let nameField = UITextField()
    private let frequencyControl = UISegmentedControl(items: PayFrequency.allCases.map(\.title))
    private let ruleControl = UISegmentedControl(items: ["First", "Last", "Specific"])
    private let weekdayButton = UIButton(type: .system)
    private let datePicker = UIDatePicker()
    private let adjustmentControl = UISegmentedControl(items: ["Exact", "Back", "Forward"])
    private let stateButton = UIButton(type: .system)
    private let enabledSwitch = UISwitch()
    private let previewLabel = UILabel()

    private var frequency: PayFrequency
    private var rule: PayDateRule
    private var adjustment: BusinessDayAdjustment
    private var state: AustralianStateOrTerritory
    private var weekday: Int

    init(cycle: PayCycle?, onSave: @escaping (PayCycle) -> Void) {
        self.existingCycle = cycle
        self.onSave = onSave
        self.frequency = cycle?.frequency ?? .monthly
        self.rule = cycle?.rule ?? .firstDay
        self.adjustment = cycle?.businessDayAdjustment ?? .none
        self.state = cycle?.stateOrTerritory ?? .newSouthWales
        self.weekday = cycle?.rule.weekday ?? Calendar.autoupdatingCurrent.firstWeekday
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = self.existingCycle == nil ? "Add Pay Cycle" : "Edit Pay Cycle"
        self.view.backgroundColor = .systemGroupedBackground
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(self.save)
        )

        self.configureLayout()
        self.configureControls()
        self.refreshForm()
    }

    private func configureLayout() {
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.stack.translatesAutoresizingMaskIntoConstraints = false
        self.stack.axis = .vertical
        self.stack.spacing = 20
        self.stack.isLayoutMarginsRelativeArrangement = true
        self.stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 32, trailing: 20)
        self.view.addSubview(self.scrollView)
        self.scrollView.addSubview(self.stack)

        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.stack.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor),
            self.stack.leadingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.leadingAnchor),
            self.stack.trailingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.trailingAnchor),
            self.stack.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor),
        ])
    }

    private func configureControls() {
        self.nameField.placeholder = "For example, Salary"
        self.nameField.text = self.existingCycle?.name
        self.nameField.borderStyle = .roundedRect
        self.nameField.autocapitalizationType = .words

        self.frequencyControl.selectedSegmentIndex = PayFrequency.allCases.firstIndex(of: self.frequency) ?? 2
        self.frequencyControl.addTarget(self, action: #selector(self.frequencyChanged), for: .valueChanged)

        self.ruleControl.selectedSegmentIndex = switch self.rule.kind {
        case .firstDay: 0
        case .lastDay: 1
        case .specific: 2
        }
        self.ruleControl.addTarget(self, action: #selector(self.ruleChanged), for: .valueChanged)

        self.datePicker.datePickerMode = .date
        self.datePicker.preferredDatePickerStyle = .compact
        self.datePicker.addTarget(self, action: #selector(self.dateChanged), for: .valueChanged)
        if let month = self.rule.month, let day = self.rule.day {
            self.datePicker.date = Calendar.autoupdatingCurrent.date(from: DateComponents(year: 2024, month: month, day: day)) ?? .now
        } else if let day = self.rule.day {
            self.datePicker.date = Calendar.autoupdatingCurrent.date(from: DateComponents(year: 2024, month: 1, day: day)) ?? .now
        }

        self.adjustmentControl.selectedSegmentIndex = BusinessDayAdjustment.allCases.firstIndex(of: self.adjustment) ?? 0
        self.adjustmentControl.addTarget(self, action: #selector(self.adjustmentChanged), for: .valueChanged)
        self.enabledSwitch.isOn = self.existingCycle?.isEnabled ?? true
        self.enabledSwitch.addTarget(self, action: #selector(self.previewChanged), for: .valueChanged)

        self.previewLabel.font = .preferredFont(forTextStyle: .body)
        self.previewLabel.adjustsFontForContentSizeCategory = true
        self.previewLabel.textColor = .secondaryLabel
        self.previewLabel.numberOfLines = 0
    }

    private func refreshForm() {
        self.stack.arrangedSubviews.forEach {
            self.stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        self.stack.addArrangedSubview(self.makeField(title: "Name", control: self.nameField))
        self.stack.addArrangedSubview(self.makeField(title: "Frequency", control: self.frequencyControl))

        if self.frequency != .daily {
            self.stack.addArrangedSubview(self.makeField(title: "When", control: self.ruleControl))
            if self.ruleControl.selectedSegmentIndex == 2 {
                switch self.frequency {
                case .weekly:
                    self.configureWeekdayButton()
                    self.stack.addArrangedSubview(self.makeField(title: "Weekday", control: self.weekdayButton))
                case .monthly:
                    self.stack.addArrangedSubview(self.makeField(title: "Day of month", control: self.datePicker))
                case .yearly:
                    self.stack.addArrangedSubview(self.makeField(title: "Month and day", control: self.datePicker))
                case .daily:
                    break
                }
            }
        }

        self.stack.addArrangedSubview(self.makeField(title: "If weekend or public holiday", control: self.adjustmentControl))
        if self.adjustment != .none {
            self.configureStateButton()
            self.stack.addArrangedSubview(self.makeField(title: "Public holiday calendar", control: self.stateButton))
        }
        self.stack.addArrangedSubview(self.makeField(title: "Enabled", control: self.enabledSwitch))
        self.updatePreview()
        self.stack.addArrangedSubview(self.previewLabel)
    }

    private func makeField(title: String, control: UIView) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }

    private func configureWeekdayButton() {
        self.weekdayButton.showsMenuAsPrimaryAction = true
        self.weekdayButton.menu = UIMenu(children: (1...7).map { weekday in
            UIAction(title: Self.weekdayName(weekday), state: weekday == self.weekday ? .on : .off) { [weak self] _ in
                self?.weekday = weekday
                self?.refreshForm()
            }
        })
        self.weekdayButton.setTitle(Self.weekdayName(self.weekday), for: .normal)
        self.weekdayButton.contentHorizontalAlignment = .leading
    }

    private func configureStateButton() {
        self.stateButton.showsMenuAsPrimaryAction = true
        self.stateButton.menu = UIMenu(children: AustralianStateOrTerritory.allCases.map { state in
            UIAction(title: state.title, state: state == self.state ? .on : .off) { [weak self] _ in
                self?.state = state
                self?.refreshForm()
            }
        })
        self.stateButton.setTitle(self.state.title, for: .normal)
        self.stateButton.contentHorizontalAlignment = .leading
    }

    private func updatePreview() {
        let cycle = self.makeCycle(name: self.nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Pay")
        guard let display = self.calculator.display(for: cycle) else {
            self.previewLabel.text = "No upcoming pay date could be calculated."
            return
        }
        self.previewLabel.text = "Next pay: \(display.countdown), \(display.date.formatted(date: .complete, time: .omitted))"
    }

    private func makeCycle(name: String) -> PayCycle {
        let rule: PayDateRule
        switch self.frequency {
        case .daily:
            rule = .firstDay
        case .weekly:
            rule = self.ruleControl.selectedSegmentIndex == 2 ? .weekly(weekday: self.weekday) : self.boundaryRule()
        case .monthly:
            rule = self.ruleControl.selectedSegmentIndex == 2
                ? .monthly(day: Calendar.autoupdatingCurrent.component(.day, from: self.datePicker.date))
                : self.boundaryRule()
        case .yearly:
            let components = Calendar.autoupdatingCurrent.dateComponents([.month, .day], from: self.datePicker.date)
            rule = self.ruleControl.selectedSegmentIndex == 2
                ? .yearly(month: components.month ?? 1, day: components.day ?? 1)
                : self.boundaryRule()
        }
        return PayCycle(
            id: self.existingCycle?.id ?? UUID(),
            name: name,
            frequency: self.frequency,
            rule: rule,
            businessDayAdjustment: self.adjustment,
            stateOrTerritory: self.state,
            isEnabled: self.enabledSwitch.isOn
        )
    }

    private func boundaryRule() -> PayDateRule {
        self.ruleControl.selectedSegmentIndex == 1 ? .lastDay : .firstDay
    }

    @objc private func frequencyChanged() {
        self.frequency = PayFrequency.allCases[self.frequencyControl.selectedSegmentIndex]
        self.refreshForm()
    }

    @objc private func ruleChanged() {
        self.refreshForm()
    }

    @objc private func dateChanged() {
        self.updatePreview()
    }

    @objc private func adjustmentChanged() {
        self.adjustment = BusinessDayAdjustment.allCases[self.adjustmentControl.selectedSegmentIndex]
        self.refreshForm()
    }

    @objc private func previewChanged() {
        self.updatePreview()
    }

    @objc private func save() {
        let name = self.nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else {
            let alert = UIAlertController(title: "Name required", message: "Give this pay cycle a name so you can recognise it on Home.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        self.onSave(self.makeCycle(name: name))
        self.navigationController?.popViewController(animated: true)
    }

    private static func weekdayName(_ weekday: Int) -> String {
        Calendar.autoupdatingCurrent.weekdaySymbols[weekday - 1]
    }
}
