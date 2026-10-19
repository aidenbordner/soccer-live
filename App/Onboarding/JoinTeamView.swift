import SoccerBackend
import SoccerModels
import SwiftUI

/// Parents: type or paste the team code, optionally a first name, and land on the scoreboard.
struct JoinTeamView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var name = ""
    @State private var error: String?
    @State private var joining = false
    @FocusState private var codeFocused: Bool

    private var normalized: String? { InviteCode.normalize(code) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("K7QX2M", text: $code)
                        .font(.system(.title, design: .monospaced).weight(.bold))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($codeFocused)
                        .onChange(of: code) { error = nil }
                } header: {
                    Text("Team code")
                } footer: {
                    if let error {
                        Text(error).foregroundStyle(.red)
                    } else if model.backend is FakeBackend {
                        Text("Demo mode: try \(FakeBackend.demoCode) to follow the Lightning.")
                    } else {
                        Text("Your coach shares this in the team chat. Opening their link fills it in for you.")
                    }
                }

                Section {
                    TextField("First name (optional)", text: $name)
                        .textContentType(.givenName)
                } footer: {
                    Text("So the coach knows who's following. Only the team's admins see it.")
                }
            }
            .navigationTitle("Follow a team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if joining {
                        ProgressView()
                    } else {
                        Button("Follow") { Task { await join() } }
                            .disabled(normalized == nil)
                    }
                }
            }
            .onAppear {
                if let pending = model.pendingJoinCode {
                    code = pending
                    model.pendingJoinCode = nil
                } else {
                    codeFocused = true
                }
            }
        }
    }

    private func join() async {
        joining = true
        defer { joining = false }
        do {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            try await model.follow(code: code, displayName: trimmed.isEmpty ? nil : trimmed)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
