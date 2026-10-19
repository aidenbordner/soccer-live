import SwiftUI
import SoccerModels

/// One side of the score bug.
public struct Competitor: Hashable, Sendable {
    public var name: String
    public var shortName: String
    public var color: Color

    public init(name: String, shortName: String, color: Color) {
        self.name = name
        self.shortName = shortName
        self.color = color
    }
}

extension Game {
    /// Home on the left, like a broadcast.
    public func competitors(team: Team) -> (left: (Competitor, Int), right: (Competitor, Int)) {
        let us = Competitor(name: team.name, shortName: team.shortName, color: Color(hex: team.colors.primary))
        let them = Competitor(
            name: opponent.name,
            shortName: opponent.shortName,
            color: opponent.colors.map { Color(hex: $0.primary) } ?? .secondary
        )
        return homeAway == .home ? ((us, score.us), (them, score.them)) : ((them, score.them), (us, score.us))
    }
}

/// The ESPN-style scoreboard: crests, short names, big score, status and a live clock.
public struct ScoreBug: View {
    public enum Style: Sendable {
        /// A row in a list of games.
        case compact
        /// The top of a game screen.
        case hero
    }

    let game: Game
    let team: Team
    let style: Style

    public init(game: Game, team: Team, style: Style = .compact) {
        self.game = game
        self.team = team
        self.style = style
    }

    public var body: some View {
        let sides = game.competitors(team: team)
        HStack(spacing: style == .hero ? 16 : 10) {
            CompetitorView(competitor: sides.left.0, style: style)
            Spacer(minLength: 0)
            if game.status == .scheduled {
                ScheduledLabel(game: game, style: style)
            } else {
                ScoreLine(left: sides.left.1, right: sides.right.1, game: game, style: style)
            }
            Spacer(minLength: 0)
            CompetitorView(competitor: sides.right.0, style: style)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(sides))
    }

    private func accessibilityText(_ sides: (left: (Competitor, Int), right: (Competitor, Int))) -> String {
        let (left, leftScore) = sides.left
        let (right, rightScore) = sides.right
        if game.status == .scheduled {
            return "\(left.name) versus \(right.name), \(game.scheduledAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "\(left.name) \(leftScore), \(right.name) \(rightScore), \(game.statusLabel)"
    }
}

struct CompetitorView: View {
    let competitor: Competitor
    let style: ScoreBug.Style

    var body: some View {
        VStack(spacing: 6) {
            TeamBadge(shortName: competitor.shortName, color: competitor.color, size: style == .hero ? 64 : 40)
            Text(style == .hero ? competitor.name : competitor.shortName)
                .font(style == .hero ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: style == .hero ? 110 : 64)
    }
}

/// A round crest with the team's initials until real crests exist.
public struct TeamBadge: View {
    let shortName: String
    let color: Color
    let size: CGFloat

    public init(shortName: String, color: Color, size: CGFloat = 40) {
        self.shortName = shortName
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color.gradient)
            .overlay {
                Text(shortName.prefix(3))
                    .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .frame(width: size, height: size)
    }
}

struct ScoreLine: View {
    let left: Int
    let right: Int
    let game: Game
    let style: ScoreBug.Style

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: style == .hero ? 14 : 8) {
                score(left)
                Text("–").foregroundStyle(.secondary)
                    .font(.system(size: style == .hero ? 36 : 22, weight: .bold, design: .rounded))
                score(right)
            }
            StatusPill(game: game, style: style)
        }
    }

    private func score(_ value: Int) -> some View {
        Text("\(value)")
            .font(.system(size: style == .hero ? 64 : 34, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .animation(.snappy, value: value)
    }
}

/// LIVE 12:07 / PAUSED 12:07 / HT / FT.
public struct StatusPill: View {
    let game: Game
    let style: ScoreBug.Style

    public init(game: Game, style: ScoreBug.Style = .compact) {
        self.game = game
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 6) {
            if game.status == .live && game.clock.running {
                Circle().fill(.red).frame(width: 6, height: 6)
            }
            Text(game.statusLabel)
            if game.status == .live {
                GameClockText(game: game)
            }
        }
        .font((style == .hero ? Font.subheadline : Font.caption).weight(.bold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(pillColor.opacity(0.15), in: Capsule())
        .foregroundStyle(pillColor)
    }

    private var pillColor: Color {
        switch game.status {
        case .live: game.clock.running ? .red : .orange
        case .intermission: .orange
        case .scheduled, .final: .secondary
        }
    }
}

/// The match clock, ticking locally from the stored clock state.
public struct GameClockText: View {
    let game: Game

    public init(game: Game) {
        self.game = game
    }

    public var body: some View {
        if game.clock.running {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(MatchClock.format(game.matchTime(at: context.date)))
            }
            .monospacedDigit()
        } else {
            Text(MatchClock.format(game.matchTime(at: .now)))
                .monospacedDigit()
        }
    }
}

struct ScheduledLabel: View {
    let game: Game
    let style: ScoreBug.Style

    var body: some View {
        VStack(spacing: 2) {
            Text(game.scheduledAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(style == .hero ? .headline : .caption.weight(.semibold))
            Text(game.scheduledAt, format: .dateTime.hour().minute())
                .font(style == .hero ? .title2.weight(.bold) : .headline)
                .monospacedDigit()
            if let venue = game.venue {
                Text(venue).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
