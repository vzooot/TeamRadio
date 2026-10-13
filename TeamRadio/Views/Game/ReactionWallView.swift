import QuartzCore
import SwiftUI
import UIKit

/// "Reaction Wall": the drivers' reflex-board drill. Eleven lights on two
/// arcs; one lights up at a time and the player hits it as fast as they
/// can for 60 seconds. Cyan lights stay until hit (1 point); red ones are
/// worth 2 but go out after 0.9 s. Best score stays on the device and goes
/// to the weekly board. Approved draft:
/// Marketing/drafts/2026-10-13/reaction-wall-W1-W2-W3.png (W2).
struct ReactionWallView: View {
    enum Phase: Equatable {
        case ready
        case countdown(Int)
        case running(end: Date)
        case finished(Run)
    }

    struct Run: Equatable {
        var score = 0
        var hits = 0
        var misses = 0
        var reactions: [Double] = []
        var averageReaction: Double? { reactions.isEmpty ? nil : reactions.reduce(0, +) / Double(reactions.count) }
    }

    struct Target: Equatable {
        let pad: Int
        let double: Bool
        let litAt: CFTimeInterval
        let serial: Int
    }

    static let duration: TimeInterval = 60
    static let outer = 7
    static let inner = 4
    private static let redLife: Duration = .milliseconds(900)
    private static let appStore = URL(string: "https://apps.apple.com/app/id6804406860")!

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .ready
    @State private var run = Run()
    @State private var target: Target?
    @State private var serial = 0
    @State private var flash: Int?
    @State private var game: Task<Void, Never>?
    @AppStorage("wallBest") private var best = 0
    @AppStorage("chatNickname") private var nickname = ""
    @State private var board: LeaderboardService.WallBoard?
    @State private var userId: String?
    @State private var newBest = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(colors: [Theme.accent.opacity(isRunning ? 0.18 : 0.08), .clear],
                           center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                header
                wall
                status
                Spacer(minLength: 0)
                controls
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onDisappear { game?.cancel() }
        .task {
            StartSounds.shared.prepare()
            #if DEBUG
            // -WallDemo YES: starts and plays itself, for screenshots and videos
            if UserDefaults.standard.bool(forKey: "WallDemo") { autoplay() }
            #endif
            userId = await ChatService.currentUserId()
            board = await LeaderboardService.wall(user: userId, name: nil, score: nil)
        }
    }

    private var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRAINING")
                    .font(.f1(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.accent)
                Text("REACTION WALL")
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

    /// The board: seven lights on the outer arc, four on the inner, the
    /// score in the middle and the clock underneath, on carbon.
    private var wall: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let c = CGPoint(x: w / 2, y: w * 0.58)
            ZStack {
                ForEach([0.43, 0.25], id: \.self) { r in
                    Circle()
                        .trim(from: 0.36, to: 0.78)
                        .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                        .rotationEffect(.degrees(90))
                        .frame(width: w * r * 2, height: w * r * 2)
                        .position(c)
                }
                ForEach(0..<(Self.outer + Self.inner), id: \.self) { i in
                    let isOuter = i < Self.outer
                    pad(i, size: isOuter ? 62 : 54)
                        .position(isOuter
                                  ? Self.point(i, of: Self.outer, radius: w * 0.43, center: c, spread: 230)
                                  : Self.point(i - Self.outer, of: Self.inner, radius: w * 0.25, center: c, spread: 200))
                }
                VStack(spacing: 8) {
                    LEDText(text: centre, pitch: 6, color: centreColor)
                        .contentTransition(.identity)
                    Text(centreCaption)
                        .font(.f1(9, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(Theme.dimText)
                }
                .position(x: c.x, y: c.y + 4)
                clock
                    .position(x: c.x, y: geo.size.height - 44)
            }
            .background(CarbonFiber().clipShape(RoundedRectangle(cornerRadius: 28)))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Theme.glassStroke))
            .trioGlow(cornerRadius: 28, opacity: isRunning ? 0.7 : 0.4)
        }
        .aspectRatio(0.86, contentMode: .fit)
    }

    private func pad(_ i: Int, size: CGFloat) -> some View {
        let lit = target?.pad == i
        let tint = target?.double == true ? Theme.live : Theme.accent
        return WallPad(lit: lit || flash == i, tint: flash == i ? .white : tint, size: size)
            .scaleEffect(flash == i ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: flash)
            .contentShape(Circle())
            // Touch-down counts, like a real button: no waiting for the finger to lift.
            .onLongPressGesture(minimumDuration: 0, maximumDistance: 30, pressing: { down in
                if down { hit(i) }
            }, perform: {})
            .accessibilityElement()
            .accessibilityLabel(lit ? "Light \(i + 1), lit" : "Light \(i + 1)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { hit(i) }
    }

    private var centre: String {
        switch phase {
        case .ready: best > 0 ? "\(best)" : "0"
        case .countdown(let n): "\(n)"
        case .running, .finished: "\(run.score)"
        }
    }

    private var centreColor: Color {
        if case .countdown = phase { return Theme.live }
        return Theme.accent
    }

    private var centreCaption: String {
        switch phase {
        case .ready: best > 0 ? "YOUR BEST" : "POINTS"
        case .countdown: "GET READY"
        case .running, .finished: "POINTS"
        }
    }

    /// Seconds left, in amber LEDs; red for the last ten.
    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let left = secondsLeft(at: context.date)
            VStack(spacing: 6) {
                LEDText(text: String(format: "%02d", left), pitch: 4,
                        color: left <= 10 && isRunning ? Theme.live : Color(red: 1, green: 0.42, blue: 0.12))
                Text("SECONDS LEFT")
                    .font(.f1(9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Theme.dimText)
            }
        }
    }

    private func secondsLeft(at now: Date) -> Int {
        switch phase {
        case .running(let end): max(0, Int(ceil(end.timeIntervalSince(now))))
        case .finished: 0
        default: Int(Self.duration)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch phase {
        case .ready:
            VStack(spacing: 16) {
                Text("Hit each light the moment it comes on. Cyan: 1 point. Red: 2 points, but gone in under a second.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.dimText)
                    .multilineTextAlignment(.center)
                weeklyBoard
            }
        case .countdown, .running:
            HStack(spacing: 18) {
                stat("\(run.hits)", "HITS")
                stat("\(run.misses)", "MISSES")
                stat(run.averageReaction.map { String(format: "%.3f", $0) } ?? "-.---", "AVG REACTION")
            }
        case .finished(let result):
            VStack(spacing: 8) {
                Text(newBest ? "NEW PERSONAL BEST" : Self.verdict(result.score))
                    .font(.f1(18).italic())
                    .foregroundStyle(newBest ? Color(red: 1, green: 0.75, blue: 0.2) : .white)
                Text("\(result.hits) hits · \(result.misses) misses" + (result.averageReaction.map { String(format: " · avg %.3f s", $0) } ?? ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.dimText)
                if let me = board?.me, let total = board?.total {
                    Text("THIS WEEK: #\(me.rank) OF \(total) · BEST \(me.score)")
                        .font(.f1(11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.f1Digits(20)).foregroundStyle(.white)
            Text(label).font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .ready:
            Button { start() } label: { Text("START") }
                .buttonStyle(GamePrimaryButtonStyle())
        case .countdown, .running:
            Button { stop() } label: { Text("STOP") }
                .buttonStyle(GameOutlineButtonStyle())
        case .finished(let result):
            HStack(spacing: 10) {
                Button { start() } label: { Text("GO AGAIN") }
                    .buttonStyle(GamePrimaryButtonStyle())
                ShareLink(item: Self.appStore,
                          message: Text("\(result.score) points on the Reaction Wall 🟦 Can you beat my reflexes on Team Radio?")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 50, height: 46)
                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.accent.opacity(0.5)))
                }
                .accessibilityLabel("Share your score")
            }
        }
    }

    /// Top three this week, under the rules.
    @ViewBuilder
    private var weeklyBoard: some View {
        if let top = board?.top, !top.isEmpty {
            VStack(spacing: 6) {
                Text("MOST POINTS THIS WEEK")
                    .font(.f1(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.2))
                ForEach(top.prefix(3)) { e in
                    HStack {
                        Text("\(e.rank)").font(.f1(14)).foregroundStyle(Theme.dimText).frame(width: 24, alignment: .leading)
                        Text(e.name).font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(e.userId == userId ? Theme.accent : .white).lineLimit(1)
                        Spacer()
                        Text("\(e.score)").font(.f1Digits(14)).foregroundStyle(.white)
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

    // MARK: - Game

    private func start() {
        game?.cancel()
        run = Run()
        target = nil
        newBest = false
        game = Task { @MainActor in
            for n in stride(from: 3, through: 1, by: -1) {
                phase = .countdown(n)
                StartSounds.shared.beep()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            phase = .running(end: Date.now.addingTimeInterval(Self.duration))
            next()
            try? await Task.sleep(for: .seconds(Self.duration))
            if Task.isCancelled { return }
            finish()
        }
    }

    private func stop() {
        game?.cancel()
        target = nil
        phase = .ready
    }

    private func finish() {
        target = nil
        StartSounds.shared.radioClick()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if run.score > best {
            newBest = best > 0
            best = run.score
        }
        phase = .finished(run)
        guard let userId, !nickname.isEmpty, run.score > 0 else { return }
        let score = run.score
        Task { if let updated = await LeaderboardService.wall(user: userId, name: nickname, score: score) { board = updated } }
    }

    /// Light the next pad: never the one just hit; after the first five
    /// seconds, about one in five is a red double that goes out on its own.
    private func next() {
        guard case .running(let end) = phase else { return }
        let count = Self.outer + Self.inner
        var pad = Int.random(in: 0..<count)
        if pad == target?.pad { pad = (pad + Int.random(in: 1..<count)) % count }
        let elapsed = Self.duration - end.timeIntervalSinceNow
        let double = elapsed > 5 && Int.random(in: 0..<5) == 0
        serial += 1
        let lit = Target(pad: pad, double: double, litAt: CACurrentMediaTime(), serial: serial)
        target = lit
        if double {
            Task { @MainActor in
                try? await Task.sleep(for: Self.redLife)
                if target?.serial == lit.serial { next() }
            }
        }
    }

    private func hit(_ pad: Int) {
        guard case .running = phase else { return }
        if let lit = target, lit.pad == pad {
            run.hits += 1
            run.score += lit.double ? 2 : 1
            run.reactions.append(CACurrentMediaTime() - lit.litAt)
            UIImpactFeedbackGenerator(style: lit.double ? .heavy : .light).impactOccurred()
            flash = pad
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                if flash == pad { flash = nil }
            }
            next()
        } else {
            run.misses += 1
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
        }
    }

    #if DEBUG
    private func autoplay() {
        start()
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 330...620)))
                guard case .running = phase else {
                    if case .finished = phase { return }
                    continue
                }
                if let lit = target { hit(lit.pad) }
            }
        }
    }
    #endif

    static func verdict(_ score: Int) -> String {
        switch score {
        case 90...: "Race-winner reflexes"
        case 70..<90: "Points finish"
        case 50..<70: "Solid stint"
        case 30..<50: "Warming the tyres"
        default: "Back to the simulator"
        }
    }

    static func point(_ i: Int, of n: Int, radius: CGFloat, center: CGPoint, spread: Double) -> CGPoint {
        let start = -90 - spread / 2
        let angle = (start + spread * Double(i) / Double(n - 1)) * .pi / 180
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}

/// One Reaction Wall light: a dark housing, a ring of LEDs and the glass
/// lens, glowing when it's the one to hit.
struct WallPad: View {
    var lit = false
    var tint: Color = Theme.accent
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            ForEach(0..<18, id: \.self) { i in
                Circle()
                    .fill(lit ? tint : Color.white.opacity(0.07))
                    .frame(width: size * 0.06, height: size * 0.06)
                    .offset(y: -size * 0.40)
                    .rotationEffect(.degrees(Double(i) * 20))
            }
            Circle()
                .fill(lit
                      ? RadialGradient(colors: [.white, tint, tint.opacity(0.55)], center: .init(x: 0.42, y: 0.38), startRadius: 0, endRadius: size * 0.34)
                      : RadialGradient(colors: [Color(white: 0.17), Color(white: 0.06)], center: .init(x: 0.42, y: 0.38), startRadius: 0, endRadius: size * 0.34))
                .padding(size * 0.2)
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                .padding(size * 0.24)
                .opacity(lit ? 0.9 : 0.25)
        }
        .frame(width: size, height: size)
        .shadow(color: lit ? tint.opacity(0.9) : .black.opacity(0.6), radius: lit ? 16 : 4, y: lit ? 0 : 3)
    }
}
