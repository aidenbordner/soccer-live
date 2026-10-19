import ScoreboardUI
import SoccerBackend
import SoccerModels
import SwiftUI

/// Admins: Sign in with Apple, then name the team and pick its colors.
struct CreateTeamView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var shortName = ""
    @State private var ownerName = ""
    @State private var color = TeamPalette.colors[0]
    @State private var periodMinutes = 25
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if model.isAppleAccount {
                    form
                } else {
                    signIn
                }
            }
            .navigationTitle("Start a team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var signIn: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "stopwatch")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Run the scoreboard")
                .font(.title2.weight(.bold))
            Text("Team admins sign in with Apple so you never lose access to your team, even on a new phone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            // Stand-in until the real backend and Sign in with Apple entitlement are set up.
            Button {
                Task {
                    working = true
                    try? await model.signInWithApple()
                    working = false
                }
            } label: {
                Label("Continue with Apple", systemImage: "apple.logo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primary)
            .foregroundStyle(Color(uiColor: .systemBackground))
            .disabled(working)
            .frame(maxWidth: 420)
            .padding()
        }
    }

    private var form: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    TeamBadge(shortName: shortName.isEmpty ? "?" : shortName.uppercased(), color: Color(hex: color), size: 80)
                        .animation(.snappy, value: color)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Team") {
                TextField("Team name", text: $name)
                    .onChange(of: name) { oldName, newName in
                        // Suggest a short name until they type their own.
                        if shortName.isEmpty || shortName == Self.suggestedShortName(for: oldName) {
                            shortName = Self.suggestedShortName(for: newName)
                        }
                    }
                TextField("Short name (3 letters)", text: $shortName)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: shortName) { _, value in
                        if value.count > 4 { shortName = String(value.prefix(4)) }
                    }
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(TeamPalette.colors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if hex == color {
                                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { color = hex }
                            .accessibilityAddTraits(hex == color ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Games") {
                Stepper("Halves of \(periodMinutes) minutes", value: $periodMinutes, in: 10...45, step: 5)
            }

            Section {
                TextField("Your first name (optional)", text: $ownerName)
                    .textContentType(.givenName)
            } footer: {
                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await create() }
                } label: {
                    HStack {
                        Spacer()
                        if working { ProgressView() } else { Text("Create team").font(.headline) }
                        Spacer()
                    }
                }
                .disabled(!canCreate || working)
            }
        }
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !shortName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func create() async {
        working = true
        defer { working = false }
        let draft = TeamDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            shortName: shortName.trimmingCharacters(in: .whitespaces).uppercased(),
            colors: TeamColors(primary: color, secondary: "#FFFFFF"),
            defaults: GameDefaults(periodCount: 2, periodMinutes: periodMinutes)
        )
        do {
            let owner = ownerName.trimmingCharacters(in: .whitespaces)
            try await model.startTeam(draft, ownerName: owner.isEmpty ? nil : owner)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    static func suggestedShortName(for name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words.prefix(3).compactMap(\.first)).uppercased()
        }
        return String(name.filter(\.isLetter).prefix(3)).uppercased()
    }
}

enum TeamPalette {
    static let colors = [
        "#F5B700", "#E53935", "#1E5AA8", "#2E7D32", "#6A1B9A", "#F57C00",
        "#00897B", "#C2185B", "#37474F", "#5D4037", "#0097A7", "#7CB342",
    ]
}
