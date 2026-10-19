import ScoreboardUI
import SoccerBackend
import SoccerModels
import SwiftUI

/// Running a game at the field. Built for one thumb in sunlight: huge targets, a confirm sheet
/// for goals with an optional jersey number, and a few seconds to undo a goal after that.
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
    @State private var confirmingEnd = false
    @State private var pendingGoal: PendingGoal?

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
        .sheet(item: $pendingGoal) { pending in
            GoalSheet(
                side: pending.side,
                name: pending.side == .us ? team.name : game?.opponent.name ?? "Them",
                shortName: pending.side == .us ? team.shortName : game?.opponent.shortName ?? "",
                color: pending.side == .us ? Color(hex: team.colors.primary) : .gray,
                minute: game.map { MatchClock.minuteMarker($0.matchTime(at: .now)) } ?? ""
            ) { scorer in
                pendingGoal = nil
                Task { await goal(pending.side, scorer: scorer) }
            }
        }
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
                        pendingGoal = PendingGoal(side: .us)
                    }
                    BigButton("Goal \(game.opponent.shortName)", systemImage: "soccerball", color: .gray, height: 120) {
                        pendingGoal = PendingGoal(side: .them)
                    }
                }
                HStack(spacing: 12) {
                    if game.clock.running {
                        BigButton("Pause", systemImage: "pause.fill", color: .orange) { await run(.pause) }
                    } else {
                        BigButton("Restart clock", systemImage: "play.fill", color: .green) { await run(.resume) }
                    }
                    BigButton(endLabel(game), systemImage: "flag.checkered", color: .secondary) { confirmingEnd = true }
                }
                .confirmationDialog(endQuestion(game), isPresented: $confirmingEnd, titleVisibility: .visible) {
                    Button(endLabel(game)) { Task { await run(.endPeriod) } }
                } message: {
                    Text("The clock stops at \(MatchClock.format(game.matchTime(at: .now))). The next period picks up from there.")
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

    private func endQuestion(_ game: Game) -> String {
        if game.period >= game.periodCount { return "End the game?" }
        return game.periodCount == 2 ? "Call halftime?" : "End this period?"
    }

    private func endLabel(_ game: Game) -> String {
        if game.period >= game.periodCount { return "End game" }
        return game.periodCount == 2 ? "Halftime" : "End period"
    }

    private func goal(_ side: Side, scorer: String?) async {
        if let event = await run(.goal(side, scorer: scorer)) {
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

struct PendingGoal: Identifiable {
    let side: Side
    var id: String { side.rawValue }
}

/// Confirms a goal before it reaches every parent's phone, with an optional jersey number.
private struct GoalSheet: View {
    let side: Side
    let name: String
    let shortName: String
    let color: Color
    let minute: String
    let confirm: (_ scorer: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var number = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                TeamBadge(shortName: shortName, color: color, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Goal, \(name)?").font(.title2.weight(.bold))
                    Text(minute.isEmpty ? "Scorer's number is optional" : "At \(minute). Scorer's number is optional")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(number.isEmpty ? "#" : "#\(number)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(number.isEmpty ? .tertiary : .primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: number)
                .accessibilityLabel(number.isEmpty ? "No number entered" : "Number \(number)")

            NumberPad(number: $number)

            HStack(spacing: 12) {
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                Button {
                    confirm(number.isEmpty ? nil : "#\(number)")
                } label: {
                    Text("Confirm goal")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(color)
            }
        }
        .padding(20)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

/// A big phone-style keypad for jersey numbers, up to two digits.
private struct NumberPad: View {
    @Binding var number: String

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["clear", "0", "delete"]]

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button {
                            press(key)
                        } label: {
                            Group {
                                switch key {
                                case "clear": Text("Clear").font(.headline)
                                case "delete": Image(systemName: "delete.left").font(.title2)
                                default: Text(key).font(.system(size: 30, weight: .semibold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .tint(Color.primary)
                        .disabled(isDisabled(key))
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: number)
    }

    private func isDisabled(_ key: String) -> Bool {
        switch key {
        case "clear", "delete": number.isEmpty
        default: number.count >= 2
        }
    }

    private func press(_ key: String) {
        switch key {
        case "clear": number = ""
        case "delete": number = String(number.dropLast())
        default:
            guard number.count < 2 else { return }
            // No leading zeros: "07" is just "7".
            number = number == "0" ? key : number + key
        }
    }
}
