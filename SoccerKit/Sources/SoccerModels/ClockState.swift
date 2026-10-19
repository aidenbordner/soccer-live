import Foundation

/// The game clock as a state, not a stream of ticks.
///
/// The admin's phone writes this only when the clock starts, pauses or resets. Every phone works out
/// the displayed time itself from `startedAt`, so a whole game costs a few dozen writes however many
/// parents are watching. Time counts up from zero within each period.
public struct ClockState: Codable, Hashable, Sendable {
    public var running: Bool
    /// When the clock last started running. Nil while paused.
    public var startedAt: Date?
    /// Time already on the clock from earlier runs in this period.
    public var elapsedBeforeStart: TimeInterval

    public init(running: Bool = false, startedAt: Date? = nil, elapsedBeforeStart: TimeInterval = 0) {
        self.running = running
        self.startedAt = startedAt
        self.elapsedBeforeStart = elapsedBeforeStart
    }

    public static let stopped = ClockState()

    /// Seconds on the clock in the current period at `now`.
    public func elapsed(at now: Date) -> TimeInterval {
        guard running, let startedAt else { return elapsedBeforeStart }
        // A phone whose clock runs slightly behind the server could see a negative interval.
        return elapsedBeforeStart + max(0, now.timeIntervalSince(startedAt))
    }

    public mutating func start(at now: Date) {
        guard !running else { return }
        running = true
        startedAt = now
    }

    public mutating func pause(at now: Date) {
        guard running else { return }
        elapsedBeforeStart = elapsed(at: now)
        running = false
        startedAt = nil
    }
}

public enum MatchClock {
    /// "7:05", "24:59", "31:12". Minutes are not zero-padded, like a broadcast clock.
    public static func format(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds))
        let secs = whole % 60
        return "\(whole / 60):\(secs < 10 ? "0" : "")\(secs)"
    }

    /// The minute marker for an event, like "12'". Minute 0 reads as "1'", as in broadcasts.
    public static func minuteMarker(_ seconds: TimeInterval) -> String {
        "\(max(0, Int(seconds)) / 60 + 1)'"
    }
}
