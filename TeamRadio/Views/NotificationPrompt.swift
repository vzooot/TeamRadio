import SwiftUI

/// First-launch ask for notifications, before iOS's own question: one
/// sentence on what you get, then the system prompt on "Turn on alerts".
/// Shown once (NotificationManager.shouldPrompt).
struct NotificationPrompt: View {
    let onDone: () -> Void
    @State private var asking = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.accent.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 140, height: 140)
                Image(systemName: "bell.badge")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(Theme.accentGradient)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                HStack(spacing: 9) {
                    TrioSlashes(height: 20)
                    Text("NEVER MISS LIGHTS OUT")
                        .font(.f1(24).italic())
                        .foregroundStyle(Theme.chromeText)
                }
                Text("Get a heads-up before every session and when your picks are about to lock.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button {
                    guard !asking else { return }
                    asking = true
                    Task {
                        _ = await NotificationManager.acceptPrompt()
                        onDone()
                    }
                } label: { Text("TURN ON ALERTS") }
                    .buttonStyle(GamePrimaryButtonStyle())
                Button {
                    NotificationManager.declinePrompt()
                    onDone()
                } label: {
                    Text("Not now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: 480)
        .interactiveDismissDisabled(asking)
    }
}
