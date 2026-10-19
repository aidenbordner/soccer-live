import Foundation

/// What a person can do on one team. The same person can hold different roles on different teams.
public enum Role: String, Codable, CaseIterable, Comparable, Sendable {
    case fan
    case admin
    case owner

    /// Anyone on the team can follow its games.
    public var canViewScores: Bool { true }

    /// Admins and the owner run the clock and score, and see the Sideline tab.
    public var canRunGames: Bool { self >= .admin }

    /// Only the owner edits the team, invites admins, and rotates the fan code.
    public var canManageTeam: Bool { self == .owner }

    private var rank: Int {
        switch self {
        case .fan: 0
        case .admin: 1
        case .owner: 2
        }
    }

    public static func < (lhs: Role, rhs: Role) -> Bool { lhs.rank < rhs.rank }
}

/// How someone ended up on a team, kept so the owner can see it in the member list.
public enum JoinMethod: String, Codable, Sendable {
    case created
    case fanCode
    case adminInvite
}

/// One person's place on one team. Stored at `teams/{teamId}/members/{userId}`.
public struct Membership: Codable, Hashable, Identifiable, Sendable {
    public var teamId: TeamID
    public var userId: UserID
    public var role: Role
    /// First name only; optional for fans.
    public var displayName: String?
    public var joinedAt: Date
    public var joinedVia: JoinMethod

    public var id: String { "\(teamId)/\(userId)" }

    public init(
        teamId: TeamID,
        userId: UserID,
        role: Role,
        displayName: String? = nil,
        joinedAt: Date,
        joinedVia: JoinMethod
    ) {
        self.teamId = teamId
        self.userId = userId
        self.role = role
        self.displayName = displayName
        self.joinedAt = joinedAt
        self.joinedVia = joinedVia
    }
}
