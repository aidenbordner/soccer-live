import ScoreboardUI
import SoccerModels
import SwiftUI

/// Scores for everyone; Sideline only on teams where you're an admin.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var tab = Tab.scores

    enum Tab: Hashable {
        case scores
        case sideline
    }

    var body: some View {
        if let team = model.selectedTeam, let membership = model.selectedMembership {
            TabView(selection: $tab) {
                NavigationStack {
                    ScoresView(team: team)
                        .toolbar { ToolbarItem(placement: .topBarLeading) { TeamSwitcher() } }
                }
                .tabItem { Label("Scores", systemImage: "sportscourt") }
                .tag(Tab.scores)

                if membership.role.canRunGames {
                    NavigationStack {
                        SidelineView(team: team)
                            .toolbar { ToolbarItem(placement: .topBarLeading) { TeamSwitcher() } }
                    }
                    .tabItem { Label("Sideline", systemImage: "stopwatch") }
                    .tag(Tab.sideline)
                }
            }
            .tint(Color(hex: team.colors.primary))
            .id(team.id)
            .onChange(of: membership.role.canRunGames) { _, canRun in
                if !canRun { tab = .scores }
            }
        } else {
            ProgressView()
        }
    }
}

/// Team name in the top corner. With more than one team it becomes a menu; it's also where you
/// follow or start another team.
struct TeamSwitcher: View {
    @Environment(AppModel.self) private var model
    @State private var showingJoin = false
    @State private var showingCreate = false

    var body: some View {
        Menu {
            ForEach(model.teamList, id: \.team.id) { entry in
                Button {
                    model.selectedTeamId = entry.team.id
                } label: {
                    if entry.team.id == model.selectedTeam?.id {
                        Label(entry.team.name, systemImage: "checkmark")
                    } else {
                        Text(entry.team.name)
                    }
                    Text(entry.role == .fan ? "Following" : entry.role == .owner ? "Owner" : "Admin")
                }
            }
            Divider()
            Button("Follow another team", systemImage: "person.badge.plus") { showingJoin = true }
            Button("Start a team", systemImage: "plus.circle") { showingCreate = true }
        } label: {
            if let team = model.selectedTeam {
                HStack(spacing: 8) {
                    TeamBadge(shortName: team.shortName, color: Color(hex: team.colors.primary), size: 28)
                    Text(team.name).font(.headline).foregroundStyle(.primary)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingJoin) { JoinTeamView() }
        .sheet(isPresented: $showingCreate) { CreateTeamView() }
    }
}
