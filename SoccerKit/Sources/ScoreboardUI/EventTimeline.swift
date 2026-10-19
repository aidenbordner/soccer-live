import SwiftUI
import SoccerModels

/// The game's story, newest first: goals, halftime, kickoff. Corrected goals are struck through.
public struct EventTimeline: View {
    let events: [GameEvent]
    let game: Game
    let team: Team

    public init(events: [GameEvent], game: Game, team: Team) {
        self.events = events
        self.game = game
        self.team = team
    }

    public var body: some View {
        let corrected = Set(events.compactMap(\.correctsEventId))
        let shown = events.filter { $0.type != .correction && $0.type != .pause && $0.type != .resume }
        if shown.isEmpty {
            ContentUnavailableView("No events yet", systemImage: "sportscourt", description: Text("Goals and halftime show up here as they happen."))
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(shown.reversed()) { event in
                    EventRow(event: event, team: team, opponent: game.opponent, isCorrected: corrected.contains(event.id))
                    Divider().padding(.leading, 56)
                }
            }
        }
    }
}

public struct EventRow: View {
    let event: GameEvent
    let team: Team
    let opponent: Opponent
    let isCorrected: Bool

    public init(event: GameEvent, team: Team, opponent: Opponent, isCorrected: Bool = false) {
        self.event = event
        self.team = team
        self.opponent = opponent
        self.isCorrected = isCorrected
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(event.minuteMarker)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(event.type == .goal ? .semibold : .regular))
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .strikethrough(isCorrected)
            .opacity(isCorrected ? 0.5 : 1)
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private var icon: String {
        switch event.type {
        case .goal: "soccerball"
        case .kickoff, .periodStart: "whistle"
        case .periodEnd: "pause.circle"
        case .final: "flag.checkered"
        case .pause: "pause"
        case .resume: "play"
        case .correction: "arrow.uturn.backward"
        }
    }

    private var iconColor: Color {
        guard event.type == .goal else { return .secondary }
        return event.side == .us ? Color(hex: team.colors.primary) : .primary
    }

    private var title: String {
        switch event.type {
        case .goal: "Goal, \(event.side == .us ? team.name : opponent.name)"
        case .kickoff: "Kickoff"
        case .periodStart: "Period \(event.period) underway"
        case .periodEnd: "End of period \(event.period)"
        case .final: "Full time"
        case .pause: "Clock paused"
        case .resume: "Clock restarted"
        case .correction: "Goal taken back"
        }
    }

    private var detail: String? {
        if isCorrected { return "Taken back by the scorekeeper" }
        return event.type == .goal ? event.scorer : nil
    }
}
