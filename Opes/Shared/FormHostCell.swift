import UIKit

/// A grouped-list row given over entirely to one view, for content that carries its
/// own layout — a chart, a summary — rather than a title and a control.
final class FormHostCell: UITableViewCell {
    init(view: UIView) {
        super.init(style: .default, reuseIdentifier: nil)

        self.selectionStyle = .none

        view.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(view)

        // Breakable, so the estimated row height the table starts from never
        // conflicts with the height this resolves to.
        let bottom = view.bottomAnchor.constraint(
            equalTo: self.contentView.layoutMarginsGuide.bottomAnchor
        )
        bottom.priority = .required - 1

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.topAnchor),
            view.leadingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),
            bottom,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
