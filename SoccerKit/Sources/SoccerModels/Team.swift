import Foundation

public typealias UserID = String
public typealias TeamID = String
public typealias GameID = String

/// A team's colors as hex strings ("#1E5AA8"), so they round-trip through Firestore unchanged.
public struct TeamColors: Codable, Hashable, Sendable {
    public var primary: String
    public var secondary: String

    public init(primary: String, secondary: String) {
        self.primary = primary
        self.secondary = secondary
    }
}

/// Defaults applied to each new game a team schedules.
public struct GameDefaults: Codable, Hashable, Sendable {
    public var periodCount: Int
    public var periodMinutes: Int

    public init(periodCount: Int = 2, periodMinutes: Int = 25) {
        self.periodCount = periodCount
        self.periodMinutes = periodMinutes
    }
}

public struct Team: Codable, Hashable, Identifiable, Sendable {
    public var id: TeamID
    public var name: String
    /// Three or so letters for the score bug, e.g. "FCB".
    public var shortName: String
    public var colors: TeamColors
    public var crestURL: URL?
    public var ownerId: UserID
    /// The team's current reusable fan code. Rotating it stops new fans joining with the old one.
    public var fanCode: String
    public var defaults: GameDefaults

    public init(
        id: TeamID,
        name: String,
        shortName: String,
        colors: TeamColors,
        crestURL: URL? = nil,
        ownerId: UserID,
        fanCode: String,
        defaults: GameDefaults = GameDefaults()
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.colors = colors
        self.crestURL = crestURL
        self.ownerId = ownerId
        self.fanCode = fanCode
        self.defaults = defaults
    }
}
