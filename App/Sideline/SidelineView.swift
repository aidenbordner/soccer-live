import ScoreboardUI
import SoccerBackend
import SoccerModels
import SwiftUI

/// The admin side: schedule games, invite fans, and run a game.
struct SidelineView: View {
    @Environment(AppModel.self) private var model
    let team: Team
    @State private var games: [Game] = []
    @State private var showingSchedule = false
    @State private var showingInvite = false

    var body: some View {
        List {
            Section {
                Button {
                    showingInvite = true
                } label: {
                    Label("Invite fans", systemImage: "qrcode")
                }
                Button {
                    showingSchedule = true
                } label: {
                    Label("Schedule a game", systemImage: "calendar.badge.plus")
                }
            }

            let active = games.filter { $0.status != .final }
            Section(active.isEmpty ? "" : "Games") {
                ForEach(active) { game in
                    NavigationLink(value: game.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            ScoreBug(game: game, team: team)
                            Text(game.status == .scheduled ? "Tap to get ready for kickoff" : "Tap to keep scoring")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Sideline")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: GameID.self) { id in
            RunGameView(gameId: id, team: team)
        }
        .sheet(isPresented: $showingSchedule) { ScheduleGameView(team: team) }
        .sheet(isPresented: $showingInvite) { InviteFansView(team: team) }
        .task(id: team.id) {
            for await list in await model.backend.games(team: team.id) {
                withAnimation(.snappy) { games = list }
            }
        }
    }
}
