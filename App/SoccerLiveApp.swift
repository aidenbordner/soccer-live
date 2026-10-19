import SoccerBackend
import SoccerModels
import SwiftUI

@main
struct SoccerLiveApp: App {
    // Swapped for the Firebase backend once it exists.
    @State private var model = AppModel(backend: FakeBackend())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { url in
                    if let code = InviteCode.code(from: url) {
                        model.pendingJoinCode = code
                    }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.hasTeams {
                MainView()
                    .transition(.opacity)
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: model.hasTeams)
    }
}
