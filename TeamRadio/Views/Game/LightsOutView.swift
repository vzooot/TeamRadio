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
    /// How the last run went: a personal best, a better week, a climb.
    @State private var outcome: RunOutcome?
    @State private var showCelebration = false
    @State private var sequence: Task<Void, Never>?
    @State private var fingerDown = false
    @AppStorage("lightsOutBest") private var best: Double = 0
    @AppStorage("lightsOutHistory") private var history = ""
    @AppStorage("chatNickname") private var nickname = ""
    @State private var board: LeaderboardService.ReactionBoard?
    @State private var boardLoaded = false
    @State private var showFullBoard = false
    @State private var userId: String?

    private static let appStore = URL(string: "https://apps.apple.com/app/id6804406860")!

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(colors: [Theme.live.opacity(litCount > 0 ? 0.22 : 0.05), .clear],
                           center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.15), value: litCount)

            // Nothing moves or disappears during a run: the lights at their
            // full size, one status line, the week's board (also after a
            // jump start), the start button.
            VStack(spacing: 14) {
                VStack(spacing: 14) {
                    header
                    gantry
                        .fixedSize(horizontal: false, vertical: true)
                    status
                        .frame(height: 64)
                    weeklyBoard
                }
                // After every run, its card over the screen; the start button
                // (drawn after it) stays lit above the dim to go again.
                .overlay {
                    if showCelebration, case .result(let seconds) = phase, let outcome {
                        RunCard(seconds: seconds, outcome: outcome, verdict: Self.verdict(seconds),
                                week: board?.me.map { (rank: $0.rank, total: board?.total ?? 0) }) { showCelebration = false }
                            .transition(.opacity)
                    }
                }
                .zIndex(1)
                Spacer(minLength: 0)
                controls
                    .zIndex(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .animation(.easeOut(duration: 0.2), value: showCelebration)
        .onDisappear { sequence?.cancel() }
        .task {
            // After the slide-up, which stuttered when the engine started during it.
            try? await Task.sleep(for: .milliseconds(450))
            StartSounds.shared.prepare()
            // Clear a best saved before anticipated starts were caught.
            if best > 0, best < Self.minReaction { best = 0 }
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "LightsOutAutoStart") { start() }
            // -ShowFullBoard YES: opens the full board, for screenshots
            if UserDefaults.standard.bool(forKey: "ShowFullBoard") { showFullBoard = true }
            // -LightsOutPhase jump|0.234: shows that end of a run, for screenshots
            switch UserDefaults.standard.string(forKey: "LightsOutPhase") {
            case "jump"?: phase = .jumpStart
            case let value?:
                if let seconds = Double(value) {
                    phase = .result(seconds)
                    // -DemoOutcome pb|week|normal: how that run went
                    switch UserDefaults.standard.string(forKey: "DemoOutcome") {
                    case "pb"?: outcome = RunOutcome(personalBest: true, previousBest: 0.246, weekBest: true, climb: 8)
                    case "week"?: outcome = RunOutcome(personalBest: false, previousBest: 0.150, weekBest: true, climb: 3)
                    default: outcome = RunOutcome(personalBest: false, previousBest: 0.150)
                    }
                    showCelebration = true
                }
            case nil: break
            }
            #endif
            userId = await ChatService.currentUserId()
            if let userId { await LeaderboardService.syncBests(user: userId) }
            board = await LeaderboardService.reaction(user: userId, name: nil, ms: nil)
            boardLoaded = true
        }
        .sheet(isPresented: $showFullBoard) {
            ArcadeFullBoard(game: .lightsOut, userId: userId)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
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
            prompt("HOLD TO START", sub: "Let go the moment the lights go out.")
        case .lighting, .holding:
            prompt("HOLD IT…", sub: "Don't let go before lights out.")
        case .go:
            prompt("LET GO!", sub: " ", color: Theme.accent)
        case .jumpStart:
            prompt("JUMP START", sub: "You let go too early. Hold to try again.", color: Theme.live)
        case .result(let seconds):
            resultStatus(seconds)
        }
    }

    private var isResult: Bool {
        if case .result = phase { return true }
        return false
    }

    private var celebrating: Bool { isResult && outcome?.personalBest == true }

    /// A personal best gets the gold treatment; a better week says so and
    /// how many places it gained; any other run shows the gap to your best.
    @ViewBuilder
    private func resultStatus(_ seconds: Double) -> some View {
        let gain = (outcome?.previousBest ?? 0) - seconds
        if celebrating {
            let sub = (outcome?.previousBest ?? 0) > 0 ? String(format: "%.3f FASTER THAN YOUR OLD BEST", gain) : "YOUR FIRST TIME ON THE CLOCK"
            VStack(spacing: 6) {
                Text("NEW PERSONAL BEST")
                    .font(.f1(26).italic())
                    .foregroundStyle(Medal.goldGradient)
                    .shadow(color: Medal.gold.opacity(0.8), radius: 10)
                Text(sub).font(.f1(11, weight: .bold)).tracking(1.5).foregroundStyle(Medal.goldLight)
            }
        } else {
            VStack(spacing: 6) {
                Text(Self.verdict(seconds))
                    .font(.f1(22).italic())
                    .foregroundStyle(.white)
                if outcome?.weekBest == true {
                    Text("BEST THIS WEEK" + ((outcome?.climb ?? 0) > 0 ? " · UP \(outcome!.climb!) \(outcome!.climb == 1 ? "PLACE" : "PLACES")" : ""))
                        .font(.f1(12, weight: .heavy)).tracking(1.5)
                        .foregroundStyle(Theme.accent)
                        .shadow(color: Theme.accent.opacity(0.6), radius: 6)
                } else {
                    Text(String(format: "+%.3f OFF YOUR BEST %.3f", -gain, outcome?.previousBest ?? best))
                        .font(.f1(12, weight: .heavy)).tracking(1.5)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private func prompt(_ title: String, sub: String, color: Color = .white) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.f1(24).italic())
                .foregroundStyle(color)
            Text(sub)
                .font(.system(size: 14))
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
        }
    }

    /// The start button: hold to start, and after a run hold START AGAIN
    /// (sharing a good time beside it). Only the button reacts to holding,
    /// so a stray touch elsewhere can't launch or end a run.
    @ViewBuilder
    private var controls: some View {
        StartButton(title: startTitle, pressed: fingerDown)
            // Down the instant the finger lands, up the instant it lifts
            // (a drag gesture waited to be recognised, so the button lagged).
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { down in
                if down {
                    guard !fingerDown else { return }
                    // After a run, holding the button starts the next one.
                    switch phase {
                    case .result, .jumpStart: restart()
                    default: break
                    }
                    fingerDown = true
                    press()
                } else {
                    fingerDown = false
                    release()
                }
            }, perform: {})
            .accessibilityElement()
            .accessibilityLabel(startTitle.0 + " " + startTitle.1)
            .accessibilityHint("Hold to start the lights, release when they go out")
            .accessibilityAction(named: "Hold") { press() }
            .accessibilityAction(named: "Release") { release() }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if case .result(let seconds) = phase {
                    ShareLink(item: Self.appStore,
                              message: Text(String(format: "Lights out in %.3f s 🏁 Beat my reaction time on Team Radio:", seconds))) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 52, height: 52)
                            .background(Circle().strokeBorder(Theme.accent.opacity(0.5)))
                    }
                    .accessibilityLabel("Share your time")
                }
            }
    }

    /// The big word and the small one on the start button.
    private var startTitle: (String, String) {
        switch phase {
        case .ready: ("HOLD", "TO START")
        case .lighting, .holding, .go: ("HOLD", "LET GO ON LIGHTS OUT")
        case .result, .jumpStart: ("START", "AGAIN")
        }
    }

    // MARK: - Logic

    /// Back to the grid: lights off, waiting for the pedal.
    private func restart() {
        sequence?.cancel()
        outcome = nil
        showCelebration = false
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
            let previous = best
            let personalBest = previous == 0 || seconds < previous
            if personalBest { best = seconds }
            outcome = RunOutcome(personalBest: personalBest, previousBest: previous)
            history = Self.appending(seconds, to: history)
            submit(seconds)
            if personalBest {
                ArcadeHaptics.finished(personalBest: true)
            } else {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            StartSounds.shared.radioClick()
            phase = .result(seconds)
            showCelebration = true
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
        let before = board?.me
        Task {
            guard let updated = await LeaderboardService.reaction(user: userId, name: nickname, ms: ms) else { return }
            board = updated
            // A better time this week, and how many places it gained.
            if let me = updated.me, me.ms == ms, before.map({ ms < $0.ms }) ?? true, case .result(let s) = phase, s == seconds {
                outcome?.weekBest = true
                outcome?.climb = before.map { $0.rank - me.rank }
            }
        }
    }

    /// This week's podium and your place; the full board behind it.
    private var weeklyBoard: some View {
        ArcadeBoardCard(game: .lightsOut, standing: board.map(ArcadeGame.from), loaded: boardLoaded,
                        celebrate: isResult && outcome?.weekBest == true, climb: isResult ? outcome?.climb : nil,
                        hasName: !nickname.isEmpty) { showFullBoard = true }
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

/// The big round start button (approved draft A, build/mockups/
/// start-button.png): a dark glass disc in a neon ring, cyan at rest and
/// red while held. Hold it, the lights come on; let go when they go out.
private struct StartButton: View {
    let title: (String, String)
    let pressed: Bool

    var body: some View {
        ZStack {
            ring
            VStack(spacing: 2) {
                Text(title.0).font(.f1(26).italic())
                Text(title.1).font(.f1(9, weight: .heavy)).tracking(1.5).multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            .frame(width: 120)
        }
        .frame(width: 158, height: 158)
        .scaleEffect(pressed ? 0.94 : 1)
        .animation(.spring(response: 0.14, dampingFraction: 0.75), value: pressed)
        .contentShape(Circle())
    }

    private var ring: some View {
        let tint = pressed ? Theme.live : Theme.accent
        return ZStack {
            Circle().fill(RadialGradient(colors: [Color(white: 0.16), Color(white: 0.04)], center: .top, startRadius: 0, endRadius: 160))
            Circle().strokeBorder(tint, lineWidth: 5)
                .shadow(color: tint.opacity(0.9), radius: 6)
                .shadow(color: tint.opacity(0.6), radius: pressed ? 26 : 16)
            Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1).padding(10)
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

/// How a finished run went.
struct RunOutcome: Equatable {
    var personalBest: Bool
    /// The best before this run (0 if there was none).
    var previousBest: Double
    /// A better time on this week's board than before.
    var weekBest = false
    /// Places gained on this week's board.
    var climb: Int?
}

/// Lights Out's card after every run (approved draft B,
/// build/mockups/result-drafts.png): what the run says, in times.
private struct RunCard: View {
    let seconds: Double
    let outcome: RunOutcome
    let verdict: String
    let week: (rank: Int, total: Int)?
    let close: () -> Void

    var body: some View {
        let tier: ArcadeResultCard.Tier = outcome.personalBest ? .best : outcome.weekBest ? .week : .run
        ArcadeResultCard(
            tier: tier,
            title: tier == .best ? "NEW PERSONAL BEST" : tier == .week ? "BEST THIS WEEK" : verdict.uppercased(),
            value: String(format: "%.3f", seconds), unit: nil,
            detail: tier == .best
                ? (outcome.previousBest > 0 ? String(format: "%.3f faster than your old best", outcome.previousBest - seconds)
                                            : "Your first time on the clock")
                : tier == .week ? verdict
                : String(format: "+%.3f off your best %.3f", seconds - outcome.previousBest, outcome.previousBest),
            extra: nil,
            place: ArcadeResultCard.place(climb: outcome.climb, week: week),
            close: close)
    }
}
