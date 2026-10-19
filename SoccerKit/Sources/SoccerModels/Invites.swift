import Foundation

/// Short codes parents can read aloud or type: no 0/O, 1/I/L or other easily confused characters.
public enum InviteCode {
    public static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    public static let length = 6
    public static let joinHost = "soccer-live.web.app"

    public static func generate<G: RandomNumberGenerator>(using generator: inout G) -> String {
        String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    public static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    /// Cleans up what a parent typed ("k7qx-2m ", "K7Q X2M") into a canonical code,
    /// or returns nil if it can't be one.
    public static func normalize(_ input: String) -> String? {
        let cleaned = input.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard cleaned.count == length, cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    /// The link shared in the team group chat or shown as a QR code.
    public static func joinURL(for code: String) -> URL {
        URL(string: "https://\(joinHost)/join/\(code)")!
    }

    /// Pulls the code out of a join link opened as a Universal Link.
    public static func code(from url: URL) -> String? {
        guard url.host() == joinHost else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "join" else { return nil }
        return normalize(parts[1])
    }
}

/// A lookup doc at `joinCodes/{code}`. Clients may get one by its exact code but never list them.
public struct JoinCode: Codable, Hashable, Sendable {
    public var code: String
    public var teamId: TeamID
    public var role: Role
    public var active: Bool

    public init(code: String, teamId: TeamID, role: Role = .fan, active: Bool = true) {
        self.code = code
        self.teamId = teamId
        self.role = role
        self.active = active
    }
}

/// A single-use invite that makes someone an admin. Stored at `adminInvites/{token}`.
public struct AdminInvite: Codable, Hashable, Identifiable, Sendable {
    public static let lifetime: TimeInterval = 7 * 24 * 60 * 60

    public var token: String
    public var teamId: TeamID
    public var createdBy: UserID
    public var expiresAt: Date
    public var usedBy: UserID?

    public var id: String { token }

    public init(token: String, teamId: TeamID, createdBy: UserID, expiresAt: Date, usedBy: UserID? = nil) {
        self.token = token
        self.teamId = teamId
        self.createdBy = createdBy
        self.expiresAt = expiresAt
        self.usedBy = usedBy
    }

    /// A fresh invite with a long random token, valid for `lifetime` from `now`.
    public static func make(teamId: TeamID, createdBy: UserID, now: Date) -> AdminInvite {
        AdminInvite(
            token: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            teamId: teamId,
            createdBy: createdBy,
            expiresAt: now.addingTimeInterval(lifetime)
        )
    }

    public func isRedeemable(at now: Date) -> Bool {
        usedBy == nil && now < expiresAt
    }
}
