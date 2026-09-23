import UIKit

/// Rows laid out like the transactions list: the summary with details under it,
/// and the amount against the trailing edge.
enum RecurrenceRows {
    /// A repeat: when it next lands and how often, and what it next lands for.
    static func repeatRow(
        for item: RecurringTransaction, showsDisclosure: Bool = true,
        now: Date = .now, calendar: Calendar = .autoupdatingCurrent
    ) -> UITableViewCell {
        let next = item.plan.next(after: now, calendar: calendar)
        let details = next.map { "Next \(self.formatted($0.date, now: now, calendar: calendar)) · \($0.cadence.description)" }
            ?? "No more payments"
        return self.row(
            title: item.merchant, details: details,
            amount: (next?.amount ?? item.amount).formatted(.currency(code: "AUD")),
            showsDisclosure: showsDisclosure
        )
    }

    static func transactionRow(for transaction: Transaction, showsDisclosure: Bool = true) -> UITableViewCell {
        self.row(title: transaction.summary, details: transaction.formattedDate,
                 amount: transaction.formattedAmount, showsDisclosure: showsDisclosure)
    }

    /// `Tue 6 Oct`, with the year when it isn't this one.
    static func formatted(_ date: Date, now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> String {
        let format = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
        return calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? date.formatted(format) : date.formatted(format.year())
    }

    private static func row(title: String, details: String, amount: String, showsDisclosure: Bool) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = title
        // One line, cut with an ellipsis, as in the transactions list.
        content.textProperties.numberOfLines = 1
        content.textProperties.lineBreakMode = .byTruncatingTail
        content.secondaryText = details
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content

        // A table cell can't show an accessory view and the disclosure chevron
        // together, so the amount and the chevron share one view.
        let label = UILabel()
        label.text = amount
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        let accessory = UIStackView(arrangedSubviews: [label])
        accessory.alignment = .center
        accessory.spacing = 8
        if showsDisclosure {
            let chevron = UIImageView(image: UIImage(
                systemName: "chevron.forward",
                withConfiguration: UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
                    .applying(UIImage.SymbolConfiguration(weight: .semibold))
            ))
            chevron.tintColor = .tertiaryLabel
            accessory.addArrangedSubview(chevron)
        } else {
            cell.selectionStyle = .none
        }
        accessory.frame.size = accessory.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        cell.accessoryView = accessory
        cell.accessibilityLabel = "\(title), \(amount), \(details)"
        return cell
    }
}
