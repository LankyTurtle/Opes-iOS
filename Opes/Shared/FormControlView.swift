import UIKit

/// Hosts a control on the grouped background between sections, aligned with the
/// section header above it rather than boxed in a row.
final class FormControlView: UIView {
    init(control: UIView) {
        super.init(frame: .zero)

        // A section header aligns to the table's own margins, so inheriting them
        // lines the control up with the title sitting above it.
        self.preservesSuperviewLayoutMargins = true

        control.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(control)

        // Breakable, so the height the table estimates for the footer never
        // conflicts with the height this resolves to.
        let bottom = control.bottomAnchor.constraint(
            equalTo: self.bottomAnchor,
            constant: -DesignTokens.titleSpacing
        )
        bottom.priority = .required - 1

        NSLayoutConstraint.activate([
            control.topAnchor.constraint(equalTo: self.topAnchor),
            control.leadingAnchor.constraint(equalTo: self.layoutMarginsGuide.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: self.layoutMarginsGuide.trailingAnchor),
            bottom,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
