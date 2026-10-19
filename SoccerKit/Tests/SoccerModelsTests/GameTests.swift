import Foundation
import Testing
@testable import SoccerModels

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private let admin: UserID = "admin-1"

private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

private func newGame(periodCount: Int = 2, periodMinutes: Int = 25) -> Game {
    Game(
        id: "g1",
        teamId: "t1",
        opponent: Opponent(name: "Hornets", shortName: "HOR"),
        homeAway: .home,
        scheduledAt: t0,
        defaults: GameDefaults(periodCount: periodCount, periodMinutes: periodMinutes),
        createdAt: t0
    )
}

@Suite struct GameTests {
    @Test func newGameIsScheduledAndScoreless() {
        let game = newGame()
        #expect(game.status == .scheduled)
        #expect(game.period == 0)
        #expect(game.score == Score())
        #expect(game.statusLabel == "UPCOMING")
    }

    @Test func fullTwoHalfGame() throws {
        var game = newGame()

        let kickoff = try game.apply(.kickoff, at: at(0), by: admin)
        #expect(kickoff.type == .kickoff)
        #expect(game.status == .live && game.period == 1 && game.statusLabel == "LIVE")

        let goal = try game.apply(.goal(.us, scorer: "#7"), at: at(12 * 60), by: admin)
        #expect(goal.type == .goal && goal.side == .us && goal.scorer == "#7")
        #expect(goal.matchSecond == 720 && goal.minuteMarker == "13'")
        #expect(game.score == Score(us: 1, them: 0))

        _ = try game.apply(.pause, at: at(15 * 60), by: admin)
        #expect(game.isPaused && game.statusLabel == "PAUSED")
        #expect(game.matchTime(at: at(20 * 60)) == 15 * 60)

        _ = try game.apply(.resume, at: at(20 * 60), by: admin)
        #expect(game.matchTime(at: at(30 * 60)) == 25 * 60)

        let half = try game.apply(.endPeriod, at: at(30 * 60), by: admin)
        #expect(half.type == .periodEnd)
        #expect(game.status == .intermission && game.statusLabel == "HT")

        let second = try game.apply(.startNextPeriod, at: at(40 * 60), by: admin)
        #expect(second.type == .periodStart && second.period == 2)
        #expect(second.matchSecond == 25 * 60)
        #expect(game.matchTime(at: at(41 * 60)) == 26 * 60)

        _ = try game.apply(.goal(.them), at: at(50 * 60), by: admin)
        let end = try game.apply(.endPeriod, at: at(65 * 60), by: admin)
        #expect(end.type == .final)
        #expect(game.status == .final && game.statusLabel == "FT")
        #expect(game.score == Score(us: 1, them: 1))
        #expect(game.updatedAt == at(65 * 60) && game.updatedBy == admin)
    }

    @Test func quarterBreaksAreLabelled() throws {
        var game = newGame(periodCount: 4, periodMinutes: 10)
        _ = try game.apply(.kickoff, at: at(0), by: admin)
        _ = try game.apply(.endPeriod, at: at(600), by: admin)
        #expect(game.statusLabel == "END Q1")
    }

    @Test func correctionUndoesAGoalAndSitsBesideIt() throws {
        var game = newGame()
        _ = try game.apply(.kickoff, at: at(0), by: admin)
        let goal = try game.apply(.goal(.them), at: at(300), by: admin)

        let correction = try game.apply(.correct(goal), at: at(320), by: admin)
        #expect(game.score == Score())
        #expect(correction.type == .correction)
        #expect(correction.correctsEventId == goal.id)
        #expect(correction.matchSecond == goal.matchSecond)
    }

    @Test func correctionsWorkAfterTheFinalWhistle() throws {
        var game = newGame()
        _ = try game.apply(.kickoff, at: at(0), by: admin)
        let goal = try game.apply(.goal(.us), at: at(60), by: admin)
        _ = try game.apply(.endPeriod, at: at(1500), by: admin)
        _ = try game.apply(.startNextPeriod, at: at(1800), by: admin)
        _ = try game.apply(.endPeriod, at: at(3300), by: admin)

        _ = try game.apply(.correct(goal), at: at(3400), by: admin)
        #expect(game.score.us == 0)
    }

    @Test func onlyGoalsCanBeCorrected() throws {
        var game = newGame()
        let kickoff = try game.apply(.kickoff, at: at(0), by: admin)
        #expect(throws: GameActionError.notAGoal) {
            try game.apply(.correct(kickoff), at: at(10), by: admin)
        }
    }

    @Test func actionsOutOfOrderAreRejected() throws {
        var game = newGame()
        #expect(throws: GameActionError.notAllowed(.goal(.us), .scheduled)) {
            try game.apply(.goal(.us), at: at(0), by: admin)
        }

        _ = try game.apply(.kickoff, at: at(0), by: admin)
        #expect(throws: GameActionError.notAllowed(.kickoff, .live)) {
            try game.apply(.kickoff, at: at(1), by: admin)
        }
        #expect(throws: GameActionError.notAllowed(.resume, .live)) {
            try game.apply(.resume, at: at(1), by: admin)
        }

        _ = try game.apply(.endPeriod, at: at(1500), by: admin)
        #expect(throws: GameActionError.notAllowed(.goal(.them), .intermission)) {
            try game.apply(.goal(.them), at: at(1600), by: admin)
        }
    }

    @Test func rejectedActionsLeaveTheGameUnchanged() throws {
        var game = newGame()
        _ = try game.apply(.kickoff, at: at(0), by: admin)
        let before = game
        _ = try? game.apply(.startNextPeriod, at: at(10), by: admin)
        #expect(game == before)
    }
}
