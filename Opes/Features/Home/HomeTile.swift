import Foundation

/// A card on Home. Doubles as the diffable section and item identifier, since each
/// tile is its own section and holds exactly one cell.
enum HomeTile: String, CaseIterable, Hashable, Identifiable {
    case availableBalance
    case budgets
    case recentTransactions

    var id: Self {
        self
    }

    /// Shown in the customise list, where the tile has no content to identify it.
    var title: String {
        switch self {
        case .availableBalance:
            return "Available Balance"
        case .budgets:
            return "Budgets"
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
            .compactMap { rawValue in
                // The custom tile is now the available-balance tile, retaining its
                // position in existing customised Home layouts.
                rawValue == "custom" ? .availableBalance : HomeTile(rawValue: rawValue)
            }

        let distinctStored = stored.reduce(into: [HomeTile]()) { tiles, tile in
            guard !tiles.contains(tile) else {
                return
            }

            tiles.append(tile)
        }

        return distinctStored + HomeTile.allCases.filter { !distinctStored.contains($0) }
    }

    static func save(_ order: [HomeTile], to defaults: UserDefaults = .standard) {
        defaults.set(order.map(\.rawValue), forKey: self.defaultsKey)
    }
}
