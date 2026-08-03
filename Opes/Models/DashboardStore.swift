import Combine
import Foundation
import SwiftUI

enum DashboardTile: String, CaseIterable, Hashable, Identifiable {
    case totalBalance
    case monthlyBudget
    case recentActivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .totalBalance: "Total balance"
        case .monthlyBudget: "Monthly budget"
        case .recentActivity: "Recent activity"
        }
    }

    var icon: String {
        switch self {
        case .totalBalance: "dollarsign.circle"
        case .monthlyBudget: "chart.pie"
        case .recentActivity: "clock.arrow.circlepath"
        }
    }
}

@MainActor
final class DashboardStore: ObservableObject {
    @Published private(set) var visibleTiles: [DashboardTile] {
        didSet { persistSelection() }
    }

    private let defaults: UserDefaults
    private let storageKey = "dashboard.visibleTiles"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let storedValues = defaults.stringArray(forKey: storageKey) {
            var seen = Set<DashboardTile>()
            visibleTiles = storedValues
                .compactMap(DashboardTile.init(rawValue:))
                .filter { seen.insert($0).inserted }
        } else {
            visibleTiles = DashboardTile.allCases
        }
    }

    func isVisible(_ tile: DashboardTile) -> Bool {
        visibleTiles.contains(tile)
    }

    func setVisible(_ tile: DashboardTile, isVisible: Bool) {
        if isVisible, !visibleTiles.contains(tile) {
            visibleTiles.append(tile)
        } else if !isVisible {
            visibleTiles.removeAll { $0 == tile }
        }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        visibleTiles.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    private func persistSelection() {
        defaults.set(visibleTiles.map(\.rawValue), forKey: storageKey)
    }
}
