import Foundation

// The transaction model only needs account identifiers. This stand-in lets its
// Foundation logic run without UIKit on Windows and macOS command-line Swift.
struct AccountPreview: Identifiable {
    let id: UUID
}

#if os(Windows)
extension URL {
    // Security-scoped access requires device verification, not a desktop stub.
    func startAccessingSecurityScopedResource() -> Bool { false }
    func stopAccessingSecurityScopedResource() {}
}
#endif
