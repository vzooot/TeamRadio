import SwiftUI

/// "Call in your crew": opens the share sheet with the App Store link.
/// Nothing is sent by the app itself — the user picks the app and the person.
struct InviteBanner: View {
    private static let appStoreURL = URL(string: "https://apps.apple.com/app/id6804406860")!

    private let gradient = LinearGradient(colors: [Theme.accent, Theme.violet],
                                          startPoint: .leading, endPoint: .trailing)

    var body: some View {
        ShareLink(item: Self.appStoreURL,
                  subject: Text("Team Radio"),
                  message: Text("Join me in the Team Radio paddock — countdowns, results and live chat for every race weekend.")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    radioBadge
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.onAccent.opacity(0.15)))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("CALL IN YOUR CREW")
                        .font(.f1(34))
                        .foregroundStyle(Theme.onAccent)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("Race weekends are better with your friends in the Paddock.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.onAccent.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(gradient)
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invite friends to Team Radio")
    }

    /// Dark badge with a neon ring, like the helmet's visor light, holding the radio waves.
    private var radioBadge: some View {
        RadioWaves()
            .stroke(gradient, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            .overlay(Circle().fill(gradient).frame(width: 8.4, height: 8.4))
            .frame(width: 32, height: 32)
            .shadow(color: Theme.accent.opacity(0.9), radius: 4)
            .frame(width: 58, height: 58)
            .background(
                Circle()
                    .fill(Theme.onAccent)
                    .overlay(Circle().fill(RadialGradient(colors: [Theme.accent.opacity(0.25), .clear],
                                                          center: .center, startRadius: 0, endRadius: 29)))
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [Theme.accent, Theme.violet],
                                                                  startPoint: .topLeading, endPoint: .bottomTrailing),
                                                   lineWidth: 2))
                    .shadow(color: Theme.accent.opacity(0.55), radius: 7)
            )
    }
}

/// Two pairs of arcs either side of the centre, drawn in a 40×40 box (the dot is overlaid).
private struct RadioWaves: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let s = min(rect.width, rect.height) / 40
        var p = Path()
        // arcs plotted point by point (y points down, 180° = left): left pair 135°…225°, right pair −45°…45°
        for r in [9.6, 16.7] {
            for from in [135.0, -45.0] {
                for step in 0...18 {
                    let a = (from + Double(step) * 5) * .pi / 180
                    let pt = CGPoint(x: c.x + r * s * cos(a), y: c.y + r * s * sin(a))
                    step == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
            }
        }
        return p
    }
}

#Preview {
    InviteBanner()
        .padding()
        .background(Theme.background)
}
