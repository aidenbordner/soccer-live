import Foundation

public enum Side: String, Codable, Sendable {
    case us
    case them
}

public enum HomeAway: String, Codable, Sendable {
    case home
    case away
}

public enum GameStatus: String, Codable, Sendable {
    case scheduled
    case live
    /// Between periods: halftime in a two-half game, a quarter break otherwise.
    case intermission
    case final
}

public struct Opponent: Codable, Hashable, Sendable {
    public var name: String
    public var shortName: String
    public var colors: TeamColors?

    public init(name: String, shortName: String, colors: TeamColors? = nil) {
        self.name = name
        self.shortName = shortName
        self.colors = colors
    }
}

public struct Score: Codable, Hashable, Sendable {
    public var us: Int
    public var them: Int

    public init(us: Int = 0, them: Int = 0) {
        self.us = us
        self.them = them
    }

    public subscript(side: Side) -> Int {
        get { side == .us ? us : them }
        set {
            if side == .us { us = newValue } else { them = newValue }
        }
    }
}

/// One game, stored at `games/{gameId}`. Score and clock live here so a fan's screen needs one listener;
/// the event log under it is the history behind them.
public struct Game: Codable, Hashable, Identifiable, Sendable {
    public var id: GameID
    public var teamId: TeamID
    public var opponent: Opponent
    public var homeAway: HomeAway
    public var venue: String?
    public var scheduledAt: Date
    public var status: GameStatus
    /// 1-based once the game kicks off; 0 before.
    public var period: Int
    public var periodCount: Int
    public var periodMinutes: Int
    public var clock: ClockState
    public var score: Score
    public var updatedAt: Date
    public var updatedBy: UserID?

    public init(
        id: GameID,
        teamId: TeamID,
        opponent: Opponent,
        homeAway: HomeAway,
        venue: String? = nil,
        scheduledAt: Date,
        defaults: GameDefaults = GameDefaults(),
        createdAt: Date
    ) {
        self.id = id
        self.teamId = teamId
        self.opponent = opponent
        self.homeAway = homeAway
        self.venue = venue
        self.scheduledAt = scheduledAt
        self.status = .scheduled
        self.period = 0
        self.periodCount = defaults.periodCount
        self.periodMinutes = defaults.periodMinutes
        self.clock = .stopped
        self.score = Score()
        self.updatedAt = createdAt
    }

    public var periodLength: TimeInterval { TimeInterval(periodMinutes * 60) }

    public var isPaused: Bool { status == .live && !clock.running }

    /// Seconds into the whole match, so the second half of a 25-minute-half game starts at 25:00.
    public func matchTime(at now: Date) -> TimeInterval {
        let completedPeriods = max(0, period - 1)
        return TimeInterval(completedPeriods) * periodLength + clock.elapsed(at: now)
    }

    /// The short state label for the score bug.
    public var statusLabel: String {
        switch status {
        case .scheduled: "UPCOMING"
        case .live: clock.running ? "LIVE" : "PAUSED"
        case .intermission: periodCount == 2 && period == 1 ? "HT" : "END Q\(period)"
        case .final: "FT"
        }
    }
}
