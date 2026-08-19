import Foundation

/// A recurring pay date. Dates are intentionally stored as calendar components,
/// rather than absolute `Date`s, so they keep their meaning in the user's locale.
struct PayCycle: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    /// Expected amount for one occurrence of this cycle.
    var amount: Decimal
    /// The transaction that the user associates with this cycle, if available.
    /// It is a stable backend-friendly identifier rather than embedded data.
    var linkedTransactionID: Transaction.ID?
    /// The account the pay lands in. A forecast for one account only counts the
    /// cycles paid into it; the net worth forecast counts them all.
    var accountID: AccountPreview.ID?
    var frequency: PayFrequency
    var rule: PayDateRule
    var businessDayAdjustment: BusinessDayAdjustment
    var stateOrTerritory: AustralianStateOrTerritory
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal = 0,
        linkedTransactionID: Transaction.ID? = nil,
        accountID: AccountPreview.ID? = nil,
        frequency: PayFrequency,
        rule: PayDateRule = .firstDay,
        businessDayAdjustment: BusinessDayAdjustment = .none,
        stateOrTerritory: AustralianStateOrTerritory = .newSouthWales,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.linkedTransactionID = linkedTransactionID
        self.accountID = accountID
        self.frequency = frequency
        self.rule = rule
        self.businessDayAdjustment = businessDayAdjustment
        self.stateOrTerritory = stateOrTerritory
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, amount, linkedTransactionID, accountID, frequency, rule, businessDayAdjustment, stateOrTerritory, isEnabled
    }

    /// Cycles saved before amount and account tracking were introduced remain
    /// usable; the editor asks for those when the user next saves one.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.amount = try container.decodeIfPresent(Decimal.self, forKey: .amount) ?? 0
        self.linkedTransactionID = try container.decodeIfPresent(Transaction.ID.self, forKey: .linkedTransactionID)
        self.accountID = try container.decodeIfPresent(AccountPreview.ID.self, forKey: .accountID)
        self.frequency = try container.decode(PayFrequency.self, forKey: .frequency)
        self.rule = try container.decode(PayDateRule.self, forKey: .rule)
        self.businessDayAdjustment = try container.decode(BusinessDayAdjustment.self, forKey: .businessDayAdjustment)
        self.stateOrTerritory = try container.decode(AustralianStateOrTerritory.self, forKey: .stateOrTerritory)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }
}

enum PayFrequency: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly

    var title: String { self.rawValue.capitalized }
}

/// `specific` uses weekday for weekly cycles, day for monthly cycles, and month
/// plus day for yearly cycles. A daily cycle always occurs every calendar day.
struct PayDateRule: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case firstDay
        case lastDay
        case specific

        var title: String {
            switch self {
            case .firstDay: "First day"
            case .lastDay: "Last day"
            case .specific: "Specific day"
            }
        }
    }

    var kind: Kind
    var weekday: Int?
    var day: Int?
    var month: Int?

    static let firstDay = PayDateRule(kind: .firstDay, weekday: nil, day: nil, month: nil)
    static let lastDay = PayDateRule(kind: .lastDay, weekday: nil, day: nil, month: nil)

    static func weekly(weekday: Int) -> PayDateRule {
        PayDateRule(kind: .specific, weekday: weekday, day: nil, month: nil)
    }

    static func monthly(day: Int) -> PayDateRule {
        PayDateRule(kind: .specific, weekday: nil, day: day, month: nil)
    }

    static func yearly(month: Int, day: Int) -> PayDateRule {
        PayDateRule(kind: .specific, weekday: nil, day: day, month: month)
    }
}

enum BusinessDayAdjustment: String, Codable, CaseIterable {
    case none
    case previousBusinessDay
    case nextBusinessDay

    var title: String {
        switch self {
        case .none: "Exact date"
        case .previousBusinessDay: "Move back"
        case .nextBusinessDay: "Move forward"
        }
    }
}

enum AustralianStateOrTerritory: String, Codable, CaseIterable {
    case australianCapitalTerritory
    case newSouthWales
    case northernTerritory
    case queensland
    case southAustralia
    case tasmania
    case victoria
    case westernAustralia

    var title: String {
        switch self {
        case .australianCapitalTerritory: "Australian Capital Territory"
        case .newSouthWales: "New South Wales"
        case .northernTerritory: "Northern Territory"
        case .queensland: "Queensland"
        case .southAustralia: "South Australia"
        case .tasmania: "Tasmania"
        case .victoria: "Victoria"
        case .westernAustralia: "Western Australia"
        }
    }
}
