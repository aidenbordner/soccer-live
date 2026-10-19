import ScoreboardUI
import SoccerBackend
import SoccerModels
import SwiftUI

/// Running a game at the field. Built for one thumb in sunlight: huge targets, no confirmations,
/// and a few seconds to undo a goal.
///
/// Two panes when there's room (unfolded, iPad, landscape): scoreboard and controls on one side,
/// the event log on the other. One column on a regular phone.
struct RunGameView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    let gameId: GameID
    let team: Team

    @State private var game: Game?
    @State private var events: [GameEvent] = []
    @State private var undoable: GameEvent?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let game {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 0) {
                        ScrollView { controls(game).padding() }
                            .frame(maxWidth: .infinity)
                        Divider()
                        ScrollView { EventTimeline(events: events, game: game, team: team).padding() }
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            controls(game)
                            EventTimeline(events: events, game: game, team: team)
                        }
                        .padding()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .bottom) {
            if let undoable {
                UndoToast(event: undoable, team: team, opponent: game?.opponent) {
                    Task { await run(.correct(undoable)) }
                    self.undoable = nil
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: undoable)
        .navigationTitle(game.map { "vs \($0.opponent.name)" } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task(id: gameId) {
            for await list in await model.backend.games(team: team.id) {
                game = list.first { $0.id == gameId }
            }
        }
        .task(id: gameId) {
            for await list in await model.backend.events(game: gameId) {
                withAnimation(.snappy) { events = list }
            }
        }
        .task(id: undoable?.id) {
            // The undo offer disappears after a few seconds.
            guard undoable != nil else { return }
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { undoable = nil }
        }
    }

    @ViewBuilder
    private func controls(_ game: Game) -> some View {
        VStack(spacing: 20) {
            ScoreBug(game: game, team: team, style: .hero)
                .padding(.vertical, 20)
                .padding(.horizontal, 8)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24))

            switch game.status {
            case .scheduled:
                BigButton("Kick off", systemImage: "whistle", color: .green) { await run(.kickoff) }

            case .live:
                HStack(spacing: 12) {
                    BigButton("Goal \(team.shortName)", systemImage: "soccerball", color: Color(hex: team.colors.primary), height: 120) {
                        await goal(.us)
                    }
                    BigButton("Goal \(game.opponent.shortName)", systemImage: "soccerball", color: .gray, height: 120) {
                        await goal(.them)
                    }
                }
                HStack(spacing: 12) {
                    if game.clock.running {
                        BigButton("Pause", systemImage: "pause.fill", color: .orange) { await run(.pause) }
                    } else {
                        BigButton("Restart clock", systemImage: "play.fill", color: .green) { await run(.resume) }
                    }
                    BigButton(endLabel(game), systemImage: "flag.checkered", color: .secondary) { await run(.endPeriod) }
                }

            case .intermission:
                BigButton(game.periodCount == 2 ? "Start second half" : "Start period \(game.period + 1)", systemImage: "whistle", color: .green) {
                    await run(.startNextPeriod)
                }

            case .final:
                Label("Full time. Nice game!", systemImage: "flag.checkered")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.score)
        .sensoryFeedback(.selection, trigger: game.status)
    }

    private func endLabel(_ game: Game) -> String {
        if game.period >= game.periodCount { return "End game" }
        return game.periodCount == 2 ? "Halftime" : "End period"
    }

    private func goal(_ side: Side) async {
        if let event = await run(.goal(side)) {
            undoable = event
        }
    }

    @discardableResult
    private func run(_ action: GameAction) async -> GameEvent? {
        do {
            return try await model.perform(action, game: gameId)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

/// A large, high-contrast button that runs an async action.
private struct BigButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let height: CGFloat
    let action: () async -> Void

    init(_ title: String, systemImage: String, color: Color, height: CGFloat = 64, action: @escaping () async -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.height = height
        self.action = action
    }

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.title2.weight(.bold))
                Text(title).font(.headline).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: height)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 18))
        .tint(color)
    }
}

private struct UndoToast: View {
    let event: GameEvent
    let team: Team
    let opponent: Opponent?
    let undo: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "soccerball")
            Text("Goal, \(event.side == .us ? team.name : opponent?.name ?? "them")")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button("Undo", action: undo)
                .font(.subheadline.weight(.bold))
        }
        .padding()
        .background(.regularMaterial, in: Capsule())
        .shadow(radius: 8, y: 4)
        .frame(maxWidth: 500)
    }
}
