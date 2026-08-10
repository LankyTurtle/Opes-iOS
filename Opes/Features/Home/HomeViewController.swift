import UIKit

final class HomeViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentRow = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemBackground

        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.scrollView)

        self.contentRow.translatesAutoresizingMaskIntoConstraints = false
        self.contentRow.axis = .horizontal
        self.contentRow.alignment = .center
        self.contentRow.spacing = 8
        self.scrollView.addSubview(self.contentRow)

        self.contentRow.addArrangedSubview(Self.makeLabel(text: "Text 1"))
        self.contentRow.addArrangedSubview(Self.makeLabel(text: "Text 2"))
        self.contentRow.addArrangedSubview(Self.makeSpacer())
        self.contentRow.addArrangedSubview(Self.makeLabel(text: "Text 3"))

        let contentLayoutGuide = self.scrollView.contentLayoutGuide
        let frameLayoutGuide = self.scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.contentRow.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            self.contentRow.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            self.contentRow.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            self.contentRow.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            self.contentRow.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
        ])
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
