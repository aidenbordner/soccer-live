import SwiftUI

/// First launch: a big door for parents and a smaller one for whoever runs the team.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showingJoin = false
    @State private var showingCreate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.32, blue: 0.16), Color(red: 0.02, green: 0.12, blue: 0.07)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            PitchLines().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                Image(systemName: "soccerball")
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: showingJoin)
                Text("Soccer Live")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 16)
                Text("Every goal, live, wherever you are.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 6)
                Spacer()

                VStack(spacing: 14) {
                    Button {
                        showingJoin = true
                    } label: {
                        VStack(spacing: 2) {
                            Text("Follow a team").font(.title3.weight(.bold))
                            Text("Use an invite link, QR code or team code").font(.footnote).opacity(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .buttonBorderShape(.roundedRectangle(radius: 16))

                    Button("Start a team") { showingCreate = true }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showingJoin) { JoinTeamView() }
        .sheet(isPresented: $showingCreate) { CreateTeamView() }
        .onChange(of: model.pendingJoinCode, initial: true) { _, code in
            if code != nil { showingJoin = true }
        }
    }
}

/// Faint center circle and halfway line behind the welcome screen.
private struct PitchLines: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height * 0.42))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.42))
                path.addEllipse(in: CGRect(x: size.width / 2 - 90, y: size.height * 0.42 - 90, width: 180, height: 180))
            }
            .stroke(.white.opacity(0.08), lineWidth: 3)
        }
    }
}
