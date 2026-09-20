import Foundation

// The transaction model only needs account identifiers. This stand-in lets its
// Foundation logic run without UIKit on Windows and macOS command-line Swift.
struct AccountPreview: Identifiable {
    let id: UUID
    static let everydayAccess = Self(id: UUID())
    static let bills = Self(id: UUID())
    static let savingsMaximiser = Self(id: UUID())
    static let spending = Self(id: UUID())
    static let platinumCard = Self(id: UUID())
}

#if os(Windows)
extension URL {
    // Security-scoped access requires device verification, not a desktop stub.
    func startAccessingSecurityScopedResource() -> Bool { false }
    func stopAccessingSecurityScopedResource() {}
}
#endif
