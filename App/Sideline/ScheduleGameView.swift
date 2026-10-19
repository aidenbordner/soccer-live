import ScoreboardUI
import SoccerBackend
import SoccerModels
import SwiftUI

struct ScheduleGameView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let team: Team

    @State private var opponentName = ""
    @State private var opponentShort = ""
    @State private var homeAway = HomeAway.home
    @State private var venue = ""
    @State private var date = Calendar.current.nextDate(
        after: .now,
        matching: DateComponents(hour: 9, minute: 0, weekday: 7),
        matchingPolicy: .nextTime
    ) ?? .now
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Opponent") {
                    TextField("Team name", text: $opponentName)
                        .onChange(of: opponentName) { oldName, newName in
                            if opponentShort.isEmpty || opponentShort == CreateTeamView.suggestedShortName(for: oldName) {
                                opponentShort = CreateTeamView.suggestedShortName(for: newName)
                            }
                        }
                    TextField("Short name (3 letters)", text: $opponentShort)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section("When and where") {
                    DatePicker("Kickoff", selection: $date)
                    Picker("Side", selection: $homeAway) {
                        Text("Home").tag(HomeAway.home)
                        Text("Away").tag(HomeAway.away)
                    }
                    .pickerStyle(.segmented)
                    TextField("Field (optional)", text: $venue)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Schedule a game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(opponentName.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let name = opponentName.trimmingCharacters(in: .whitespaces)
        let short = opponentShort.trimmingCharacters(in: .whitespaces).uppercased()
        let place = venue.trimmingCharacters(in: .whitespaces)
        let draft = GameDraft(
            teamId: team.id,
            opponent: Opponent(name: name, shortName: short.isEmpty ? String(name.prefix(3)).uppercased() : short),
            homeAway: homeAway,
            venue: place.isEmpty ? nil : place,
            scheduledAt: date
        )
        do {
            try await model.scheduleGame(draft)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
