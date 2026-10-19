import Foundation
import Testing
@testable import SoccerModels

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Suite struct ClockTests {
    @Test func stoppedClockShowsZero() {
        #expect(ClockState.stopped.elapsed(at: t0) == 0)
    }

    @Test func runningClockCountsFromStart() {
        var clock = ClockState.stopped
        clock.start(at: t0)
        #expect(clock.elapsed(at: t0.addingTimeInterval(90)) == 90)
    }

    @Test func pauseFreezesAndResumeContinues() {
        var clock = ClockState.stopped
        clock.start(at: t0)
        clock.pause(at: t0.addingTimeInterval(60))
        #expect(clock.elapsed(at: t0.addingTimeInterval(500)) == 60)

        clock.start(at: t0.addingTimeInterval(500))
        #expect(clock.elapsed(at: t0.addingTimeInterval(530)) == 90)
    }

    @Test func startAndPauseAreIdempotent() {
        var clock = ClockState.stopped
        clock.start(at: t0)
        clock.start(at: t0.addingTimeInterval(30))
        #expect(clock.elapsed(at: t0.addingTimeInterval(60)) == 60)

        clock.pause(at: t0.addingTimeInterval(60))
        clock.pause(at: t0.addingTimeInterval(90))
        #expect(clock.elapsed(at: t0.addingTimeInterval(120)) == 60)
    }

    @Test func clockSkewNeverGoesNegative() {
        var clock = ClockState.stopped
        clock.start(at: t0)
        #expect(clock.elapsed(at: t0.addingTimeInterval(-5)) == 0)
    }

    @Test(arguments: [
        (0.0, "0:00"),
        (65.0, "1:05"),
        (1499.9, "24:59"),
        (1872.0, "31:12"),
    ])
    func formatsLikeABroadcastClock(seconds: Double, expected: String) {
        #expect(MatchClock.format(seconds) == expected)
    }

    @Test func minuteMarkersStartAtOne() {
        #expect(MatchClock.minuteMarker(0) == "1'")
        #expect(MatchClock.minuteMarker(59) == "1'")
        #expect(MatchClock.minuteMarker(660) == "12'")
    }
}
