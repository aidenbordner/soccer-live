import Foundation

public enum GameEventType: String, Codable, Sendable {
    case kickoff
    case goal
    case pause
    case resume
    case periodEnd
    case periodStart
    case final
    /// Undoes an earlier goal. History is append-only, so a mistaken tap is corrected, never erased.
    case correction
}

/// One entry in a game's log, stored at `games/{gameId}/events/{eventId}`.
public struct GameEvent: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var type: GameEventType
    public var side: Side?
    /// First name or jersey number only.
    public var scorer: String?
    public var period: Int
    /// Seconds into the whole match when it happened.
    public var matchSecond: Int
    public var createdAt: Date
    public var createdBy: UserID
    public var correctsEventId: String?

    public init(
        id: String = UUID().uuidString,
        type: GameEventType,
        side: Side? = nil,
        scorer: String? = nil,
        period: Int,
        matchSecond: Int,
        createdAt: Date,
        createdBy: UserID,
        correctsEventId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.side = side
        self.scorer = scorer
        self.period = period
        self.matchSecond = matchSecond
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.correctsEventId = correctsEventId
    }

    public var minuteMarker: String { MatchClock.minuteMarker(TimeInterval(matchSecond)) }
}

/// Something an admin does from the Sideline tab.
public enum GameAction: Hashable, Sendable {
    case kickoff
    case pause
    case resume
    case goal(Side, scorer: String? = nil)
    /// Ends the current period. Ending the last period ends the game.
    case endPeriod
    case startNextPeriod
    /// Undoes a goal event.
    case correct(GameEvent)
}

public enum GameActionError: Error, Equatable, Sendable {
    case notAllowed(GameAction, GameStatus)
    case notAGoal
}

extension Game {
    /// Applies an admin action, returning the event to append to the log.
    ///
    /// The caller writes the updated game and the event together in one batch, so fans never see
    /// a score without its event or the reverse.
    public mutating func apply(_ action: GameAction, at now: Date, by user: UserID) throws -> GameEvent {
        func event(_ type: GameEventType, side: Side? = nil, scorer: String? = nil, corrects: String? = nil) -> GameEvent {
            GameEvent(
                type: type,
                side: side,
                scorer: scorer,
                period: period,
                matchSecond: Int(matchTime(at: now)),
                createdAt: now,
                createdBy: user,
                correctsEventId: corrects
            )
        }

        let result: GameEvent
        switch (action, status) {
        case (.kickoff, .scheduled):
            status = .live
            period = 1
            clock = .stopped
            clock.start(at: now)
            result = event(.kickoff)

        case (.pause, .live) where clock.running:
            clock.pause(at: now)
            result = event(.pause)

        case (.resume, .live) where !clock.running:
            clock.start(at: now)
            result = event(.resume)

        case let (.goal(side, scorer), .live):
            score[side] += 1
            result = event(.goal, side: side, scorer: scorer)

        case (.endPeriod, .live):
            clock.pause(at: now)
            result = event(period >= periodCount ? .final : .periodEnd)
            status = period >= periodCount ? .final : .intermission

        case (.startNextPeriod, .intermission):
            period += 1
            clock = .stopped
            clock.start(at: now)
            result = event(.periodStart)
            status = .live

        case let (.correct(goal), .live), let (.correct(goal), .intermission), let (.correct(goal), .final):
            guard goal.type == .goal, let side = goal.side else { throw GameActionError.notAGoal }
            score[side] = max(0, score[side] - 1)
            var correction = event(.correction, side: side, corrects: goal.id)
            // Keep the correction on the timeline next to the goal it undoes.
            correction.period = goal.period
            correction.matchSecond = goal.matchSecond
            result = correction

        default:
            throw GameActionError.notAllowed(action, status)
        }

        updatedAt = now
        updatedBy = user
        return result
    }
}
