import Foundation

/// A card on Home. Doubles as the diffable section and item identifier, since each
/// tile is its own section and holds exactly one cell.
enum HomeTile: String, CaseIterable, Hashable, Identifiable {
    case balance
    case custom
    case recentTransactions

    var id: Self {
        self
    }

    /// Shown in the customise list, where the tile has no content to identify it.
    var title: String {
        switch self {
        case .balance:
            return "Available Balance"
        case .custom:
            return "Custom"
        case .recentTransactions:
            return "Recent Transactions"
        }
    }
}

enum HomeTileOrder {
    private static let defaultsKey = "home.tileOrder"

    /// Reconciles the stored order against the tiles that actually exist, so a tile
    /// added in a later build appears at the end rather than never appearing, and a
    /// removed one drops out rather than lingering as a dead identifier.
    static func load(from defaults: UserDefaults = .standard) -> [HomeTile] {
        let stored = (defaults.array(forKey: self.defaultsKey) as? [String] ?? [])
            .compactMap(HomeTile.init(rawValue:))

        return stored + HomeTile.allCases.filter { !stored.contains($0) }
    }

    static func save(_ order: [HomeTile], to defaults: UserDefaults = .standard) {
        defaults.set(order.map(\.rawValue), forKey: self.defaultsKey)
    }
}
