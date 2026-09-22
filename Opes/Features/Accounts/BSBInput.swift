import Foundation

/// Keeps a BSB field in the `062-000` form as the user types: digits only, at
/// most six, with the hyphen added once the fourth digit goes in.
enum BSBInput {
    /// Applies a text field edit and returns the formatted text, with the caret
    /// as a UTF-16 offset so it stays beside the digit the user was editing.
    static func edit(_ text: String, range: NSRange, replacement: String) -> (text: String, cursor: Int) {
        let current = text as NSString
        var range = range
        // Backspacing over the hyphen alone would change nothing once it's put
        // back, so it takes the digit before it too.
        if replacement.isEmpty, range.length == 1, range.location > 0, current.substring(with: range) == "-" {
            range = NSRange(location: range.location - 1, length: 2)
        }
        let proposed = current.replacingCharacters(in: range, with: replacement)
        let caret = range.location + (replacement as NSString).length
        let digitsBeforeCaret = Self.digits((proposed as NSString).substring(to: caret)).count

        let digits = String(Self.digits(proposed).prefix(6))
        let formatted = digits.count > 3 ? "\(digits.prefix(3))-\(digits.dropFirst(3))" : digits
        let caretDigits = min(digitsBeforeCaret, digits.count)
        return (formatted, caretDigits + (caretDigits > 3 ? 1 : 0))
    }

    private static func digits(_ text: String) -> String {
        text.filter { ("0"..."9").contains($0) }
    }
}
