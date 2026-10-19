import Foundation
import SoccerModels

/// An in-memory backend that enforces the same permissions the Firestore rules will.
public actor FakeBackend: Backend {
    private var teams: [TeamID: Team]
    private var members: [TeamID: [UserID: Membership]]
    private var joinCodes: [String: JoinCode]
    private var games: [GameID: Game]
    private var events: [GameID: [GameEvent]]
    private let now: @Sendable () -> Date

    private var membershipListeners = Listeners<UserID, [Membership]>()
    private var gameListeners = Listeners<TeamID, [Game]>()
    private var eventListeners = Listeners<GameID, [GameEvent]>()

    /// - Parameter seedDemo: adds the demo team "Lightning" (fan code `FakeBackend.demoCode`) with a
    ///   game in progress and one from last week, so the app has something to show straight away.
    public init(seedDemo: Bool = true, now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
        let seed = seedDemo ? Seed.demo(now: now()) : Seed()
        teams = seed.teams
        members = seed.members
        joinCodes = seed.joinCodes
        games = seed.games
        events = seed.events
    }

    public static let demoCode = "NETS22"

    // MARK: Accounts and teams

    public func signIn(_ method: SignInMethod) async throws -> UserID {
        let prefix = method == .apple ? "apple" : "anon"
        return "\(prefix)-\(UUID().uuidString.prefix(8).lowercased())"
    }

    public func createTeam(_ draft: TeamDraft, owner: UserID, ownerName: String?) async throws -> Team {
        var code = InviteCode.generate()
        while joinCodes[code] != nil { code = InviteCode.generate() }

        let team = Team(
            id: UUID().uuidString,
            name: draft.name,
            shortName: draft.shortName.uppercased(),
            colors: draft.colors,
            ownerId: owner,
            fanCode: code,
            defaults: draft.defaults
        )
        teams[team.id] = team
        joinCodes[code] = JoinCode(code: code, teamId: team.id)
        addMember(Membership(teamId: team.id, userId: owner, role: .owner, displayName: ownerName, joinedAt: now(), joinedVia: .created))
        return team
    }

    public func joinTeam(code: String, user: UserID, displayName: String?) async throws -> Team {
        guard let code = InviteCode.normalize(code) else { throw BackendError.invalidCode }
        guard let joinCode = joinCodes[code], joinCode.active, let team = teams[joinCode.teamId] else {
            throw BackendError.unknownCode
        }
        if members[team.id]?[user] == nil {
            addMember(Membership(teamId: team.id, userId: user, role: joinCode.role, displayName: displayName, joinedAt: now(), joinedVia: .fanCode))
        }
        return team
    }

    public func team(_ id: TeamID) async throws -> Team {
        guard let team = teams[id] else { throw BackendError.notFound }
        return team
    }

    // MARK: Listeners

    public func memberships(of user: UserID) -> AsyncStream<[Membership]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [Membership].self, bufferingPolicy: .bufferingNewest(1))
        let id = membershipListeners.add(user, continuation)
        continuation.yield(membershipList(of: user))
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeMembershipListener(user, id) }
        }
        return stream
    }

    public func games(team: TeamID) -> AsyncStream<[Game]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [Game].self, bufferingPolicy: .bufferingNewest(1))
        let id = gameListeners.add(team, continuation)
        continuation.yield(gameList(team: team))
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeGameListener(team, id) }
        }
        return stream
    }

    public func events(game: GameID) -> AsyncStream<[GameEvent]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [GameEvent].self, bufferingPolicy: .bufferingNewest(1))
        let id = eventListeners.add(game, continuation)
        continuation.yield(events[game] ?? [])
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeEventListener(game, id) }
        }
        return stream
    }

    // MARK: Games

    public func scheduleGame(_ draft: GameDraft, by user: UserID) async throws -> Game {
        guard let team = teams[draft.teamId] else { throw BackendError.notFound }
        try requireCanRunGames(user, team: team.id)
        let game = Game(
            id: UUID().uuidString,
            teamId: team.id,
            opponent: draft.opponent,
            homeAway: draft.homeAway,
            venue: draft.venue,
            scheduledAt: draft.scheduledAt,
            defaults: team.defaults,
            createdAt: now()
        )
        games[game.id] = game
        events[game.id] = []
        gameListeners.send(team.id, gameList(team: team.id))
        return game
    }

    public func perform(_ action: GameAction, game id: GameID, by user: UserID) async throws -> GameEvent {
        guard var game = games[id] else { throw BackendError.notFound }
        try requireCanRunGames(user, team: game.teamId)
        let event = try game.apply(action, at: now(), by: user)
        games[id] = game
        events[id, default: []].append(event)
        gameListeners.send(game.teamId, gameList(team: game.teamId))
        eventListeners.send(id, events[id] ?? [])
        return event
    }

    // MARK: Helpers

    private func requireCanRunGames(_ user: UserID, team: TeamID) throws {
        guard members[team]?[user]?.role.canRunGames == true else { throw BackendError.notAllowed }
    }

    private func addMember(_ membership: Membership) {
        members[membership.teamId, default: [:]][membership.userId] = membership
        membershipListeners.send(membership.userId, membershipList(of: membership.userId))
    }

    private func membershipList(of user: UserID) -> [Membership] {
        members.values.compactMap { $0[user] }.sorted { $0.joinedAt < $1.joinedAt }
    }

    /// Live games first, then upcoming soonest first, then finished games newest first.
    private func gameList(team: TeamID) -> [Game] {
        games.values.filter { $0.teamId == team }.sorted(by: Game.displayOrder)
    }

    private func removeMembershipListener(_ key: UserID, _ id: UUID) { membershipListeners.remove(key, id) }
    private func removeGameListener(_ key: TeamID, _ id: UUID) { gameListeners.remove(key, id) }
    private func removeEventListener(_ key: GameID, _ id: UUID) { eventListeners.remove(key, id) }
}

extension Game {
    /// Live games first, then upcoming soonest first, then finished games newest first.
    public static func displayOrder(_ a: Game, _ b: Game) -> Bool {
        func rank(_ game: Game) -> Int {
            switch game.status {
            case .live, .intermission: 0
            case .scheduled: 1
            case .final: 2
            }
        }
        if rank(a) != rank(b) { return rank(a) < rank(b) }
        return a.status == .final ? a.scheduledAt > b.scheduledAt : a.scheduledAt < b.scheduledAt
    }
}

/// Open listener streams, grouped by what they listen to.
struct Listeners<Key: Hashable & Sendable, Value: Sendable> {
    private var byKey: [Key: [UUID: AsyncStream<Value>.Continuation]] = [:]

    mutating func add(_ key: Key, _ continuation: AsyncStream<Value>.Continuation) -> UUID {
        let id = UUID()
        byKey[key, default: [:]][id] = continuation
        return id
    }

    mutating func remove(_ key: Key, _ id: UUID) {
        byKey[key]?[id] = nil
    }

    func send(_ key: Key, _ value: Value) {
        for continuation in byKey[key, default: [:]].values {
            continuation.yield(value)
        }
    }
}

/// Starting data for the fake backend.
struct Seed {
    var teams: [TeamID: Team] = [:]
    var members: [TeamID: [UserID: Membership]] = [:]
    var joinCodes: [String: JoinCode] = [:]
    var games: [GameID: Game] = [:]
    var events: [GameID: [GameEvent]] = [:]

    static func demo(now: Date) -> Seed {
        let coach: UserID = "demo-coach"
        let team = Team(
            id: "demo-lightning",
            name: "Lightning",
            shortName: "LTG",
            colors: TeamColors(primary: "#F5B700", secondary: "#1B1F3B"),
            ownerId: coach,
            fanCode: FakeBackend.demoCode,
            defaults: GameDefaults(periodCount: 2, periodMinutes: 25)
        )

        var seed = Seed()
        seed.teams[team.id] = team
        seed.joinCodes[team.fanCode] = JoinCode(code: team.fanCode, teamId: team.id)
        seed.members[team.id] = [
            coach: Membership(teamId: team.id, userId: coach, role: .owner, displayName: "Coach", joinedAt: now.addingTimeInterval(-90 * 86_400), joinedVia: .created),
        ]

        /// Plays `steps` (seconds after kickoff, action) against `game` and stores the result.
        func play(_ game: Game, _ steps: [(seconds: Int, action: GameAction)]) {
            var game = game
            var log: [GameEvent] = []
            for step in steps {
                let time = game.scheduledAt.addingTimeInterval(TimeInterval(step.seconds))
                if let event = try? game.apply(step.action, at: time, by: coach) {
                    log.append(event)
                }
            }
            seed.games[game.id] = game
            seed.events[game.id] = log
        }

        // Kicked off 12 minutes ago and still running, so the clock ticks on screen.
        let liveStart = now.addingTimeInterval(-12 * 60)
        play(
            Game(id: "demo-live", teamId: team.id, opponent: Opponent(name: "Hornets", shortName: "HOR", colors: TeamColors(primary: "#2E7D32", secondary: "#FFFFFF")), homeAway: .home, venue: "Field 3", scheduledAt: liveStart, defaults: team.defaults, createdAt: liveStart),
            [(0, .kickoff), (7 * 60 + 14, .goal(.us, scorer: "#7"))]
        )

        let lastWeek = now.addingTimeInterval(-7 * 86_400)
        play(
            Game(id: "demo-final", teamId: team.id, opponent: Opponent(name: "Comets", shortName: "COM", colors: TeamColors(primary: "#6A1B9A", secondary: "#FFFFFF")), homeAway: .away, venue: "Riverside Park", scheduledAt: lastWeek, defaults: team.defaults, createdAt: lastWeek),
            [
                (0, .kickoff),
                (4 * 60, .goal(.them)),
                (11 * 60, .goal(.us, scorer: "Maya")),
                (25 * 60, .endPeriod),
                (30 * 60, .startNextPeriod),
                (38 * 60, .goal(.us, scorer: "#10")),
                (44 * 60, .goal(.them)),
                (51 * 60, .goal(.us, scorer: "#7")),
                (55 * 60, .endPeriod),
            ]
        )

        let nextWeek = Calendar.current.date(byAdding: .day, value: 6, to: now) ?? now.addingTimeInterval(6 * 86_400)
        let upcoming = Game(id: "demo-next", teamId: team.id, opponent: Opponent(name: "Sharks", shortName: "SHK"), homeAway: .home, venue: "Field 1", scheduledAt: nextWeek, defaults: team.defaults, createdAt: now)
        seed.games[upcoming.id] = upcoming
        seed.events[upcoming.id] = []

        return seed
    }
}
