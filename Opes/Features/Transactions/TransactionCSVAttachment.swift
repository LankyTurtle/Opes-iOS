import Foundation

enum TransactionCSVAttachment {
    static let maximumFileSize = 10 * 1_024 * 1_024

    static func readFile(at url: URL) throws -> Data {
        guard url.pathExtension.lowercased() == "csv" else {
            throw AttachmentError.invalidType
        }
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        // Bound the read itself as well as the picker type; provider metadata can be stale.
        let data = try file.read(upToCount: self.maximumFileSize + 1) ?? Data()
        guard !data.isEmpty else { throw AttachmentError.emptyFile }
        guard data.count <= self.maximumFileSize else { throw AttachmentError.tooLarge }
        return data
    }

    enum AttachmentError: LocalizedError {
        case invalidType, emptyFile, tooLarge

        var errorDescription: String? {
            switch self {
            case .invalidType: "Choose a file with a .csv extension."
            case .emptyFile: "This file is empty. Choose a CSV containing transactions."
            case .tooLarge: "Choose a CSV smaller than 10 MB."
            }
        }
    }
}
