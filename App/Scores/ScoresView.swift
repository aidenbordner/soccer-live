import ScoreboardUI
import SoccerModels
import SwiftUI

/// The fan side: live game up top, then upcoming games and results.
struct ScoresView: View {
    @Environment(AppModel.self) private var model
    let team: Team
    @State private var games: [Game] = []
    @State private var loaded = false

    var body: some View {
        List {
            let live = games.filter { $0.status == .live || $0.status == .intermission }
            let upcoming = games.filter { $0.status == .scheduled }
            let results = games.filter { $0.status == .final }

            if !live.isEmpty {
                Section("Live") {
                    ForEach(live) { game in
                        NavigationLink(value: game.id) {
                            ScoreBug(game: game, team: team, style: .hero)
                                .padding(.vertical, 12)
                        }
                    }
                }
            }
            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { game in
                        NavigationLink(value: game.id) {
                            ScoreBug(game: game, team: team).padding(.vertical, 4)
                        }
                    }
                }
            }
            if !results.isEmpty {
                Section("Results") {
                    ForEach(results) { game in
                        NavigationLink(value: game.id) {
                            ScoreBug(game: game, team: team).padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .overlay {
            if loaded && games.isEmpty {
                ContentUnavailableView(
                    "No games yet",
                    systemImage: "calendar",
                    description: Text("When \(team.name) schedules a game, it shows up here.")
                )
            }
        }
        .navigationTitle("Scores")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: GameID.self) { id in
            GameDetailView(gameId: id, team: team)
        }
        .task(id: team.id) {
            for await list in await model.backend.games(team: team.id) {
                withAnimation(.snappy) { games = list }
                loaded = true
            }
        }
    }
}

/// One game for fans: the big score bug and the timeline.
struct GameDetailView: View {
    @Environment(AppModel.self) private var model
    let gameId: GameID
    let team: Team
    @State private var game: Game?
    @State private var events: [GameEvent] = []

    var body: some View {
        ScrollView {
            if let game {
                VStack(spacing: 24) {
                    ScoreBug(game: game, team: team, style: .hero)
                        .padding(.vertical, 24)
                        .padding(.horizontal)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24))
                        .sensoryFeedback(.success, trigger: game.score)
                    EventTimeline(events: events, game: game, team: team)
                }
                .padding()
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .navigationTitle(game.map { "\(team.shortName) vs \($0.opponent.shortName)" } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: gameId) { await listenForGame() }
        .task(id: gameId) { await listenForEvents() }
    }

    private func listenForGame() async {
        for await list in await model.backend.games(team: team.id) {
            game = list.first { $0.id == gameId }
        }
    }

    private func listenForEvents() async {
        for await list in await model.backend.events(game: gameId) {
            withAnimation(.snappy) { events = list }
        }
    }
}
