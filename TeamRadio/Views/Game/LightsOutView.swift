import QuartzCore
import SwiftUI
import UIKit

/// "Lights Out": the F1 start procedure as a reaction test. The player holds
/// a finger down like the clutch; five red lights come on a second apart,
/// hold for a random 0.2–3 s and go out, and the player lets go. Letting go
/// before lights out is a jump start. Best time stays on the device; the
/// result can be shared with the App Store link.
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
    @State private var fingerDown = false
    @AppStorage("lightsOutBest") private var best: Double = 0
    @AppStorage("lightsOutHistory") private var history = ""
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

            VStack(spacing: 22) {
                header
                Spacer(minLength: 0)
                gantry
                status
                Spacer(minLength: 0)
                controls
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onDisappear { sequence?.cancel() }
        .task {
            // After the slide-up, which stuttered when the engine started during it.
            try? await Task.sleep(for: .milliseconds(450))
            StartSounds.shared.prepare()
            // Clear a best saved before anticipated starts were caught.
            if best > 0, best < Self.minReaction { best = 0 }
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "LightsOutAutoStart") { start() }
            #endif
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

    /// The main screen's LED board, its five start lights driven by the
    /// sequence, on the same carbon panel as the countdown card, with the
    /// running timer underneath.
    private var gantry: some View {
        VStack(spacing: 16) {
            DotMatrixBoard(litLights: litCount, standby: phase == .ready)
                .alignedToContent()
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel("\(litCount) of 5 start lights on")
            ReactionTimer(phase: phase)
        }
        .padding(18)
        .background(
            CarbonFiber()
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.glassStroke, lineWidth: 1))
                .trioGlow(cornerRadius: 22)
        )
    }

    @ViewBuilder
    private var status: some View {
        switch phase {
        case .ready:
            VStack(spacing: 18) {
                prompt("HOLD THE BRAKE", sub: "The lights come on while you hold. Let go the moment they go out.")
                weeklyBoard
            }
        case .lighting, .holding:
            prompt("HOLD IT…", sub: "Don't let go before lights out.")
        case .go:
            prompt("LET GO!", sub: " ", color: Theme.accent)
        case .jumpStart:
            prompt("JUMP START", sub: "You let go too early. Drive-through penalty.", color: Theme.live)
        case .result(let seconds):
            VStack(spacing: 8) {
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
        .frame(minHeight: 90)
    }

    /// The brake pedal while a start is possible; after a run, START AGAIN
    /// (and sharing a good time). Only the pedal reacts to holding, so a
    /// stray touch elsewhere can't launch or end a run.
    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .ready, .lighting, .holding, .go:
            BrakePedal(pressed: fingerDown)
                // Down the instant the finger lands, up the instant it lifts
                // (a drag gesture waited to be recognised, so the pedal lagged).
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { down in
                    if down {
                        guard !fingerDown else { return }
                        fingerDown = true
                        press()
                    } else {
                        fingerDown = false
                        release()
                    }
                }, perform: {})
                .accessibilityElement()
                .accessibilityLabel("Brake pedal")
                .accessibilityHint("Hold to start the lights, release when they go out")
                .accessibilityAction(named: "Hold") { press() }
                .accessibilityAction(named: "Release") { release() }
        case .result(let seconds):
            HStack(spacing: 10) {
                Button { restart() } label: { Text("START AGAIN") }
                    .buttonStyle(GamePrimaryButtonStyle())
                ShareLink(item: Self.appStore,
                          message: Text(String(format: "Lights out in %.3f s 🏁 Beat my reaction time on Team Radio:", seconds))) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 50, height: 46)
                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.accent.opacity(0.5)))
                }
                .accessibilityLabel("Share your time")
            }
        case .jumpStart:
            Button { restart() } label: { Text("START AGAIN") }
                .buttonStyle(GamePrimaryButtonStyle())
        }
    }

    // MARK: - Logic

    /// Back to the grid: lights off, waiting for the pedal.
    private func restart() {
        sequence?.cancel()
        fingerDown = false
        phase = .ready
    }

    /// Pedal down: the brake is on and the start sequence begins.
    private func press() {
        guard phase == .ready else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        start()
    }

    /// Finger up: a jump start before lights out, the reaction after.
    private func release() {
        switch phase {
        case .ready, .result, .jumpStart:
            break
        case .lighting, .holding:
            jumpStart()
        case .go(let out):
            let seconds = CACurrentMediaTime() - out
            // Nobody reacts in under 0.1 s: that's anticipation, a jump
            // start (the server ignores such times too).
            guard seconds >= Self.minReaction else { return jumpStart() }
            if best == 0 || seconds < best { best = seconds }
            history = Self.appending(seconds, to: history)
            submit(seconds)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            StartSounds.shared.radioClick()
            phase = .result(seconds)
        }
    }

    static let minReaction = 0.1

    /// The last ten reaction times, oldest first, stored as "0.231,0.208,…".
    static func times(_ stored: String) -> [Double] {
        stored.split(separator: ",").compactMap { Double($0) }
    }

    static func appending(_ seconds: Double, to stored: String) -> String {
        (times(stored) + [seconds]).suffix(10).map { String(format: "%.3f", $0) }.joined(separator: ",")
    }

    private func jumpStart() {
        sequence?.cancel()
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        StartSounds.shared.buzz()
        phase = .jumpStart
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
                ForEach(top.prefix(3)) { e in
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

/// A brake pedal: ridged aluminium on a dark mount, tilting down and
/// glowing red while it's held.
private struct BrakePedal: View {
    let pressed: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color(white: pressed ? 0.30 : 0.42), Color(white: 0.16)],
                                         startPoint: .top, endPoint: .bottom))
                // grip ridges
                VStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { _ in
                        Capsule()
                            .fill(Color.black.opacity(0.55))
                            .frame(height: 6)
                            .overlay(alignment: .top) { Capsule().fill(Color.white.opacity(0.18)).frame(height: 1) }
                    }
                }
                .padding(.horizontal, 18)
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(pressed ? Theme.live : Color.white.opacity(0.18), lineWidth: pressed ? 2.5 : 1)
            }
            .frame(width: 112, height: 132)
            .rotation3DEffect(.degrees(pressed ? 22 : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
            .scaleEffect(pressed ? 0.96 : 1)
            .shadow(color: pressed ? Theme.live.opacity(0.7) : .black.opacity(0.6), radius: pressed ? 18 : 10, y: pressed ? 2 : 10)
            .animation(.spring(response: 0.12, dampingFraction: 0.8), value: pressed)
            Text(pressed ? "HOLDING…" : "HOLD THE BRAKE")
                .font(.f1(11, weight: .heavy))
                .tracking(2)
                .foregroundStyle(pressed ? Theme.live : Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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

/// The reaction clock: idle at 0.000, racing from lights out, frozen on
/// the tap, red on a jump start. Neon-tile frame like the countdown.
private struct ReactionTimer: View {
    let phase: LightsOutView.Phase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !isRunning)) { context in
            let (text, tint) = display(at: context.date)
            Text(text)
                .font(.f1Digits(64))
                .foregroundStyle(tint == Theme.live ? AnyShapeStyle(Theme.liveGradient) : AnyShapeStyle(Theme.chromeText))
                .shadow(color: tint.opacity(0.6), radius: 10)
                .contentTransition(.numericText())
                .animation(isRunning ? nil : .snappy(duration: 0.25), value: text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors: [Color(white: 0.03), Color(white: 0.09)], startPoint: .top, endPoint: .bottom))
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
                        RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.9), lineWidth: 3).blur(radius: 5)
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.95), tint, tint.opacity(0.8)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.2)
                    }
                )
                .shadow(color: tint.opacity(0.45), radius: 12)
                .overlay(alignment: .bottom) {
                    Text(caption)
                        .font(.f1(10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(tint.opacity(0.85))
                        .offset(y: 18)
                }
                .padding(.bottom, 14)
        }
    }

    private var isRunning: Bool {
        if case .go = phase { return true }
        return false
    }

    private var caption: String {
        switch phase {
        case .ready: "REACTION TIME"
        case .lighting, .holding: "WAIT FOR LIGHTS OUT"
        case .go: "LET GO!"
        case .result: "SECONDS"
        case .jumpStart: "JUMP START"
        }
    }

    private func display(at now: Date) -> (String, Color) {
        switch phase {
        case .go(let out):
            return (String(format: "%.3f", max(0, CACurrentMediaTime() - out)), Theme.accent)
        case .result(let s):
            return (String(format: "%.3f", s), Theme.accent)
        case .jumpStart:
            return ("JUMP", Theme.live)
        case .lighting, .holding:
            return ("0.000", Theme.live)
        case .ready:
            return ("0.000", Theme.accent)
        }
    }
}
