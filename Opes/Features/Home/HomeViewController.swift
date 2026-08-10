import UIKit

final class HomeViewController: TabRootViewController {
    private let scrollView = UIScrollView()
    private let contentColumn = UIStackView()
    private let contentRow = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.scrollView)

        self.contentColumn.translatesAutoresizingMaskIntoConstraints = false
        self.contentColumn.axis = .vertical
        self.contentColumn.spacing = 8
        self.contentColumn.isLayoutMarginsRelativeArrangement = true
        self.contentColumn.directionalLayoutMargins.top = 8
        self.scrollView.addSubview(self.contentColumn)

        self.contentRow.axis = .horizontal
        self.contentRow.alignment = .center
        self.contentRow.spacing = 8

        self.contentRow.addArrangedSubview(Self.makeLabel(text: "Text 1"))
        self.contentRow.addArrangedSubview(Self.makeLabel(text: "Text 2"))
        self.contentRow.addArrangedSubview(Self.makeSpacer())
        self.contentRow.addArrangedSubview(Self.makeLabel(text: "Text 3"))

        // The title scrolls away with the content rather than staying pinned.
        self.contentColumn.addArrangedSubview(self.titleLabel)
        self.contentColumn.addArrangedSubview(self.contentRow)

        let contentLayoutGuide = self.scrollView.contentLayoutGuide
        let frameLayoutGuide = self.scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.contentColumn.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            self.contentColumn.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            self.contentColumn.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            self.contentColumn.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            self.contentColumn.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
        ])
    }

    /// Keeps the content inset in step with the system's readable margins, which
    /// vary by device width.
    override func viewLayoutMarginsDidChange() {
        super.viewLayoutMarginsDidChange()

        self.contentColumn.directionalLayoutMargins.leading = self.view.directionalLayoutMargins.leading
        self.contentColumn.directionalLayoutMargins.trailing = self.view.directionalLayoutMargins.trailing
    }

    private static func makeLabel(text: String) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    /// Stands in for a SwiftUI `Spacer`: soaks up whatever width the labels leave.
    private static func makeSpacer() -> UIView {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return spacer
    }
}
