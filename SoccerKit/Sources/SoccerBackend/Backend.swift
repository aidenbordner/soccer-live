import Foundation
import SoccerModels

public enum SignInMethod: Sendable {
    /// Fans: no account, created behind the scenes when they follow a team.
    case anonymous
    /// Admins: Sign in with Apple, so admin access survives a lost phone.
    case apple
}

/// What the "Start a team" form collects.
public struct TeamDraft: Hashable, Sendable {
    public var name: String
    public var shortName: String
    public var colors: TeamColors
    public var defaults: GameDefaults

    public init(name: String, shortName: String, colors: TeamColors, defaults: GameDefaults = GameDefaults()) {
        self.name = name
        self.shortName = shortName
        self.colors = colors
        self.defaults = defaults
    }
}

/// What the "Schedule a game" form collects.
public struct GameDraft: Hashable, Sendable {
    public var teamId: TeamID
    public var opponent: Opponent
    public var homeAway: HomeAway
    public var venue: String?
    public var scheduledAt: Date

    public init(teamId: TeamID, opponent: Opponent, homeAway: HomeAway, venue: String? = nil, scheduledAt: Date) {
        self.teamId = teamId
        self.opponent = opponent
        self.homeAway = homeAway
        self.venue = venue
        self.scheduledAt = scheduledAt
    }
}

public enum BackendError: Error, Equatable, Sendable, LocalizedError {
    case invalidCode
    case unknownCode
    case notFound
    case notAllowed

    public var errorDescription: String? {
        switch self {
        case .invalidCode: "Team codes are 6 letters and numbers, like K7QX2M."
        case .unknownCode: "That code doesn't match a team. Check with your coach for a new one."
        case .notFound: "That couldn't be found. It may have been removed."
        case .notAllowed: "Only the team's admins can do that."
        }
    }
}

/// Everything the app needs from the server. Firebase implements it for real; `FakeBackend` runs
/// the whole app in memory for previews, tests and development.
///
/// Listeners return streams that yield the current value straight away and again on every change,
/// matching how Firestore snapshot listeners behave.
public protocol Backend: Sendable {
    func signIn(_ method: SignInMethod) async throws -> UserID

    func createTeam(_ draft: TeamDraft, owner: UserID, ownerName: String?) async throws -> Team
    /// Joins as a fan. Joining a team you already belong to keeps your existing role.
    func joinTeam(code: String, user: UserID, displayName: String?) async throws -> Team
    func team(_ id: TeamID) async throws -> Team

    func memberships(of user: UserID) async -> AsyncStream<[Membership]>
    func games(team: TeamID) async -> AsyncStream<[Game]>
    func events(game: GameID) async -> AsyncStream<[GameEvent]>

    func scheduleGame(_ draft: GameDraft, by user: UserID) async throws -> Game
    /// Applies an admin action and appends its event, together.
    func perform(_ action: GameAction, game: GameID, by user: UserID) async throws -> GameEvent
}
