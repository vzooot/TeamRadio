import QuartzCore
import SwiftUI
import UIKit

/// "Lights Out": the F1 start procedure as a reaction test. Five red lights
/// come on a second apart, hold for a random 0.2–3 s, go out, and the player
/// taps. Tapping before lights out is a jump start. Best time stays on the
/// device; the result can be shared with the App Store link.
struct LightsOutView: View {
    enum Phase: Equatable {
        case ready
        case lighting(Int)          // lights on so far
        case holding                // all five on, random wait
        case go(CFTimeInterval)     // lights out at this media time
        case result(Double)         // seconds
        case jumpStart
    }

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .ready
    @State private var sequence: Task<Void, Never>?
    @AppStorage("lightsOutBest") private var best: Double = 0
    @AppStorage("chatNickname") private var nickname = ""
    @State private var board: LeaderboardService.ReactionBoard?
    @State private var userId: String?

    private static let appStore = URL(string: "https://apps.apple.com/app/id6804406860")!

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(colors: [Theme.live.opacity(litCount > 0 ? 0.22 : 0.05), .clear],
                           center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.15), value: litCount)

            VStack(spacing: 28) {
                header
                Spacer(minLength: 0)
                gantry
                status
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture { tap() }
        .onDisappear { sequence?.cancel() }
        .task {
            StartSounds.shared.prepare()
            userId = await ChatService.currentUserId()
            board = await LeaderboardService.reaction(user: userId, name: nil, ms: nil)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("REACTION TEST")
                    .font(.f1(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.live)
                Text("LIGHTS OUT")
                    .font(.f1(28).italic())
                    .foregroundStyle(Theme.chromeText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.dimText)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .accessibilityLabel("Close")
        }
    }

    private var litCount: Int {
        switch phase {
        case .lighting(let n): n
        case .holding: 5
        default: 0
        }
    }

    /// The gantry as it hangs over the grid: five black housings on a
    /// crossbar, two large lamps each under a hood. Both lamps of a column
    /// light together.
    private var gantry: some View {
        ZStack(alignment: .top) {
            // the crossbar the housings hang from
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.3)], startPoint: .top, endPoint: .bottom))
                .frame(height: 10)
                .padding(.top, 34)
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { column in
                    let on = column < litCount
                    VStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { _ in lamp(on: on) }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(white: 0.13), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.1)))
                }
            }
        }
        .animation(.easeOut(duration: 0.05), value: litCount)
        .accessibilityElement()
        .accessibilityLabel("\(litCount) of 5 start lights on")
    }

    /// A round lamp under a hood: dark lens with a fine LED grid when off,
    /// glowing red when on.
    private func lamp(on: Bool) -> some View {
        ZStack {
            Circle().fill(on ? Theme.live : Color(white: 0.09))
            if on {
                Circle().fill(RadialGradient(colors: [Color.white.opacity(0.55), .clear],
                                             center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: 22))
            }
            // LED dot texture
            Circle()
                .fill(ImagePaint(image: Image(systemName: "circle.grid.3x3.fill"), scale: 0.18))
                .opacity(on ? 0.12 : 0.18)
            Circle().strokeBorder(Color.black.opacity(0.8), lineWidth: 3)
        }
        .frame(width: 46, height: 46)
        .overlay(alignment: .top) {
            // the hood above each lamp
            UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                .fill(Color(white: 0.06))
                .frame(width: 52, height: 8)
                .offset(y: -6)
        }
        .shadow(color: on ? Theme.live.opacity(0.95) : .clear, radius: 16)
    }

    @ViewBuilder
    private var status: some View {
        switch phase {
        case .ready:
            VStack(spacing: 18) {
                prompt("TAP ANYWHERE TO START", sub: "Wait for the lights to go out, then tap as fast as you can.")
                weeklyBoard
            }
        case .lighting, .holding:
            prompt("WAIT FOR IT…", sub: "Don't jump the start.")
        case .go:
            prompt("GO!", sub: " ")
        case .jumpStart:
            prompt("JUMP START", sub: "Drive-through penalty. Tap to try again.", color: Theme.live)
        case .result(let seconds):
            VStack(spacing: 8) {
                Text(String(format: "%.3f", seconds))
                    .font(.f1Digits(72))
                    .foregroundStyle(Theme.accent)
                    .shadow(color: Theme.accent.opacity(0.6), radius: 14)
                Text(Self.verdict(seconds))
                    .font(.f1(18).italic())
                    .foregroundStyle(.white)
                Text(seconds <= best ? "NEW PERSONAL BEST" : String(format: "Personal best %.3f · F1 drivers ≈ 0.200", best))
                    .font(.f1(11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(seconds <= best ? Color(red: 1, green: 0.75, blue: 0.2) : Theme.dimText)
                if let me = board?.me, let total = board?.total {
                    Text("THIS WEEK: #\(me.rank) OF \(total) · BEST \(String(format: "%.3f", Double(me.ms) / 1000))")
                        .font(.f1(11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.accent)
                }
                Text("Tap to go again")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faintText)
                    .padding(.top, 4)
            }
        }
    }

    private func prompt(_ title: String, sub: String, color: Color = .white) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.f1(30).italic())
                .foregroundStyle(color)
            Text(sub)
                .font(.system(size: 14))
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
        }
        .frame(minHeight: 150)
    }

    @ViewBuilder
    private var footer: some View {
        if case .result(let seconds) = phase {
            ShareLink(item: Self.appStore,
                      message: Text(String(format: "Lights out in %.3f s 🏁 Beat my reaction time on Team Radio:", seconds))) {
                Text("SHARE YOUR TIME")
            }
            .buttonStyle(GamePrimaryButtonStyle())
        } else if best > 0 {
            Text(String(format: "PERSONAL BEST  %.3f s", best))
                .font(.f1(13, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Theme.dimText)
        }
    }

    // MARK: - Logic

    private func tap() {
        switch phase {
        case .ready, .result, .jumpStart:
            start()
        case .lighting, .holding:
            sequence?.cancel()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            StartSounds.shared.buzz()
            phase = .jumpStart
        case .go(let out):
            let seconds = CACurrentMediaTime() - out
            if best == 0 || seconds < best { best = seconds }
            submit(seconds)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            StartSounds.shared.radioClick()
            phase = .result(seconds)
        }
    }

    private func start() {
        sequence?.cancel()
        phase = .lighting(0)
        sequence = Task { @MainActor in
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            for n in 1...5 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                phase = n == 5 ? .holding : .lighting(n)
                haptic.impactOccurred()
                StartSounds.shared.beep()
            }
            // Like the real procedure: a random hold before lights out.
            try? await Task.sleep(for: .seconds(Double.random(in: 0.2...3.0)))
            if Task.isCancelled { return }
            phase = .go(CACurrentMediaTime())
        }
    }

    /// Every finished run goes to the weekly board; the server keeps each
    /// player's best and ignores anything under 0.100 s.
    private func submit(_ seconds: Double) {
        guard let userId, !nickname.isEmpty else { return }
        let ms = Int((seconds * 1000).rounded())
        Task { if let updated = await LeaderboardService.reaction(user: userId, name: nickname, ms: ms) { board = updated } }
    }

    /// Top five this week, under the start prompt.
    @ViewBuilder
    private var weeklyBoard: some View {
        if let top = board?.top, !top.isEmpty {
            VStack(spacing: 6) {
                Text("FASTEST THIS WEEK")
                    .font(.f1(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.2))
                ForEach(top.prefix(5)) { e in
                    HStack {
                        Text("\(e.rank)").font(.f1(14)).foregroundStyle(Theme.dimText).frame(width: 24, alignment: .leading)
                        Text(e.name).font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(e.userId == userId ? Theme.accent : .white).lineLimit(1)
                        Spacer()
                        Text(String(format: "%.3f", Double(e.ms) / 1000)).font(.f1Digits(14)).foregroundStyle(.white)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
        } else if nickname.isEmpty {
            Text("Pick a Paddock name to get on the weekly leaderboard.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.faintText)
        }
    }

    static func verdict(_ s: Double) -> String {
        switch s {
        case ..<0.12: "Suspiciously fast… 👀"
        case ..<0.20: "Verstappen-level launch"
        case ..<0.25: "F1-ready reflexes"
        case ..<0.30: "Solid getaway"
        case ..<0.40: "Bogged down a bit"
        default: "Stalled on the grid"
        }
    }
}

/// Countdown-tab entry: the best time and a play button.
struct LightsOutCard: View {
    let onPlay: () -> Void
    @AppStorage("lightsOutBest") private var best: Double = 0

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle().fill(Theme.live).frame(width: 9, height: 9)
                            .shadow(color: Theme.live.opacity(0.8), radius: 4)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
                VStack(alignment: .leading, spacing: 3) {
                    Text("LIGHTS OUT")
                        .font(.f1(15).italic())
                        .foregroundStyle(.white)
                    Text(best > 0 ? String(format: "Your best: %.3f s · can you go under 0.200?", best)
                         : "Test your start reaction like an F1 driver")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dimText)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.live)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.live.opacity(0.35), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play Lights Out, the reaction test")
    }
}
