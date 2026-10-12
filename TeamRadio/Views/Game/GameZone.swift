import SceneKit
import SwiftUI
import UIKit

/// The game features on the Countdown tab, each its own card in its own
/// size: picks (the result after scoring) as a race-hero card, the AI
/// Strategist with the season duel in rings and 3D bars, driver of the day
/// as a bold yellow card with the team's suit, Lights Out as a photo strip,
/// and the Ask Emily bar. Approved draft:
/// Marketing/drafts/2026-10-12/game-zone-final-before-after-race.jpg
struct GameZone: View {
    @Bindable var game: GameViewModel
    let dotd: DotdModel
    /// Rounds in the season, for the duel chart's empty columns.
    var seasonRounds = 0
    let onPicks: () -> Void
    let onResult: () -> Void
    let onVote: () -> Void
    let onLightsOut: () -> Void
    let onEmily: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let state = game.cardState(at: now)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle("GAME ZONE")
                    Spacer()
                    if game.access == .ready, let text = headerChip(state, now: now) {
                        ZoneChip(text: text)
                    }
                }
                PicksHero(game: game, state: state, now: now, seasonRounds: seasonRounds,
                          onPicks: onPicks, onResult: onResult)
                if dotd.race != nil {
                    DotdBoldCard(model: dotd, now: now, onVote: onVote)
                        .id("dotdCard")
                }
                LightsStrip(onPlay: onLightsOut)
                EmilyBar(onTap: onEmily)
            }
        }
    }

    /// "LOCKS IN 2D 04H" while picks are open, then the state.
    private func headerChip(_ state: GameViewModel.CardState, now: Date) -> String? {
        switch state {
        case .open, .picked:
            guard let next = game.nextLock(at: now) else { return nil }
            return "LOCKS IN " + PicksCard.parts(until: next.date, now: now).prefix(2).joined(separator: " ")
        case .locked: return "LOCKED"
        case let .scored(race, _, _): return "SCORED · R\(race.round)"
        case .missed: return nil
        }
    }
}

// MARK: - Picks / result: the race-hero card

private struct PicksHero: View {
    @Bindable var game: GameViewModel
    let state: GameViewModel.CardState
    let now: Date
    let seasonRounds: Int
    let onPicks: () -> Void
    let onResult: () -> Void

    /// The race this card is about: the scored one, else the next.
    private var race: Race? {
        if case let .scored(race, _, _) = state { return race }
        return game.race
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let race {
                    Text("ROUND \(race.roundNumber)")
                        .font(.f1(13).italic())
                        .tracking(1)
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 7))
                }
                Spacer()
                Text(isScored ? "YOUR RESULT" : "YOUR PICKS")
                    .font(.f1(15).italic())
                    .foregroundStyle(Theme.dimText)
            }
            if let race {
                Text(PicksCard.shortName(race))
                    .font(.f1(30).italic())
                    .foregroundStyle(Theme.chromeText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            switch game.access {
            case .checking:
                ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 12)
            case .needsICloud:
                note("Sign in to iCloud in Settings to play. Your iCloud account is your player identity.")
            case .needsName:
                note("Pick a Paddock name in the Paddock tab first. It's how you appear on the leaderboard.")
            case .ready:
                content
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Theme.card, Theme.violet.opacity(0.16), Theme.accent.opacity(0.24)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    if let race {
                        Text(Flags.emoji(for: race.circuit.location.country))
                            .font(.system(size: 100))
                            .opacity(0.14)
                            .rotationEffect(.degrees(-12))
                            .offset(x: 14, y: -6)
                            .accessibilityHidden(true)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
                .trioGlow(cornerRadius: 20)
        )
    }

    private var isScored: Bool {
        if case .scored = state { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .missed:
            note("Picks for this round closed when the race started. The next round opens after the race.")
        case let .scored(_, score, prediction):
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("+\(score.total)").font(.f1Digits(52))
                    Text("PTS").font(.f1(16))
                }
                .foregroundStyle(Theme.accent)
                .shadow(color: Theme.accent.opacity(0.5), radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    if let me = game.lastBoard?.me, let total = game.lastBoard?.total {
                        Text("\(me.rank.ordinal) of \(total.formatted())")
                    }
                    Text("\(score.exactPicks) exact \(score.exactPicks == 1 ? "pick" : "picks")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.dimText)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            }
            strip(prediction, score: score)
            aiSection
            if let comment = game.lastBoard?.me?.comment {
                RadioComment(text: comment)
            }
            Button(action: onResult) { Text("SEE BREAKDOWN") }
                .buttonStyle(GameOutlineButtonStyle())
        case .locked:
            strip(current, score: nil)
            aiSection
            Label("All picks locked · scored after the race", systemImage: "lock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.dimText)
        case .open, .picked:
            strip(current, score: nil)
            aiSection
            Text(PicksCard.lockStatus(game, now: now))
                .font(.system(size: 12))
                .foregroundStyle(Theme.faintText)
            if state == .picked, current.isComplete {
                Button(action: onPicks) { Text("EDIT PICKS") }
                    .buttonStyle(GameOutlineButtonStyle())
            } else {
                Button(action: onPicks) { Text(state == .open ? "MAKE YOUR PICKS" : "FINISH YOUR PICKS") }
                    .buttonStyle(GamePrimaryButtonStyle())
            }
        }
    }

    private var current: Prediction { game.saved?.prediction ?? game.draft }

    /// The AI Strategist inside this card: its picks under yours, the
    /// scoreline and the season duel.
    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.violet.opacity(0.3)).frame(height: 1).padding(.bottom, 12)
            StrategistCard(game: game, state: state, seasonRounds: seasonRounds, embedded: true)
        }
        .id("strategist")
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.dimText)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One tile per pick: code and team colour, a cyan "+" where a pick is
    /// still open, a padlock where it locked empty, the points once scored.
    private func strip(_ p: Prediction, score: ScoreBreakdown?) -> some View {
        let picks: [(String, String?, ScoreBreakdown.Kind, PickGroup)] =
            (p.hasSprint ? [("SPR", p.sprintWinner, .sprint, .sprint)] : []) + [
                ("POLE", p.pole, .pole, .quali), ("P1", p.p1, .p1, .race), ("P2", p.p2, .p2, .race),
                ("P3", p.p3, .p3, .race), ("FL", p.fastestLap, .fastestLap, .race),
            ]
        return HStack(spacing: 6) {
            ForEach(picks, id: \.0) { label, id, kind, group in
                let driver = game.driver(id)
                let open = id == nil && score == nil && !game.isLocked(group, at: now)
                VStack(spacing: 3) {
                    Text(label).font(.f1(10, weight: .bold)).tracking(1).foregroundStyle(Theme.faintText)
                    if let driver {
                        Text(driver.code).font(.f1(15)).foregroundStyle(.white)
                    } else if open {
                        Text("+").font(.f1(15)).foregroundStyle(Theme.accent)
                    } else {
                        Text("—").font(.f1(15)).foregroundStyle(Theme.faintText)
                    }
                    Capsule()
                        .fill(driver.map { Theme.teamColor($0.teamId) } ?? (open ? Theme.accent.opacity(0.4) : .clear))
                        .frame(width: 18, height: 3)
                    if let item = score?.items.first(where: { $0.kind == kind }) {
                        Text(PicksStrip.mark(item))
                            .font(.f1(10, weight: .bold))
                            .foregroundStyle(PicksStrip.color(item.outcome))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.25)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(open ? Theme.accent.opacity(0.4) : .clear))
            }
        }
    }
}

// MARK: - AI Strategist

/// The AI's picks (sealed until the round is scored, then revealed with
/// their points) and the season duel: totals in rings, every round in 3D.
private struct StrategistCard: View {
    let game: GameViewModel
    let state: GameViewModel.CardState
    let seasonRounds: Int
    /// Inside the picks card: no card chrome of its own.
    var embedded = false
    @State private var history: [LeaderboardService.DuelRound]?
    @State private var revealed: LeaderboardService.PlayerPicks?
    /// The duel fills (rings sweep, bars grow) each time the card scrolls
    /// into view, and resets once it has left the screen.
    @State private var shown = false
    /// Round tapped in the 3D chart (index into the season).
    @State private var selected: Int?

    private var scored: (race: Race, score: ScoreBreakdown)? {
        if case let .scored(race, score, _) = state { return (race, score) }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "cpu")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.violet)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.violet.opacity(0.15)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI STRATEGIST").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                    Text(subtitle).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
                }
                Spacer(minLength: 4)
                if let scored, let ai = revealed?.points {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("YOU \(scored.score.total) · AI \(ai)").font(.f1(12, weight: .heavy)).foregroundStyle(.white)
                        Text(scored.score.total > ai ? "YOU WIN ✓" : scored.score.total == ai ? "DRAW" : "AI WINS")
                            .font(.f1(10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(scored.score.total > ai ? PicksStrip.color(.exact) : Theme.dimText)
                    }
                } else if scored == nil {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.violet)
                }
            }
            tiles
            if let rounds = history, !rounds.isEmpty {
                duel(rounds)
            }
        }
        .padding(embedded ? 0 : 16)
        .background {
            if !embedded {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Theme.card, Theme.violet.opacity(0.14)], startPoint: .leading, endPoint: .trailing))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.violet.opacity(0.35), lineWidth: 1))
            }
        }
        .onCardVisibility(show: {
            guard !shown else { return }
            withAnimation(.easeOut(duration: 1.1)) { shown = true }
        }, hide: {
            shown = false
            selected = nil
        })
        .task(id: scored?.race.id) {
            if let race = scored?.race {
                revealed = await LeaderboardService.playerPicks(round: race.id, user: "ai-strategist")
            }
            // Keep asking until the history arrives (offline, server busy).
            var player = await ChatService.currentUserId()
            #if DEBUG
            if player == nil, UserDefaults.standard.bool(forKey: "FakePicks") { player = "debug-player" }
            #endif
            guard let user = player else { return }
            while !Task.isCancelled {
                if let rounds = await LeaderboardService.history(user: user) {
                    history = rounds
                    return
                }
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    private var subtitle: String {
        if let race = scored?.race { return "Its \(race.raceName.replacingOccurrences(of: " Grand Prix", with: "")) picks, revealed" }
        if let race = game.race { return "Has picked R\(race.round) · revealed after the race" }
        return "Beat the AI every round"
    }

    private func duel(_ rounds: [LeaderboardService.DuelRound]) -> some View {
        // One column per round of the season; unscored rounds stay empty.
        let count = max(seasonRounds, rounds.map(\.round).max() ?? 0)
        let byRound = Dictionary(rounds.map { ($0.round, $0) }, uniquingKeysWith: { a, _ in a })
        let youCols = (1...max(count, 1)).map { byRound[$0]?.you.map(Double.init) }
        let aiCols = (1...max(count, 1)).map { byRound[$0]?.ai.map(Double.init) }
        let you = youCols.compactMap { $0 }
        let ai = aiCols.compactMap { $0 }
        // Rounds before the next race have been raced (lighter columns).
        let raced = min(count, max(0, (game.race?.roundNumber ?? count + 1) - 1))
        // A compact season line on top; the 3D bars get the full width below.
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                SeasonDuelRings(you: you.reduce(0, +), ai: ai.reduce(0, +), progress: shown ? 1 : 0, compact: true)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SEASON · \(rounds.count)/\(count)")
                        .font(.f1(9, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(Theme.faintText)
                    HStack(spacing: 10) {
                        CountingText(value: you.reduce(0, +) * (shown ? 1 : 0), prefix: "YOU ")
                            .foregroundStyle(Theme.accent)
                        CountingText(value: ai.reduce(0, +) * (shown ? 1 : 0), prefix: "AI ")
                            .foregroundStyle(Theme.violet)
                    }
                    .font(.f1(13, weight: .heavy))
                }
                Spacer(minLength: 6)
                if let selected {
                    // the tapped round
                    let round = byRound[selected + 1]
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("R\(selected + 1)\(round?.name.map { " · " + $0.replacingOccurrences(of: " Grand Prix", with: "").uppercased() } ?? "")")
                            .font(.f1(10, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let round {
                            Text("YOU \(round.you.map(String.init) ?? "—") · AI \(round.ai.map(String.init) ?? "—")")
                                .font(.f1(10, weight: .heavy))
                                .foregroundStyle(Theme.accent)
                        } else {
                            Text(selected < raced ? "NOT SCORED" : "TO COME")
                                .font(.f1(9, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.faintText)
                        }
                    }
                } else {
                    Text("DRAG · TAP A ROUND")
                        .font(.f1(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.faintText)
                }
            }
            SeasonDuelBars(you: youCols, ai: aiCols, raced: raced, grown: shown, selected: $selected)
                .frame(height: 150)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Season: you \(Int(you.reduce(0, +))) points, AI \(Int(ai.reduce(0, +))) points")
    }

    private func legend(_ s: String, _ c: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 6, height: 6).shadow(color: c, radius: 3)
            Text(s).font(.f1(9, weight: .heavy)).tracking(1).foregroundStyle(.white.opacity(0.8))
        }
    }

    /// Sealed "?" tiles, or the revealed picks with their points.
    private var tiles: some View {
        let order: [(String, String)] = (game.draft.hasSprint || revealed?.items?.contains { $0.kind == "sprint" } == true
                                        ? [("SPR", "sprint")] : []) +
            [("POLE", "pole"), ("P1", "p1"), ("P2", "p2"), ("P3", "p3"), ("FL", "fastestLap")]
        return HStack(spacing: 6) {
            ForEach(order, id: \.1) { label, kind in
                let item = scored == nil ? nil : revealed?.items?.first { $0.kind == kind }
                VStack(spacing: 3) {
                    Text(label).font(.f1(9, weight: .bold)).tracking(1).foregroundStyle(Theme.faintText)
                    if let item {
                        Text(game.driver(item.picked)?.code ?? "—").font(.f1(14)).foregroundStyle(.white)
                        Text(item.outcome == "miss" ? "✗ 0" : item.outcome == "exact" ? "✓ \(item.points)" : "~ \(item.points)")
                            .font(.f1(9, weight: .bold))
                            .foregroundStyle(item.outcome == "miss" ? PicksStrip.color(.miss)
                                             : item.outcome == "exact" ? PicksStrip.color(.exact) : PicksStrip.color(.partial))
                    } else {
                        Text("?").font(.f1(14)).foregroundStyle(Theme.violet)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.violet.opacity(item == nil ? 0.12 : 0.08)))
            }
        }
    }
}

/// Season totals as two concentric rings: you (cyan) outside, the AI
/// (violet) inside, each against the larger total.
private struct SeasonDuelRings: View {
    let you: Double
    let ai: Double
    /// 0 empty, 1 full; animating it sweeps the rings and counts the totals up.
    var progress: Double = 1
    /// Small badge: just the two rings, the totals sit beside it.
    var compact = false

    var body: some View {
        let top = max(you, ai, 1) * 1.08
        ZStack {
            ring(you / top * progress, Theme.accent, inset: 0)
            ring(ai / top * progress, Theme.violet, inset: compact ? 7 : 13)
            if !compact {
                VStack(spacing: 0) {
                    CountingText(value: you * progress, prefix: "")
                        .font(.f1Digits(18))
                        .foregroundStyle(.white)
                    CountingText(value: ai * progress, prefix: "VS ")
                        .font(.f1(9, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Theme.violet)
                }
            }
        }
    }

    private func ring(_ value: Double, _ color: Color, inset: CGFloat) -> some View {
        let width: CGFloat = compact ? 5 : 9
        return ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: width)
            Circle().trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.8), radius: compact ? 2 : 4)
        }
        .padding(inset)
    }
}

/// A number that counts while it animates (whole numbers, optional prefix).
private struct CountingText: View, Animatable {
    var value: Double
    let prefix: String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(prefix)\(Int(value.rounded()))").monospacedDigit()
    }
}

private extension View {
    /// Calls `show` once the card is mostly on screen, and `hide` only after
    /// it has left the screen completely (iOS 18+; on iOS 17 on appear and
    /// disappear).
    @ViewBuilder
    func onCardVisibility(show: @escaping () -> Void, hide: @escaping () -> Void) -> some View {
        if #available(iOS 18, *) {
            self
                .onScrollVisibilityChange(threshold: 0.5) { if $0 { show() } }
                .onScrollVisibilityChange(threshold: 0.01) { if !$0 { hide() } }
        } else {
            onAppear(perform: show).onDisappear(perform: hide)
        }
    }
}

/// Points per round as glowing 3D bars, you in front and the AI behind, in
/// a glass column per round of the season: lighter for rounds already
/// raced, darker for the ones to come (SceneKit, like the circuit map).
/// The chart swings on its own; drag sideways to turn it, tap a column to
/// pick a round. The bars rise when `grown` turns true.
private struct SeasonDuelBars: UIViewRepresentable {
    /// One entry per round of the season; nil where the round isn't scored.
    let you: [Double?]
    let ai: [Double?]
    /// Rounds already raced.
    var raced = 0
    var grown = true
    /// The tapped column (round index), if any.
    @Binding var selected: Int?

    private var key: [Double] { (you + ai).map { $0 ?? -1 } + [Double(raced)] }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.scene = Self.scene(you: you, ai: ai, raced: raced)
        let coordinator = context.coordinator
        coordinator.key = key
        coordinator.raced = raced
        coordinator.onSelect = { selected = $0 }
        view.addGestureRecognizer(UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.tapped(_:))))
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.panned(_:)))
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)
        Self.setGrown(grown, in: view, animated: false)
        coordinator.grown = grown
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSelect = { selected = $0 }
        if coordinator.key != key {
            coordinator.key = key
            coordinator.raced = raced
            view.scene = Self.scene(you: you, ai: ai, raced: raced)
            Self.setGrown(grown, in: view, animated: grown)
            coordinator.grown = grown
            coordinator.selected = nil
        } else if coordinator.grown != grown {
            coordinator.grown = grown
            Self.setGrown(grown, in: view, animated: grown)
        }
        if coordinator.selected != selected {
            coordinator.selected = selected
            Self.highlight(selected, raced: raced, in: view)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var key: [Double] = []
        var grown = true
        var raced = 0
        var selected: Int?
        var onSelect: ((Int?) -> Void)?

        /// Tap a bar or its column: select that round (again: deselect).
        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let hits = view.hitTest(gesture.location(in: view), options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            let column = hits.lazy.compactMap { hit -> Int? in
                guard let name = hit.node.name, name.hasPrefix("bar-") || name.hasPrefix("track-") else { return nil }
                return Int(name.split(separator: "-").last ?? "")
            }.first
            guard let column else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect?(column == selected ? nil : column)
        }

        /// Drag to turn the chart: sideways spins it, up and down tips it
        /// toward you or away. It moves on its own again a moment after you
        /// let go.
        @objc func panned(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView,
                  let tilt = view.scene?.rootNode.childNode(withName: "tilt", recursively: false),
                  let chart = tilt.childNode(withName: "chart", recursively: false) else { return }
            switch gesture.state {
            case .began:
                chart.removeAction(forKey: "swing")
                tilt.removeAction(forKey: "sway")
            case .changed:
                let t = gesture.translation(in: view)
                chart.eulerAngles.y += Float(t.x) * 0.012
                tilt.eulerAngles.x = min(0.55, max(-0.4, tilt.eulerAngles.x + Float(t.y) * 0.008))
                tilt.eulerAngles.z *= 0.9
                gesture.setTranslation(.zero, in: view)
            case .ended, .cancelled:
                let back = SCNAction.rotateTo(x: 0, y: CGFloat(SeasonDuelBars.restAngle), z: 0, duration: 0.9, usesShortestUnitArc: true)
                back.timingMode = .easeInEaseOut
                chart.runAction(.sequence([.wait(duration: 2.5), back, SeasonDuelBars.swing]), forKey: "swing")
                let level = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.7, usesShortestUnitArc: true)
                level.timingMode = .easeOut
                tilt.runAction(.sequence([level, .wait(duration: 2.7), SeasonDuelBars.sway]), forKey: "sway")
            default:
                break
            }
        }

        /// Only horizontal drags turn the chart; vertical ones scroll the page.
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard let pan = gesture as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y)
        }
    }

    static let restAngle: Float = -0.75

    /// A wide, eased swing so the depth is obvious.
    static var swing: SCNAction {
        let right = SCNAction.rotateBy(x: 0, y: 1.5, z: 0, duration: 3.2)
        right.timingMode = .easeInEaseOut
        let left = SCNAction.rotateBy(x: 0, y: -1.5, z: 0, duration: 3.2)
        left.timingMode = .easeInEaseOut
        return .repeatForever(.sequence([right, left]))
    }

    /// A slower tip and roll on the other axes, out of step with the swing,
    /// so the chart never moves the same way twice.
    static var sway: SCNAction {
        func step(_ x: CGFloat, _ z: CGFloat, _ duration: Double) -> SCNAction {
            let a = SCNAction.rotateTo(x: x, y: 0, z: z, duration: duration, usesShortestUnitArc: true)
            a.timingMode = .easeInEaseOut
            return a
        }
        return .repeatForever(.sequence([
            step(0.22, 0.05, 2.3),
            step(-0.12, -0.04, 2.6),
            step(0.08, 0.06, 2.1),
            step(0, 0, 2.0),
        ]))
    }

    /// Bars rise gently from a fifth of their height with a light stagger,
    /// or sit low and still until the card shows.
    private static func setGrown(_ grown: Bool, in view: SCNView, animated: Bool) {
        let low: Float = 0.2, duration = 0.55
        view.scene?.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, name.hasPrefix("bar-"), let column = Int(name.split(separator: "-").last ?? "") else { return }
            node.removeAction(forKey: "grow")
            guard grown, animated else {
                node.scale = SCNVector3(1, grown ? 1 : low, 1)
                return
            }
            node.scale = SCNVector3(1, low, 1)
            let rise = SCNAction.customAction(duration: duration) { node, elapsed in
                let t = Float(elapsed / duration)
                let eased = 1 - (1 - t) * (1 - t)   // ease out
                node.scale = SCNVector3(1, low + (1 - low) * eased, 1)
            }
            node.runAction(.sequence([.wait(duration: Double(column) * 0.02), rise]), forKey: "grow")
        }
    }

    private static let pastAlpha: CGFloat = 0.14
    private static let futureAlpha: CGFloat = 0.045

    /// The selected round's bars glow and its column brightens.
    private static func highlight(_ selected: Int?, raced: Int, in view: SCNView) {
        view.scene?.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, let column = Int(name.split(separator: "-").last ?? "") else { return }
            let on = column == selected
            if name.hasPrefix("bar-"), let material = node.geometry?.firstMaterial,
               let color = material.diffuse.contents as? UIColor {
                material.emission.contents = color.withAlphaComponent(on ? 0.95 : 0.35)
            } else if name.hasPrefix("track-") {
                let base = column < raced ? pastAlpha : futureAlpha
                node.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: on ? base + 0.16 : base)
            }
        }
    }

    private static func scene(you: [Double?], ai: [Double?], raced: Int) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        // tilt (x tip, z roll) carries chart (y swing): the axes move apart
        let tilt = SCNNode()
        tilt.name = "tilt"
        scene.rootNode.addChildNode(tilt)
        let chart = SCNNode()
        chart.name = "chart"
        tilt.addChildNode(chart)
        let n = max(you.count, ai.count, 1)
        let pitch: Float = min(0.42, 7.2 / Float(n))
        let x0 = -Float(n - 1) * pitch / 2
        let top = max(you.compactMap { $0 }.max() ?? 0, ai.compactMap { $0 }.max() ?? 0, 1)
        let full: CGFloat = 1.6
        let cyan = UIColor(red: 0.15, green: 0.82, blue: 1, alpha: 1)
        let violet = UIColor(red: 0.52, green: 0.42, blue: 1, alpha: 1)

        // A glass column per round: lighter for raced rounds, darker ahead.
        for row in 0..<2 {
            for i in 0..<n {
                let glass = SCNMaterial()
                glass.lightingModel = .constant
                glass.diffuse.contents = UIColor(white: 1, alpha: i < raced ? pastAlpha : futureAlpha)
                glass.writesToDepthBuffer = false
                glass.isDoubleSided = true
                let track = SCNBox(width: CGFloat(pitch * 0.7), height: full, length: CGFloat(pitch * 0.7), chamferRadius: 0.04)
                track.materials = [glass]
                let node = SCNNode(geometry: track)
                node.name = "track-\(row)-\(i)"
                node.position = SCNVector3(x0 + Float(i) * pitch, Float(full) / 2, row == 0 ? 0.22 : -0.22)
                node.renderingOrder = 10
                chart.addChildNode(node)
            }
        }

        for (row, values, color) in [(0, you, cyan), (1, ai, violet)] {
            for (i, value) in values.enumerated() {
                guard let v = value else { continue }
                let h = CGFloat(max(v, 0.3) / top) * full
                let box = SCNBox(width: CGFloat(pitch * 0.62), height: h, length: CGFloat(pitch * 0.62), chamferRadius: 0.04)
                let material = SCNMaterial()
                material.lightingModel = .lambert
                material.diffuse.contents = color.withAlphaComponent(row == 0 ? 1 : 0.85)
                material.emission.contents = color.withAlphaComponent(0.35)
                box.materials = [material]
                let node = SCNNode(geometry: box)
                node.name = "bar-\(row)-\(i)"
                // Pivot at the bottom face so the bar grows up from the floor.
                node.pivot = SCNMatrix4MakeTranslation(0, -Float(h) / 2, 0)
                node.position = SCNVector3(x0 + Float(i) * pitch, 0, row == 0 ? 0.22 : -0.22)
                chart.addChildNode(node)
            }
        }
        let floor = SCNNode(geometry: SCNBox(width: CGFloat(Float(n) * pitch + 0.3), height: 0.01, length: 0.9, chamferRadius: 0))
        floor.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.06)
        floor.geometry?.firstMaterial?.lightingModel = .constant
        chart.addChildNode(floor)

        chart.eulerAngles.y = restAngle
        chart.runAction(swing, forKey: "swing")
        tilt.runAction(sway, forKey: "sway")

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.eulerAngles = SCNVector3(-Float.pi / 3, 0.6, 0)
        scene.rootNode.addChildNode(sun)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 30
        // back far enough that the swing and tilt never reach the edges
        camera.position = SCNVector3(0, 3.9, 7.1)
        camera.look(at: SCNVector3(0, 0.35, 0))
        scene.rootNode.addChildNode(camera)
        return scene
    }
}

// MARK: - Driver of the day: bold yellow card

private struct DotdBoldCard: View {
    let model: DotdModel
    let now: Date
    let onVote: () -> Void

    /// Warm yellow flowing to amber, corner to corner (the user's pick,
    /// from the first card draft).
    private static var yellow: [Color] {
        #if DEBUG
        // -DotdTone 1|2|3: compare yellows on the real card
        switch UserDefaults.standard.integer(forKey: "DotdTone") {
        case 2: return [Color(red: 1, green: 0.78, blue: 0.2), Color(red: 0.98, green: 0.55, blue: 0.1)]   // golden
        case 3: return [Color(red: 1, green: 0.88, blue: 0.4), Color(red: 1, green: 0.72, blue: 0.24)]    // sunny
        default: break
        }
        #endif
        return [Color(red: 1, green: 0.84, blue: 0.35), Color(red: 1, green: 0.6, blue: 0.2)]              // original
    }
    private static let ink = Theme.onAccent

    /// The entrance plays each time the card scrolls in: the suit strides in,
    /// the star spins, a shine sweeps across, the bars fill and count up.
    @State private var shown = false

    private var voted: Bool { model.myVote != nil && !(model.tally?.votes.isEmpty ?? true) }

    /// The driver in the spotlight: the fans' leader once you've voted,
    /// before that the race winner.
    private var spotlight: GameDriver? {
        model.driver(voted ? model.tally?.votes.first?.driverId : model.drivers.first?.id)
    }

    var body: some View {
        Button(action: onVote) {
            VStack(alignment: .leading, spacing: 10) {
                header
                if let driver = spotlight { spotlightRow(driver) }
                if voted {
                    podium
                } else {
                    candidates
                }
                chips
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Driver of the day vote")
        .onCardVisibility(show: {
            guard !shown else { return }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) { shown = true }
        }, hide: {
            shown = false
        })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Self.yellow[0])
                    .rotationEffect(.degrees(shown ? 360 : 0))
                    .scaleEffect(shown ? 1 : 0.4)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Self.ink))
                    .shadow(color: Color.white.opacity(shown ? 0.8 : 0), radius: 8)
                Text(model.race.map { "FAN VOTE · R\($0.round) \(PicksCard.shortName($0))" } ?? "FAN VOTE")
                    .font(.f1(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Self.ink.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: 190, alignment: .leading)
            }
            Text("DRIVER OF THE DAY").font(.f1(22)).foregroundStyle(Self.ink)
        }
    }

    /// Big car number, name and team, and where they finished.
    private func spotlightRow(_ driver: GameDriver) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(driver.number ?? driver.code)
                .font(.f1Digits(44))
                .foregroundStyle(Self.ink)
                .shadow(color: .white.opacity(0.5), radius: 0, x: 1.5, y: 1.5)
            VStack(alignment: .leading, spacing: 2) {
                Text(voted ? "FANS' FAVOURITE" : "RACE WINNER")
                    .font(.f1(9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Self.ink.opacity(0.55))
                Text(driver.familyName.uppercased())
                    .font(.f1(17).italic())
                    .foregroundStyle(Self.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(teamLine(driver))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Self.ink.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 210, alignment: .leading)
    }

    /// "Ferrari · finished P3"
    private func teamLine(_ driver: GameDriver) -> String {
        let team = (driver.teamId ?? "")
            .split(separator: "_").map { $0.capitalized }.joined(separator: " ")
        guard model.driversInFinishingOrder, let i = model.drivers.firstIndex(where: { $0.id == driver.id }) else { return team }
        return team.isEmpty ? "Finished P\(i + 1)" : "\(team) · finished P\(i + 1)"
    }

    /// Before you vote: the podium three as candidates, and the call to vote.
    private var candidates: some View {
        HStack(spacing: 6) {
            if model.driversInFinishingOrder {
                ForEach(Array(model.drivers.prefix(3).enumerated()), id: \.element.id) { index, d in
                    HStack(spacing: 4) {
                        Text("P\(index + 1)").font(.f1(9, weight: .heavy)).foregroundStyle(Self.ink.opacity(0.55))
                        Text(d.code).font(.f1(12)).foregroundStyle(Self.ink)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Capsule().fill(Self.ink.opacity(0.1)))
                }
            }
            Text("TAP TO VOTE")
                .font(.f1(11).italic())
                .tracking(1.2)
                .foregroundStyle(Self.yellow[0])
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Self.ink))
                .phaseAnimator([1.0, 1.06]) { pill, scale in
                    pill.scaleEffect(scale)
                } animation: { _ in .easeInOut(duration: 0.9) }
        }
    }

    /// Votes so far, your vote, time left.
    private var chips: some View {
        HStack(spacing: 6) {
            chip(Image(systemName: "person.2.fill"), "\(model.tally?.total ?? 0) \(model.tally?.total == 1 ? "VOTE" : "VOTES")")
            if let mine = model.driver(model.myVote)?.code {
                chip(Image(systemName: "checkmark"), "YOU: \(mine)")
            }
            if let left = timeLeft {
                chip(Image(systemName: "clock.fill"), left)
            }
        }
    }

    private func chip(_ icon: Image, _ text: String) -> some View {
        HStack(spacing: 4) {
            icon.font(.system(size: 8, weight: .bold))
            Text(text).font(.f1(9, weight: .heavy)).tracking(1)
        }
        .foregroundStyle(Self.ink)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Capsule().strokeBorder(Self.ink.opacity(0.35), lineWidth: 1))
    }

    /// "3D LEFT", "9H LEFT" until the vote closes.
    private var timeLeft: String? {
        guard let race = model.race, let closes = DotdService.window(for: race)?.closes else { return nil }
        let left = Int(closes.timeIntervalSince(now))
        guard left > 0 else { return nil }
        return left >= 86400 ? "\(left / 86400)D LEFT" : "\(max(1, left / 3600))H LEFT"
    }

    /// The suit of the driver in the spotlight.
    private var suit: String? {
        guard let team = spotlight?.teamId, UIImage(named: "Suits/\(team)") != nil else { return nil }
        return "Suits/\(team)"
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: Self.yellow, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .topTrailing) {
                if let suit {
                    Image(suit)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 290)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: -3, y: 6)
                        .offset(x: shown ? -4 : 130, y: 10)
                        .rotationEffect(.degrees(shown ? 0 : 6), anchor: .bottom)
                        .accessibilityHidden(true)
                }
            }
            // one sweep of light across the card
            .overlay {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.35)
                        .rotationEffect(.degrees(18))
                        .offset(x: shown ? geo.size.width * 1.2 : -geo.size.width * 0.5)
                        .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
    }

    private struct Entry: Identifiable {
        let driverId: String
        let code: String
        let team: Color
        let pct: Double
        var id: String { driverId }
    }

    /// The three most-voted drivers; if fewer have votes, the podium
    /// finishers fill the gaps at 0%.
    private var entries: [Entry] {
        var list: [Entry] = (model.tally?.votes ?? []).prefix(3).map { v in
            let d = model.driver(v.driverId)
            return Entry(driverId: v.driverId, code: d?.code ?? String(v.driverId.prefix(3)).uppercased(),
                         team: Theme.teamColor(d?.teamId), pct: Double(v.pct) / 100)
        }
        for d in model.drivers where list.count < 3 && !list.contains(where: { $0.driverId == d.id }) {
            list.append(Entry(driverId: d.id, code: d.code, team: Theme.teamColor(d.teamId), pct: 0))
        }
        return list
    }

    /// The fan vote as a 3D podium: the leader in the middle, second left,
    /// third right; team-coloured columns rise and the shares count up.
    private var podium: some View {
        let top3 = entries
        let order = top3.count == 3 ? [top3[1], top3[0], top3[2]] : top3
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(order) { entry in
                let leader = entry.id == top3.first?.id
                let mine = entry.driverId == model.myVote
                let barHeight: CGFloat = shown ? 10 + entry.pct * 80 : 4
                VStack(spacing: 4) {
                    // the share rides on top of its column as it rises
                    VStack(spacing: 2) {
                        HStack(spacing: 1) {
                            CountingText(value: (shown ? entry.pct : 0) * 100, prefix: "")
                            Text("%")
                        }
                        .font(.f1Digits(leader ? 14 : 12))
                        .foregroundStyle(Self.ink)
                        PrismBar(height: barHeight, color: entry.team, width: leader ? 34 : 28)
                            .frame(width: 52, height: barHeight + 16)
                    }
                    .frame(height: 112, alignment: .bottom)
                    HStack(spacing: 3) {
                        if leader { Image(systemName: "crown.fill").font(.system(size: 8, weight: .black)) }
                        Text(entry.code).font(.f1(13))
                    }
                    .foregroundStyle(Self.ink)
                    .fixedSize()
                    Text(mine ? "YOU" : " ")
                        .font(.f1(8, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Self.yellow[0])
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(mine ? Self.ink : .clear))
                }
                .frame(width: 60)
            }
        }
        .frame(maxWidth: 210, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(top3.map { "\($0.code) \(Int(($0.pct * 100).rounded())) percent" }.joined(separator: ", "))
    }
}

/// A 3D column: a team-coloured front with a gloss stripe, a lit top and a
/// shaded side, standing on a soft shadow. `height` animates.
private struct PrismBar: View, Animatable {
    var height: CGFloat
    let color: Color
    let width: CGFloat

    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }

    var body: some View {
        Canvas { ctx, size in
            let dx = width * 0.34, dy = width * 0.22
            let base = size.height - 4
            let x0 = (size.width - width - dx) / 2
            let top = base - height

            // ground shadow
            ctx.fill(Path(ellipseIn: CGRect(x: x0 - 4, y: base - 4, width: width + dx + 8, height: 10)),
                     with: .color(.black.opacity(0.18)))

            var side = Path()
            side.move(to: CGPoint(x: x0 + width, y: top))
            side.addLine(to: CGPoint(x: x0 + width + dx, y: top - dy))
            side.addLine(to: CGPoint(x: x0 + width + dx, y: base - dy))
            side.addLine(to: CGPoint(x: x0 + width, y: base))
            side.closeSubpath()
            ctx.fill(side, with: .color(color))
            ctx.fill(side, with: .color(.black.opacity(0.35)))

            var cap = Path()
            cap.move(to: CGPoint(x: x0, y: top))
            cap.addLine(to: CGPoint(x: x0 + dx, y: top - dy))
            cap.addLine(to: CGPoint(x: x0 + width + dx, y: top - dy))
            cap.addLine(to: CGPoint(x: x0 + width, y: top))
            cap.closeSubpath()
            ctx.fill(cap, with: .color(color))
            ctx.fill(cap, with: .color(.white.opacity(0.4)))

            let front = Path(CGRect(x: x0, y: top, width: width, height: height))
            ctx.fill(front, with: .linearGradient(Gradient(colors: [color, color.opacity(0.8)]),
                                                  startPoint: CGPoint(x: x0, y: top), endPoint: CGPoint(x: x0, y: base)))
            // gloss stripe
            if height > 6 {
                ctx.fill(Path(CGRect(x: x0 + width * 0.16, y: top + 3, width: width * 0.12, height: height - 6)),
                         with: .color(.white.opacity(0.28)))
            }
        }
    }
}

// MARK: - Lights Out: photo strip

private struct LightsStrip: View {
    let onPlay: () -> Void
    @AppStorage("lightsOutBest") private var best: Double = 0
    @AppStorage("lightsOutHistory") private var history = ""
    @State private var board: LeaderboardService.ReactionBoard?

    var body: some View {
        Button(action: onPlay) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("REACTION TEST").font(.f1(10, weight: .bold)).tracking(2).foregroundStyle(Theme.live)
                    Text("LIGHTS OUT").font(.f1(22).italic()).foregroundStyle(Theme.chromeText)
                    HStack(spacing: 10) {
                        LEDText(text: best > 0 ? String(format: "%.3f", best) : "-.---", pitch: 2.8)
                        Text(subtitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                starts
                NeonChip(title: "PLAY ▸", tint: Theme.live, selected: true).frame(width: 84)
            }
            .padding(16)
            .frame(height: 118)
            .background(
                Color.clear
                    .overlay(alignment: .trailing) { Image("LightsOutHero").resizable().scaledToFill() }
                    .overlay(LinearGradient(stops: [.init(color: Theme.background.opacity(0.95), location: 0),
                                                    .init(color: Theme.background.opacity(0.55), location: 0.5),
                                                    .init(color: .clear, location: 0.85)],
                                            startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(best > 0 ? String(format: "Lights Out, your best %.3f seconds", best) : "Play Lights Out")
        .task {
            let user = await ChatService.currentUserId()
            board = await LeaderboardService.reaction(user: user, name: nil, ms: nil)
        }
    }

    private var subtitle: String {
        if let me = board?.me { return "P\(me.rank) this week" }
        return best > 0 ? "Your best" : "Beat 0.200"
    }

    /// The last ten starts: shorter is faster, the best one lit.
    @ViewBuilder
    private var starts: some View {
        let times = LightsOutView.times(history)
        if times.count > 1, let fastest = times.min() {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(times.enumerated()), id: \.offset) { _, t in
                    let lit = t == fastest
                    Capsule()
                        .fill(lit ? Theme.live : Color.white.opacity(0.35))
                        .frame(width: 4, height: CGFloat(min(max((t - 0.1) * 120, 6), 46)))
                        .shadow(color: lit ? Theme.live : .clear, radius: 3)
                }
            }
            .padding(.trailing, 6)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Ask Emily

private struct EmilyBar: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Color.clear
                    .overlay(Image("EmilyAvatar").resizable().scaledToFill())
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .shadow(color: Theme.accent.opacity(0.7), radius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ASK EMILY").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                    Text("AI race engineer").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
                }
                RadioWave()
                    .frame(height: 26)
                Image(systemName: "mic.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.accentGradient))
            }
            .padding(8)
            .padding(.leading, 2)
            .zoneGlass(Capsule(), light: Theme.violet, offset: CGSize(width: 0, height: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask Emily, the AI race engineer")
    }
}

/// A radio burst in the trio colours, flowing and breathing like live
/// audio (still under Reduce Motion).
struct RadioWave: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                // the voice swells and fades every couple of seconds
                let loudness = 0.55 + 0.45 * abs(sin(t * 1.3)) * (0.7 + 0.3 * sin(t * 3.1))
                var path = Path()
                for x in stride(from: 0, through: size.width, by: 1) {
                    let envelope = sin(Double(x / size.width) * .pi)
                    let wave = sin(Double(x) * 0.35 - t * 7) * 0.6 + sin(Double(x) * 0.11 + t * 3) * 0.4
                    let y = size.height / 2 + CGFloat(wave * envelope * loudness) * size.height * 0.45
                    x == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
                ctx.stroke(path, with: .linearGradient(Gradient(colors: [Theme.accent, Theme.violet, Theme.live]),
                                                       startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
                           lineWidth: 1.3)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Shared pieces

/// The violet outlined countdown chip of the race-weekend list.
private struct ZoneChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.f1(10, weight: .heavy).monospacedDigit())
            .tracking(1)
            .foregroundStyle(Theme.violet)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.violet.opacity(0.65), lineWidth: 1))
    }
}

private extension View {
    /// Liquid glass (iOS 26) or material, with a soft coloured light behind
    /// it for the glass to bend.
    func zoneGlass(_ shape: some Shape, light: Color, offset: CGSize) -> some View {
        modifier(ZoneGlass(shape: AnyShape(shape)))
            .background(
                Ellipse()
                    .fill(light)
                    .frame(width: 220, height: 140)
                    .blur(radius: 60)
                    .opacity(0.55)
                    .offset(offset)
                    .allowsHitTesting(false)
            )
    }
}

private struct ZoneGlass: ViewModifier {
    let shape: AnyShape
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - LED type

/// Text in round LEDs with dim sockets, glowing like the countdown board.
/// 5×7 glyphs; characters without a glyph are skipped.
struct LEDText: View {
    let text: String
    var pitch: CGFloat = 5.5
    var color: Color = Color(red: 1, green: 0.42, blue: 0.12)

    private var glyphs: [[String]] { text.uppercased().compactMap { LEDFont.glyphs[$0] } }
    private var columns: Int { glyphs.reduce(0) { $0 + $1[0].count } + max(0, glyphs.count - 1) }

    var body: some View {
        Canvas { ctx, _ in
            let dot = pitch * 0.72
            var x: CGFloat = 0
            for glyph in glyphs {
                for (r, row) in glyph.enumerated() {
                    for (c, ch) in row.enumerated() {
                        let rect = CGRect(x: x + CGFloat(c) * pitch, y: CGFloat(r) * pitch, width: dot, height: dot)
                        ctx.fill(Path(ellipseIn: rect), with: .color(ch == "#" ? color : .white.opacity(0.05)))
                    }
                }
                x += CGFloat(glyph[0].count + 1) * pitch
            }
        }
        .frame(width: CGFloat(columns) * pitch, height: 7 * pitch)
        .shadow(color: color.opacity(0.75), radius: pitch * 0.8)
        .accessibilityLabel(text)
    }
}

enum LEDFont {
    static let glyphs: [Character: [String]] = [
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        ".": [".", ".", ".", ".", ".", ".", "#"],
        "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
        "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
        "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    ]
}
