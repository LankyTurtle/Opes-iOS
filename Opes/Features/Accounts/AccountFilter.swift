import Foundation

/// Narrows the account list by type and institution. Choices within one
/// criterion widen the match (Transaction or Savings); choices across criteria
/// narrow it (Transaction and Macquarie). An empty criterion matches everything.
struct AccountFilter: Equatable {
    private(set) var types: Set<AccountType> = []
    /// Keys from `institutionKey(_:)`, so "Macquarie" and "macquarie " match.
    private(set) var institutions: Set<String> = []

    var isActive: Bool { !self.types.isEmpty || !self.institutions.isEmpty }

    static func institutionKey(_ institution: String) -> String {
        institution.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    func matches(type: AccountType, institution: String) -> Bool {
        (self.types.isEmpty || self.types.contains(type))
            && (self.institutions.isEmpty || self.institutions.contains(Self.institutionKey(institution)))
    }

    func contains(institution: String) -> Bool {
        self.institutions.contains(Self.institutionKey(institution))
    }

    /// Drops choices no remaining account has, so a filter can't stay active
    /// with nothing left in the menu to turn it off.
    mutating func removeUnavailable(types: Set<AccountType>, institutions: [String]) {
        self.types.formIntersection(types)
        self.institutions.formIntersection(institutions.map(Self.institutionKey))
    }

    mutating func toggle(_ type: AccountType) {
        if self.types.remove(type) == nil { self.types.insert(type) }
    }

    mutating func toggle(institution: String) {
        let key = Self.institutionKey(institution)
        if self.institutions.remove(key) == nil { self.institutions.insert(key) }
    }
}
