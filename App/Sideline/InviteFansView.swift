import CoreImage.CIFilterBuiltins
import ScoreboardUI
import SoccerModels
import SwiftUI

/// The team code three ways: a link for the group chat, a QR code to show at the field, and the
/// code itself to read out.
struct InviteFansView: View {
    @Environment(\.dismiss) private var dismiss
    let team: Team

    private var link: URL { InviteCode.joinURL(for: team.fanCode) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Parents scan this or tap the link to follow \(team.name). No account needed.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    if let qr = QRCode.image(for: link.absoluteString) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260)
                            .padding(20)
                            .background(.white, in: RoundedRectangle(cornerRadius: 24))
                            .accessibilityLabel("QR code to follow \(team.name)")
                    }

                    VStack(spacing: 4) {
                        Text("Team code").font(.caption).foregroundStyle(.secondary)
                        Text(team.fanCode)
                            .font(.system(size: 40, weight: .heavy, design: .monospaced))
                            .kerning(4)
                            .textSelection(.enabled)
                    }

                    ShareLink(
                        item: link,
                        subject: Text("Follow \(team.name) live"),
                        message: Text("Follow \(team.name)'s games live in Soccer Live. Team code: \(team.fanCode)")
                    ) {
                        Label("Share invite link", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Invite fans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

enum QRCode {
    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
