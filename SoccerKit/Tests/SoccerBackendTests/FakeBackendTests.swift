import Foundation
import Testing
import SoccerModels
@testable import SoccerBackend

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func draft() -> TeamDraft {
    TeamDraft(name: "Thunder", shortName: "thu", colors: TeamColors(primary: "#000000", secondary: "#FFFFFF"))
}

@Suite struct FakeBackendTests {
    @Test func demoTeamHasALiveGameFirst() async throws {
        let backend = FakeBackend(now: { t0 })
        let fan = try await backend.signIn(.anonymous)
        let team = try await backend.joinTeam(code: FakeBackend.demoCode, user: fan, displayName: nil)
        #expect(team.name == "Lightning")

        var games = await backend.games(team: team.id).makeAsyncIterator()
        let list = try #require(await games.next())
        #expect(list.map(\.status) == [.live, .scheduled, .final])
        #expect(list.last?.score == Score(us: 3, them: 2))
    }

    @Test func creatingATeamMakesYouItsOwner() async throws {
        let backend = FakeBackend(seedDemo: false, now: { t0 })
        let coach = try await backend.signIn(.apple)
        let team = try await backend.createTeam(draft(), owner: coach, ownerName: "Aiden")
        #expect(team.shortName == "THU")
        #expect(InviteCode.normalize(team.fanCode) == team.fanCode)

        var memberships = await backend.memberships(of: coach).makeAsyncIterator()
        let mine = try #require(await memberships.next())
        #expect(mine.map(\.role) == [.owner])
    }

    @Test func fansJoinWithTheCodeHoweverTheyTypeIt() async throws {
        let backend = FakeBackend(seedDemo: false, now: { t0 })
        let team = try await backend.createTeam(draft(), owner: "coach", ownerName: nil)
        let code = team.fanCode.lowercased()
        let messy = " \(code.prefix(3))-\(code.suffix(3)) "

        let joined = try await backend.joinTeam(code: messy, user: "parent", displayName: "Sam")
        #expect(joined.id == team.id)

        var memberships = await backend.memberships(of: "parent").makeAsyncIterator()
        #expect(try #require(await memberships.next()).first?.role == .fan)
    }

    @Test func badCodesAreExplained() async throws {
        let backend = FakeBackend(seedDemo: false, now: { t0 })
        await #expect(throws: BackendError.invalidCode) {
            try await backend.joinTeam(code: "nope", user: "parent", displayName: nil)
        }
        await #expect(throws: BackendError.unknownCode) {
            try await backend.joinTeam(code: "ZZZZ22", user: "parent", displayName: nil)
        }
    }

    @Test func rejoiningNeverDowngradesTheOwner() async throws {
        let backend = FakeBackend(seedDemo: false, now: { t0 })
        let team = try await backend.createTeam(draft(), owner: "coach", ownerName: nil)
        _ = try await backend.joinTeam(code: team.fanCode, user: "coach", displayName: nil)

        var memberships = await backend.memberships(of: "coach").makeAsyncIterator()
        #expect(try #require(await memberships.next()).map(\.role) == [.owner])
    }

    @Test func onlyAdminsScheduleAndRunGames() async throws {
        let backend = FakeBackend(seedDemo: false, now: { t0 })
        let team = try await backend.createTeam(draft(), owner: "coach", ownerName: nil)
        _ = try await backend.joinTeam(code: team.fanCode, user: "parent", displayName: nil)
        let gameDraft = GameDraft(teamId: team.id, opponent: Opponent(name: "Hornets", shortName: "HOR"), homeAway: .home, scheduledAt: t0)

        await #expect(throws: BackendError.notAllowed) {
            try await backend.scheduleGame(gameDraft, by: "parent")
        }

        let game = try await backend.scheduleGame(gameDraft, by: "coach")
        await #expect(throws: BackendError.notAllowed) {
            try await backend.perform(.kickoff, game: game.id, by: "parent")
        }
        let kickoff = try await backend.perform(.kickoff, game: game.id, by: "coach")
        #expect(kickoff.type == .kickoff)
    }

    @Test func listenersSeeEveryChange() async throws {
        let backend = FakeBackend(seedDemo: false, now: { t0 })
        let team = try await backend.createTeam(draft(), owner: "coach", ownerName: nil)
        let game = try await backend.scheduleGame(
            GameDraft(teamId: team.id, opponent: Opponent(name: "Hornets", shortName: "HOR"), homeAway: .away, scheduledAt: t0),
            by: "coach"
        )

        var games = await backend.games(team: team.id).makeAsyncIterator()
        var events = await backend.events(game: game.id).makeAsyncIterator()
        #expect(try #require(await games.next()).first?.status == .scheduled)
        #expect(try #require(await events.next()).isEmpty)

        _ = try await backend.perform(.kickoff, game: game.id, by: "coach")
        _ = try await backend.perform(.goal(.us, scorer: "#9"), game: game.id, by: "coach")

        // Listeners keep only the newest value, like a Firestore snapshot.
        #expect(try #require(await games.next()).first?.score == Score(us: 1, them: 0))
        #expect(try #require(await events.next()).map(\.type) == [.kickoff, .goal])
    }
}
