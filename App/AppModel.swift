import Observation
import SoccerBackend
import SoccerModels
import SwiftUI

/// Who you are and which teams you belong to. Game data is listened to by the screens that show it.
@MainActor
@Observable
final class AppModel {
    let backend: any Backend

    private(set) var userId: UserID?
    private(set) var isAppleAccount = false
    private(set) var memberships: [Membership] = []
    private(set) var teams: [TeamID: Team] = [:]
    var selectedTeamId: TeamID?

    /// A join code from a link opened before the person reached the join screen.
    var pendingJoinCode: String?

    private var membershipTask: Task<Void, Never>?

    init(backend: any Backend) {
        self.backend = backend
    }

    var hasTeams: Bool { !memberships.isEmpty }

    var selectedMembership: Membership? {
        memberships.first { $0.teamId == selectedTeamId } ?? memberships.first
    }

    var selectedTeam: Team? {
        selectedMembership.flatMap { teams[$0.teamId] }
    }

    /// Teams paired with your role on each, in the order you joined them.
    var teamList: [(team: Team, role: Role)] {
        memberships.compactMap { membership in
            teams[membership.teamId].map { ($0, membership.role) }
        }
    }

    // MARK: The two doors

    /// Fans: no account needed, so this signs in anonymously first if necessary.
    func follow(code: String, displayName: String?) async throws {
        let user = try await ensureSignedIn(.anonymous)
        let team = try await backend.joinTeam(code: code, user: user, displayName: displayName)
        teams[team.id] = team
        selectedTeamId = team.id
    }

    /// Admins sign in with Apple before creating a team.
    func signInWithApple() async throws {
        _ = try await ensureSignedIn(.apple)
    }

    func startTeam(_ draft: TeamDraft, ownerName: String?) async throws {
        let user = try await ensureSignedIn(.apple)
        let team = try await backend.createTeam(draft, owner: user, ownerName: ownerName)
        teams[team.id] = team
        selectedTeamId = team.id
    }

    // MARK: Games

    func perform(_ action: GameAction, game: GameID) async throws -> GameEvent {
        guard let userId else { throw BackendError.notAllowed }
        return try await backend.perform(action, game: game, by: userId)
    }

    func scheduleGame(_ draft: GameDraft) async throws {
        guard let userId else { throw BackendError.notAllowed }
        _ = try await backend.scheduleGame(draft, by: userId)
    }

    // MARK: Private

    private func ensureSignedIn(_ method: SignInMethod) async throws -> UserID {
        if let userId {
            // The real backend links Apple to the existing anonymous account, keeping its teams.
            if method == .apple { isAppleAccount = true }
            return userId
        }
        let id = try await backend.signIn(method)
        userId = id
        isAppleAccount = method == .apple
        listenForMemberships(of: id)
        return id
    }

    private func listenForMemberships(of user: UserID) {
        membershipTask?.cancel()
        membershipTask = Task { [backend] in
            for await list in await backend.memberships(of: user) {
                await self.apply(list)
            }
        }
    }

    private func apply(_ list: [Membership]) async {
        for membership in list where teams[membership.teamId] == nil {
            teams[membership.teamId] = try? await backend.team(membership.teamId)
        }
        memberships = list
        if !list.isEmpty, !list.contains(where: { $0.teamId == selectedTeamId }) {
            selectedTeamId = list.first?.teamId
        }
    }
}
