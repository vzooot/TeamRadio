import SwiftUI

/// The 1.2 features grouped under one heading on the Countdown tab: picks,
/// driver of the day, Lights Out and Ask Emily. First step of the
/// "telemetry glass" style (Docs/redesign-telemetry-glass.md): glass panels
/// with coloured light behind them and LED numbers like the countdown board,
/// in the app's own colour code (trio slashes, grey chips, violet countdown
/// chip, cyan "next" stripe).
struct GameZone: View {
    @Bindable var game: GameViewModel
    let dotd: DotdModel
    let onPicks: () -> Void
    let onResult: () -> Void
    let onVote: () -> Void
    let onLightsOut: () -> Void
    let onEmily: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let state = game.cardState(at: now)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle("GAME ZONE")
                    Spacer()
                    if game.access == .ready, let text = headerChip(state, now: now) {
                        ZoneChip(text: text)
                    }
                }
                PicksPanel(game: game, state: state, now: now,
                           onOpen: { if case .scored = state { onResult() } else { onPicks() } })
                if dotd.race != nil {
                    DotdTile(model: dotd, now: now, onVote: onVote)
                }
                LightsOutTile(onPlay: onLightsOut)
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

// MARK: - Picks

private struct PicksPanel: View {
    @Bindable var game: GameViewModel
    let state: GameViewModel.CardState
    let now: Date
    let onOpen: () -> Void

    var body: some View {
        // Not .disabled: that would dim the whole panel; it just does nothing.
        Button {
            if game.access == .ready, state != .missed { onOpen() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.f1(22).italic())
                    .foregroundStyle(Theme.chromeText)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                switch game.access {
                case .checking:
                    ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 24)
                case .needsICloud:
                    note("Sign in to iCloud in Settings to play. Your iCloud account is your player identity.")
                case .needsName:
                    note("Pick a Paddock name in the Paddock tab first. It's how you appear on the leaderboard.")
                case .ready:
                    content
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .zoneGlass(RoundedRectangle(cornerRadius: 22), light: Theme.accent, offset: CGSize(width: -90, height: -20))
            .background(Color.clear.trioGlow(cornerRadius: 22, opacity: 0.35))
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        switch state {
        case .scored: "YOUR RESULT"
        case .open: "MAKE YOUR PICKS"
        default: "YOUR PICKS"
        }
    }

    private var prediction: Prediction {
        if case let .scored(_, _, prediction) = state { return prediction }
        return game.saved?.prediction ?? game.draft
    }

    private var score: ScoreBreakdown? {
        if case let .scored(_, score, _) = state { return score }
        return nil
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .missed:
            note("Picks for this round closed when the race started. The next round opens after the race.")
        case let .scored(_, score, _):
            scoreHeader(score)
            rows
            if let comment = game.lastBoard?.me?.comment {
                RadioComment(text: comment).padding(.horizontal, 16)
            }
            footer(cta: "BREAKDOWN →")
        case .locked:
            rows
            Label("All picks locked · scored after the race", systemImage: "lock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.dimText)
                .padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 4)
        case .open, .picked:
            rows
            footer(cta: state == .open ? "MAKE PICKS →" : prediction.isComplete ? "EDIT →" : "FINISH →")
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.dimText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16).padding(.bottom, 16)
    }

    private func scoreHeader(_ score: ScoreBreakdown) -> some View {
        HStack(alignment: .center, spacing: 14) {
            LEDText(text: "+\(score.total)", pitch: 6, color: Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                if let me = game.lastBoard?.me, let total = game.lastBoard?.total {
                    Text("\(me.rank.ordinal) of \(total.formatted()) · \(score.total) pts")
                } else {
                    Text("\(score.total) pts · \(score.exactPicks) exact")
                }
                if let ai = game.lastBoard?.strategist {
                    Text(score.total > ai.points ? "You beat the \(ai.name) ✓"
                         : score.total == ai.points ? "Level with the \(ai.name)"
                         : "\(ai.name) scored \(ai.points)")
                        .font(.system(size: 12))
                        .foregroundStyle(score.total > ai.points ? PicksStrip.color(.exact) : Theme.dimText)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Rows

    private struct Slot: Identifiable {
        let label: String
        let picks: [String?]
        let group: PickGroup
        let kinds: [ScoreBreakdown.Kind]
        var id: String { label }
    }

    private var slots: [Slot] {
        let p = prediction
        return (p.hasSprint ? [Slot(label: "SPR", picks: [p.sprintWinner], group: .sprint, kinds: [.sprint])] : []) + [
            Slot(label: "POLE", picks: [p.pole], group: .quali, kinds: [.pole]),
            Slot(label: "WIN", picks: [p.p1], group: .race, kinds: [.p1]),
            Slot(label: "P2·P3", picks: [p.p2, p.p3], group: .race, kinds: [.p2, .p3]),
            Slot(label: "FL", picks: [p.fastestLap], group: .race, kinds: [.fastestLap]),
        ]
    }

    /// The first open slot still missing a pick gets the cyan "next" stripe.
    private var nextSlot: String? {
        guard state == .open || state == .picked else { return nil }
        return slots.first { slot in
            slot.picks.contains(nil) && !game.isLocked(slot.group, at: now)
        }?.label
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(slots) { slot in
                row(slot, isNext: slot.label == nextSlot)
            }
        }
    }

    private func row(_ slot: Slot, isNext: Bool) -> some View {
        HStack(spacing: 12) {
            ZoneSessionChip(text: slot.label)
            if slot.picks.allSatisfy({ $0 == nil }) {
                Text(isNext ? "TAP TO PICK" : "—")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isNext ? Theme.accent : Theme.faintText)
            } else {
                HStack(spacing: 10) {
                    ForEach(Array(slot.picks.enumerated()), id: \.offset) { _, id in
                        pickCode(id)
                    }
                }
                if slot.picks.count == 1, let name = game.driver(slot.picks[0])?.familyName {
                    Text(name.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.dimText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            trailing(slot)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isNext ? Theme.accent.opacity(0.08) : .clear)
        .overlay(alignment: .leading) { if isNext { Rectangle().fill(Theme.accent).frame(width: 3) } }
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.06)) }
    }

    private func pickCode(_ id: String?) -> some View {
        let driver = game.driver(id)
        return HStack(spacing: 6) {
            Capsule().fill(Theme.teamColor(driver?.teamId)).frame(width: 3, height: 16)
            Text(driver?.code ?? "—").font(.f1(17)).foregroundStyle(.white)
        }
    }

    /// Points once scored, otherwise when this pick locks.
    @ViewBuilder
    private func trailing(_ slot: Slot) -> some View {
        if let score {
            let items = score.items.filter { slot.kinds.contains($0.kind) }
            HStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(PicksStrip.mark(item))
                        .font(.f1(11, weight: .bold))
                        .foregroundStyle(PicksStrip.color(item.outcome))
                }
            }
        } else if game.isLocked(slot.group, at: now) {
            Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.faintText)
        } else if let lock = game.lockDate(slot.group) {
            Text(lock.formatted(.dateTime.weekday(.abbreviated).hour().minute()).uppercased())
                .font(.f1(10, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Theme.faintText)
        }
    }

    // MARK: Footer

    private var pickCount: (made: Int, total: Int) {
        let p = prediction
        let all: [String?] = (p.hasSprint ? [p.sprintWinner] : []) + [p.pole, p.p1, p.p2, p.p3, p.fastestLap, p.wildcard]
        return (all.compactMap { $0 }.count, all.count)
    }

    private func footer(cta: String) -> some View {
        let count = pickCount
        return HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(0..<count.total, id: \.self) { i in
                    Capsule()
                        .fill(i < count.made ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.12)))
                        .frame(width: 14, height: 3)
                }
            }
            Text("\(count.made) OF \(count.total)")
                .font(.f1(10, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Theme.dimText)
            Spacer()
            Text(cta)
                .font(.f1(13).italic())
                .tracking(1.5)
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Capsule().fill(Theme.accentGradient))
                .shadow(color: Theme.accent.opacity(0.45), radius: 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 4)
    }
}

// MARK: - Driver of the day

private struct DotdTile: View {
    let model: DotdModel
    let now: Date
    let onVote: () -> Void

    var body: some View {
        Button(action: onVote) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TileHeading(text: "DRIVER OF THE DAY")
                    Spacer(minLength: 4)
                    if let left = timeLeft { ZoneChip(text: left) }
                }
                HStack(spacing: 16) {
                    if model.myVote != nil, let lead = model.tally?.votes.first {
                        let driver = model.driver(lead.driverId)
                        LEDText(text: driver?.code ?? String(lead.driverId.prefix(3)).uppercased(), pitch: 5.6,
                                color: Theme.teamColor(driver?.teamId))
                        detail("\(lead.pct)% of \(model.tally?.total ?? 0) votes", action: "CHANGE →")
                    } else {
                        LEDText(text: "???", pitch: 5.6, color: Theme.violet)
                        detail("Who impressed you most?", action: "VOTE →")
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zoneGlass(RoundedRectangle(cornerRadius: 20), light: Theme.violet, offset: CGSize(width: -20, height: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Driver of the day vote")
    }

    private func detail(_ text: String, action: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text(action)
                .font(.f1(12).italic())
                .tracking(1.5)
                .foregroundStyle(Theme.accent)
        }
    }

    /// "4D LEFT", "9H LEFT" until the vote closes.
    private var timeLeft: String? {
        guard let race = model.race, let closes = DotdService.window(for: race)?.closes else { return nil }
        let left = Int(closes.timeIntervalSince(now))
        guard left > 0 else { return nil }
        return left >= 86400 ? "\(left / 86400)D LEFT" : "\(max(1, left / 3600))H LEFT"
    }
}

// MARK: - Lights Out

private struct LightsOutTile: View {
    let onPlay: () -> Void
    @AppStorage("lightsOutBest") private var best: Double = 0
    @State private var board: LeaderboardService.ReactionBoard?

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TileHeading(text: "LIGHTS OUT")
                    Spacer(minLength: 4)
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle().fill(Theme.live).frame(width: 8, height: 8).shadow(color: Theme.live, radius: 3)
                        }
                    }
                }
                HStack(spacing: 16) {
                    LEDText(text: best > 0 ? String(format: "%.3f", best) : "-.---", pitch: 5)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("PLAY ▸")
                            .font(.f1(12).italic())
                            .tracking(1.5)
                            .foregroundStyle(Theme.live)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zoneGlass(RoundedRectangle(cornerRadius: 20), light: Theme.live, offset: CGSize(width: 20, height: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(best > 0 ? String(format: "Lights Out, your best %.3f seconds", best) : "Play Lights Out")
        .task {
            let user = await ChatService.currentUserId()
            board = await LeaderboardService.reaction(user: user, name: nil, ms: nil)
        }
    }

    private var subtitle: String {
        if let me = board?.me { return "Best · P\(me.rank) this week" }
        return best > 0 ? "Your best start" : "Can you beat 0.200?"
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

/// A radio burst in the trio colours.
struct RadioWave: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            for x in stride(from: 0, through: size.width, by: 1) {
                let envelope = sin(Double(x / size.width) * .pi)
                let wave = sin(Double(x) * 0.35) * 0.6 + sin(Double(x) * 0.11) * 0.4
                let y = size.height / 2 + CGFloat(wave * envelope) * size.height * 0.45
                x == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.stroke(path, with: .linearGradient(Gradient(colors: [Theme.accent, Theme.violet, Theme.live]),
                                                   startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
                       lineWidth: 1.3)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Shared pieces

/// Trio slashes and a small-caps label, heading a tile.
private struct TileHeading: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            TrioSlashes(height: 11)
            Text(text).font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

/// The grey session chip of the race-weekend list ("FP1").
private struct ZoneSessionChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.f1(12).italic())
            .foregroundStyle(Theme.dimText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: 50, height: 26)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
    }
}

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
