import Foundation

struct Account: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let institution: String
    let balance: Decimal
}
