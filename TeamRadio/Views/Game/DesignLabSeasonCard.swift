#if DEBUG
import SwiftUI

/// `-DesignLab seasonCockpit`: three season cards built from the countdown
/// screen's own parts (carbon panel with the trio glow, neon tiles, LED
/// lettering, the neon ring), each keeping the you-vs-AI bar.
struct SeasonCockpitDrafts: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // -DesignPage 2: only C, which runs off the first screen
                ForEach(UserDefaults.standard.integer(forKey: "DesignPage") == 2 ? ["C · NEON RING"]
                        : ["A · NEON TILES", "B · LED BOARD", "C · NEON RING"], id: \.self) { title in
                    Text(title).font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.accent)
                    CockpitCard(style: String(title.prefix(1)), c: .alone)
                    CockpitCard(style: String(title.prefix(1)), c: .busy)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }
}

private struct CockpitCard: View {
    let style: String
    let c: FutureCase

    var body: some View {
        VStack(spacing: 14) {
            switch style {
            case "B": board
            case "C": ring
            default: tiles
            }
            tug
        }
        .padding(16)
        .background(
            CarbonFiber()
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.glassStroke, lineWidth: 1))
                .trioGlow(cornerRadius: 22)
        )
    }

    private var header: some View {
        HStack {
            Text("SEASON").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Color.white.opacity(0.7))
            Spacer()
            Text(c.total == 1 ? "ONLY PLAYER SO FAR" : c.rank == 1 ? "LEADING \(c.total)" : "\(c.behind) BEHIND P1 · OF \(c.total)")
                .font(.f1(10, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.dimText)
        }
    }

    // A: the countdown's neon tiles: position, points, and the duel gap.
    private var tiles: some View {
        VStack(spacing: 10) {
            header
            HStack(spacing: 10) {
                StatTile(text: "P\(c.rank)", label: "POSITION", tint: Theme.accent)
                StatTile(text: "\(c.points)", label: "POINTS", tint: Theme.accent)
                StatTile(text: c.points >= c.ai ? "+\(c.points - c.ai)" : "−\(c.ai - c.points)", label: "VS AI", tint: Theme.violet)
            }
        }
    }

    // B: the countdown's LED board, lettering your standing in amber.
    private var board: some View {
        VStack(spacing: 10) {
            header
            HStack(spacing: 16) {
                LEDText(text: "P\(c.rank)", pitch: 5, color: Color(red: 1, green: 0.42, blue: 0.12))
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 40)
                LEDText(text: "\(c.points)", pitch: 5, color: Theme.accent)
                Text("PTS").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Color.white.opacity(0.7))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
        }
    }

    // C: your position in the neon ring of the Lights Out start button.
    private var ring: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(white: 0.16), Color(white: 0.04)], center: .top, startRadius: 0, endRadius: 80))
                Circle().strokeBorder(Theme.accent, lineWidth: 4)
                    .shadow(color: Theme.accent.opacity(0.9), radius: 6)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 14)
                Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1).padding(9)
                Text("P\(c.rank)").font(.f1(26).italic()).foregroundStyle(Theme.chromeText).minimumScaleFactor(0.6).padding(10)
            }
            .frame(width: 86, height: 86)
            VStack(alignment: .leading, spacing: 4) {
                Text("SEASON").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Color.white.opacity(0.7))
                Text("\(c.points) PTS").font(.f1Digits(28)).foregroundStyle(Theme.chromeText)
                Text(c.total == 1 ? "ONLY PLAYER SO FAR" : c.rank == 1 ? "LEADING \(c.total) PLAYERS" : "OF \(c.total) · \(c.behind) BEHIND P1")
                    .font(.f1(10, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.dimText)
            }
            Spacer(minLength: 0)
        }
    }

    /// The you-vs-AI bar, as two neon tubes meeting.
    private var tug: some View {
        VStack(spacing: 6) {
            HStack {
                Text("YOU \(c.points)").font(.f1(12, weight: .heavy)).foregroundStyle(Theme.accent)
                Spacer()
                Text(c.points == c.ai ? "LEVEL WITH THE AI" : c.points > c.ai ? "YOU LEAD BY \(c.points - c.ai)" : "AI LEADS BY \(c.ai - c.points)")
                    .font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(c.ai) AI").font(.f1(12, weight: .heavy)).foregroundStyle(Theme.violet)
            }
            GeometryReader { geo in
                let share = CGFloat(c.points) / CGFloat(max(1, c.points + c.ai))
                HStack(spacing: 3) {
                    tube(Theme.accent).frame(width: min(max(10, (geo.size.width - 3) * share), geo.size.width - 12))
                    tube(Theme.violet)
                }
            }
            .frame(height: 10)
        }
    }

    private func tube(_ tint: Color) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [.white.opacity(0.9), tint, tint.opacity(0.8)], startPoint: .top, endPoint: .bottom))
            .shadow(color: tint.opacity(0.9), radius: 6)
    }
}

/// A neon-rimmed tile like the countdown's, holding text.
private struct StatTile: View {
    let text: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(text).font(.f1Digits(28)).foregroundStyle(Theme.chromeText)
                .shadow(color: .white.opacity(0.5), radius: 6).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.f1(10, weight: .bold)).tracking(1.5).foregroundStyle(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color(white: 0.03), Color(white: 0.09)], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
                RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.9), lineWidth: 3).blur(radius: 5)
                RoundedRectangle(cornerRadius: 16).strokeBorder(LinearGradient(colors: [Color.white.opacity(0.95), tint, tint.opacity(0.8)],
                                                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
            }
            .shadow(color: tint.opacity(0.5), radius: 10)
        )
    }
}

/// `-DesignLab seasonFuture`: three futuristic season cards in the approved
/// "telemetry glass" direction (Docs/redesign-telemetry-glass.md), each in
/// the two situations.
struct SeasonFutureDrafts: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(["A · TELEMETRY READOUT", "B · HUD GAUGE", "C · HOLOGRAM"], id: \.self) { title in
                    Text(title).font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.accent)
                    HStack(alignment: .top, spacing: 8) {
                        ForEach([FutureCase.alone, FutureCase.busy], id: \.rank) { c in
                            FutureCard(style: String(title.prefix(1)), c: c)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
    }
}

private struct FutureCase {
    let rank: Int, total: Int, points: Int, ai: Int, behind: Int
    static let alone = FutureCase(rank: 1, total: 1, points: 4, ai: 19, behind: 0)
    static let busy = FutureCase(rank: 12, total: 340, points: 86, ai: 71, behind: 42)
}

private struct FutureCard: View {
    let style: String
    let c: FutureCase

    private var lead: String { c.points == c.ai ? "LEVEL" : c.points > c.ai ? "+\(c.points - c.ai) YOU" : "+\(c.ai - c.points) AI" }
    private let mono = Font.system(size: 9, weight: .semibold, design: .monospaced)

    var body: some View {
        Group {
            switch style {
            case "B": gauge
            case "C": hologram
            default: readout
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func glass<S: View>(_ light: Color, @ViewBuilder _ content: () -> S) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .background(Ellipse().fill(light).frame(width: 160, height: 110).blur(radius: 45).opacity(0.6))
    }

    private func rule(_ n: String, _ meta: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(n) / SEASON").font(mono).tracking(1.2).foregroundStyle(Theme.accent)
                Spacer()
                Text(meta).font(mono).tracking(1.2).foregroundStyle(Theme.dimText)
            }
            HStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { i in
                    Rectangle().fill(Color.white.opacity(i % 6 == 0 ? 0.5 : 0.18)).frame(width: 1, height: i % 6 == 0 ? 6 : 3)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 6, alignment: .top)
        }
    }

    private func row(_ label: String, _ value: String, _ tint: Color = .white) -> some View {
        HStack {
            Text(label).font(mono).tracking(1.2).foregroundStyle(Theme.dimText)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(tint)
        }
    }

    /// Six cells each, lit by share of the combined points.
    private func cells(_ value: Int, _ total: Int, _ tint: Color) -> some View {
        let lit = total == 0 ? 0 : Int((Double(value) / Double(total) * 6).rounded())
        return HStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(i < lit ? tint : tint.opacity(0.15))
                    .frame(height: 8)
                    .shadow(color: i < lit ? tint.opacity(0.8) : .clear, radius: 4)
            }
        }
    }

    // A: a timing-screen readout: LED position, monospaced data rows and
    // two 6-cell energy bars for you and the AI.
    private var readout: some View {
        glass(Theme.accent) {
            VStack(alignment: .leading, spacing: 9) {
                rule("01", "\(c.total) PLR")
                HStack(alignment: .center, spacing: 10) {
                    LEDText(text: "P\(c.rank)", pitch: 4, color: Theme.accent)
                    Spacer(minLength: 0)
                }
                row("PTS", String(format: "%03d", c.points))
                row("GAP P1", c.behind == 0 ? "LEADER" : "-\(c.behind)")
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                HStack(spacing: 6) { Text("YOU").font(mono).foregroundStyle(Theme.accent).frame(width: 24, alignment: .leading); cells(c.points, c.points + c.ai, Theme.accent) }
                HStack(spacing: 6) { Text("AI").font(mono).foregroundStyle(Theme.violet).frame(width: 24, alignment: .leading); cells(c.ai, c.points + c.ai, Theme.violet) }
                row("Δ", lead, c.points >= c.ai ? Theme.accent : Theme.violet)
            }
        }
    }

    // B: a HUD gauge: the duel as a ring split cyan/violet with ticks,
    // your position in LEDs in the middle, corner brackets.
    private var gauge: some View {
        glass(Theme.violet) {
            VStack(spacing: 8) {
                rule("01", "\(c.total) PLR")
                ZStack {
                    let share = Double(c.points) / Double(max(1, c.points + c.ai))
                    Circle().trim(from: 0, to: 0.75).stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(135))
                    Circle().trim(from: 0, to: 0.75 * share).stroke(Theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(135)).shadow(color: Theme.accent, radius: 6)
                    Circle().trim(from: 0.75 * share + 0.01, to: 0.75).stroke(Theme.violet, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(135)).shadow(color: Theme.violet, radius: 6)
                    ForEach(0..<16, id: \.self) { i in
                        Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1, height: 4)
                            .offset(y: -50).rotationEffect(.degrees(-135 + Double(i) * 18))
                    }
                    VStack(spacing: 4) {
                        LEDText(text: "P\(c.rank)", pitch: 3, color: Theme.accent)
                        Text("\(c.points) PTS").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                    }
                }
                .frame(width: 112, height: 112)
                .frame(maxWidth: .infinity)
                HStack {
                    Text("YOU \(c.points)").font(mono).foregroundStyle(Theme.accent)
                    Spacer()
                    Text("AI \(c.ai)").font(mono).foregroundStyle(Theme.violet)
                }
            }
            .overlay { Brackets().stroke(Theme.accent.opacity(0.6), lineWidth: 1.2).padding(-4) }
        }
    }

    // C: a hologram: a perspective grid glowing under a big chrome position,
    // you and the AI as two energy columns rising from it.
    private var hologram: some View {
        glass(Theme.accent) {
            VStack(alignment: .leading, spacing: 8) {
                rule("01", "\(c.total) PLR")
                ZStack(alignment: .bottom) {
                    PerspectiveGrid().stroke(Theme.accent.opacity(0.35), lineWidth: 0.7).frame(height: 54)
                    HStack(alignment: .bottom, spacing: 10) {
                        Text("P\(c.rank)").font(.f1(36).italic()).foregroundStyle(Theme.chromeText)
                            .shadow(color: Theme.accent.opacity(0.9), radius: 12)
                        Spacer(minLength: 0)
                        column(c.points, Theme.accent, "YOU")
                        column(c.ai, Theme.violet, "AI")
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 96)
                row("PTS", "\(c.points)")
                row("Δ AI", lead, c.points >= c.ai ? Theme.accent : Theme.violet)
            }
        }
    }

    private func column(_ value: Int, _ tint: Color, _ label: String) -> some View {
        let height = 70 * CGFloat(value) / CGFloat(max(1, max(c.points, c.ai)))
        return VStack(spacing: 3) {
            Text("\(value)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(tint)
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [tint, tint.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                .frame(width: 16, height: max(6, height))
                .shadow(color: tint.opacity(0.8), radius: 6)
            Text(label).font(mono).foregroundStyle(tint)
        }
    }
}

/// HUD corner brackets.
private struct Brackets: Shape {
    func path(in r: CGRect) -> Path {
        let l: CGFloat = 14
        var p = Path()
        for (corner, dx, dy) in [(CGPoint(x: r.minX, y: r.minY), 1.0, 1.0), (CGPoint(x: r.maxX, y: r.minY), -1.0, 1.0),
                                 (CGPoint(x: r.minX, y: r.maxY), 1.0, -1.0), (CGPoint(x: r.maxX, y: r.maxY), -1.0, -1.0)] {
            p.move(to: CGPoint(x: corner.x + l * dx, y: corner.y))
            p.addLine(to: corner)
            p.addLine(to: CGPoint(x: corner.x, y: corner.y + l * dy))
        }
        return p
    }
}

/// A floor grid running towards a vanishing point.
private struct PerspectiveGrid: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let vanish = CGPoint(x: r.midX, y: r.minY - r.height * 1.4)
        for i in 0...10 {
            let x = r.minX + r.width * CGFloat(i) / 10
            let t = (r.maxY - r.minY) / (r.maxY - vanish.y)
            p.move(to: CGPoint(x: x, y: r.maxY))
            p.addLine(to: CGPoint(x: x + (vanish.x - x) * t, y: r.minY))
        }
        for j in 0...4 {
            let y = r.minY + r.height * pow(CGFloat(j) / 4, 1.6)
            p.move(to: CGPoint(x: r.minX, y: y)); p.addLine(to: CGPoint(x: r.maxX, y: y))
        }
        return p
    }
}

/// `-DesignLab seasonTags`: the current season card with three shapes for
/// the position tag (no slanted cut against the card's corner).
struct SeasonTagDrafts: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(["NOW", "1 · ROUNDED BADGE", "2 · F1 PARALLELOGRAM", "3 · MEDALLION"], id: \.self) { title in
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.accent)
                    TagCard(style: String(title.prefix(1)))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

private struct TagCard: View {
    let style: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tag
                VStack(alignment: .leading, spacing: 2) {
                    Text("OF 1 PLAYER · SEASON").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                    Text("4 PTS").font(.f1Digits(22)).foregroundStyle(.white)
                }
                .padding(.leading, style == "N" ? 8 : 12)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("VS AI").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                    HStack(spacing: 4) {
                        Text("4").font(.f1Digits(20)).foregroundStyle(Theme.accent)
                        Text("–").foregroundStyle(Theme.dimText)
                        Text("19").font(.f1Digits(20)).foregroundStyle(Theme.violet)
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(style == "N" ? 0 : 10)
            HStack(spacing: 6) {
                Image(systemName: "list.number").font(.system(size: 12, weight: .bold))
                Text("FULL LEADERBOARD").font(.f1(11, weight: .heavy)).tracking(1)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke))
    }

    private var label: some View {
        Text("P1").font(.f1(30).italic()).foregroundStyle(Theme.onAccent)
    }

    @ViewBuilder
    private var tag: some View {
        switch style {
        case "1":
            label
                .frame(width: 78, height: 58)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accentGradient))
                .shadow(color: Theme.accent.opacity(0.6), radius: 10)
        case "2":
            label
                .frame(width: 86, height: 54)
                .background(Parallelogram().fill(Theme.accentGradient))
                .shadow(color: Theme.accent.opacity(0.6), radius: 10)
        case "3":
            label
                .frame(width: 62, height: 62)
                .background(Circle().fill(Theme.accentGradient))
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5).padding(3))
                .shadow(color: Theme.accent.opacity(0.6), radius: 10)
        default:
            label
                .padding(.leading, 16).padding(.trailing, 24)
                .frame(height: 64)
                .background(NowSlant().fill(Theme.accentGradient))
        }
    }
}

/// Both sides slanted, rounded corners: the shape of F1 TV graphics.
private struct Parallelogram: Shape {
    func path(in r: CGRect) -> Path {
        let lean: CGFloat = 12, radius: CGFloat = 6
        var p = Path()
        let points = [CGPoint(x: r.minX + lean, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                      CGPoint(x: r.maxX - lean, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
        p.move(to: CGPoint(x: (points[3].x + points[0].x) / 2, y: (points[3].y + points[0].y) / 2))
        for i in 0..<4 {
            p.addArc(tangent1End: points[i], tangent2End: points[(i + 1) % 4], radius: radius)
        }
        p.closeSubpath()
        return p
    }
}

/// Today's tag: square on the left, slanted on the right.
private struct NowSlant: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: r.maxX, y: 0))
            p.addLine(to: CGPoint(x: r.maxX - 14, y: r.maxY))
            p.addLine(to: CGPoint(x: 0, y: r.maxY))
            p.closeSubpath()
        }
    }
}

// Season-standing card drafts for the Games tab, each shown in two
// situations: alone and behind the AI, and 12th of 340 ahead of it.
// `-DesignLab seasonA|seasonB|seasonC`.

private struct SeasonCase {
    let rank: Int?
    let total: Int
    let points: Int
    let ai: Int
    let leader: (name: String, points: Int)
    /// The players around you: (rank, name, points, you).
    let around: [(Int, String, Int, Bool)]

    static let alone = SeasonCase(rank: 1, total: 1, points: 4, ai: 19, leader: ("You", 4),
                                  around: [(1, "You", 4, true)])
    static let busy = SeasonCase(rank: 12, total: 340, points: 86, ai: 71, leader: ("Pole2Win", 128),
                                 around: [(11, "BoxBoxBox", 88, false), (12, "You", 86, true), (13, "Slipstream", 84, false)])
}

struct SeasonCardDrafts: View {
    let style: String

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title).font(.f1(13, weight: .heavy)).tracking(2).foregroundStyle(Theme.accent).padding(.top, 10)
            caseLabel("YOU NOW · ALONE, AI AHEAD")
            card(.alone)
            caseLabel("A BUSY SEASON · 12TH OF 340, AHEAD OF THE AI")
            card(.busy)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var title: String {
        switch style {
        case "B": "B · TWO TILES: STANDING AND DUEL"
        case "C": "C · STANDINGS WITH THE AI IN THEM"
        default: "A · ONE LINE + TUG OF WAR"
        }
    }

    private func caseLabel(_ text: String) -> some View {
        Text(text).font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.faintText)
    }

    @ViewBuilder
    private func card(_ c: SeasonCase) -> some View {
        switch style {
        case "B": TilesDraft(c: c)
        case "C": TowerDraft(c: c)
        default: TugDraft(c: c)
        }
    }
}

private func shell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) {
        content()
        HStack(spacing: 6) {
            Image(systemName: "list.number").font(.system(size: 12, weight: .bold))
            Text("FULL LEADERBOARD").font(.f1(11, weight: .heavy)).tracking(1)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Theme.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    .background(Theme.card)
    .clipShape(RoundedRectangle(cornerRadius: 18))
    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke))
}

/// A: your standing in one line (position, points, gap to the leader), then
/// you against the AI as a tug of war, with who leads by how much in words.
private struct TugDraft: View {
    let c: SeasonCase

    var body: some View {
        shell {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(c.rank.map { "P\($0)" } ?? "P–").font(.f1(34).italic()).foregroundStyle(Theme.accentGradient)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(c.points) PTS").font(.f1Digits(20)).foregroundStyle(.white)
                    Text(c.total == 1 ? "ONLY PLAYER SO FAR · SEASON" : "OF \(c.total) PLAYERS · \(c.leader.points - c.points) BEHIND P1")
                        .font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(Theme.dimText)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14)
            VStack(spacing: 6) {
                HStack {
                    Text("YOU \(c.points)").font(.f1(12, weight: .heavy)).foregroundStyle(Theme.accent)
                    Spacer()
                    Text(c.points >= c.ai ? "YOU LEAD BY \(c.points - c.ai)" : "AI LEADS BY \(c.ai - c.points)")
                        .font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("\(c.ai) AI").font(.f1(12, weight: .heavy)).foregroundStyle(Theme.violet)
                }
                GeometryReader { geo in
                    let share = CGFloat(c.points) / CGFloat(max(1, c.points + c.ai))
                    HStack(spacing: 2) {
                        Capsule().fill(Theme.accent).frame(width: max(8, geo.size.width * share))
                            .shadow(color: Theme.accent.opacity(0.7), radius: 5)
                        Capsule().fill(Theme.violet)
                            .shadow(color: Theme.violet.opacity(0.7), radius: 5)
                    }
                }
                .frame(height: 10)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
            .padding(.horizontal, 12).padding(.top, 12)
        }
    }
}

/// B: two tiles side by side: your season standing, and the duel with
/// both faces and the scoreline.
private struct TilesDraft: View {
    let c: SeasonCase

    var body: some View {
        shell {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SEASON").font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                    Text(c.rank.map { "P\($0)" } ?? "P–").font(.f1(32).italic()).foregroundStyle(Theme.accentGradient)
                    Text("\(c.points) pts · of \(c.total)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accent.opacity(0.35)))
                VStack(spacing: 6) {
                    Text("VS AI STRATEGIST").font(.f1(9, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.dimText)
                    HStack(spacing: 8) {
                        face("person.fill", Theme.accent)
                        Text("\(c.points)").font(.f1Digits(22)).foregroundStyle(Theme.accent)
                        Text("–").foregroundStyle(Theme.dimText)
                        Text("\(c.ai)").font(.f1Digits(22)).foregroundStyle(Theme.violet)
                        face("cpu", Theme.violet)
                    }
                    Text(c.points >= c.ai ? "You're ahead" : "AI ahead by \(c.ai - c.points)")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.violet.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.violet.opacity(0.35)))
            }
            .padding(.horizontal, 12).padding(.top, 12)
        }
    }

    private func face(_ icon: String, _ tint: Color) -> some View {
        Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
            .frame(width: 26, height: 26).background(Circle().fill(tint.opacity(0.15)))
            .overlay(Circle().strokeBorder(tint.opacity(0.6)))
    }
}

/// C: the timing tower of the season with the AI Strategist slotted in
/// where its points would place it, so "you vs AI" is just two lines.
private struct TowerDraft: View {
    let c: SeasonCase

    private var rows: [(String, String, Int, Kind)] {
        var list = c.around.map { (rank, name, points, you) in ("\(rank)", you ? "YOU" : name.uppercased(), points, you ? Kind.you : .player) }
        list.append(("AI", "AI STRATEGIST", c.ai, .ai))
        if c.total > 3 { list.insert(("1", c.leader.name.uppercased(), c.leader.points, .player), at: 0) }
        return list.sorted { $0.2 > $1.2 }
    }

    enum Kind { case you, player, ai }

    var body: some View {
        shell {
            HStack {
                Text("SEASON STANDINGS").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                Spacer()
                Text("\(c.total) \(c.total == 1 ? "PLAYER" : "PLAYERS")").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.faintText)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                line(row)
            }
        }
    }

    private func line(_ row: (String, String, Int, Kind)) -> some View {
        let (pos, name, points, kind) = row
        let tint: Color = kind == .you ? Theme.accent : kind == .ai ? Theme.violet : .white
        return HStack(spacing: 10) {
            Group {
                if kind == .ai { Image(systemName: "cpu").font(.system(size: 13, weight: .bold)) }
                else { Text(pos).font(.f1Digits(15)) }
            }
            .foregroundStyle(pos == "1" ? Theme.onAccent : tint)
            .frame(width: 34, height: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(pos == "1" ? AnyShapeStyle(Color(red: 1, green: 0.78, blue: 0.25))
                                                                 : AnyShapeStyle(tint.opacity(kind == .player ? 0.08 : 0.15))))
            Rectangle().fill(tint.opacity(kind == .player ? 0.25 : 1)).frame(width: 3, height: 20)
            Text(name).font(.f1(14).italic()).foregroundStyle(tint)
            Spacer()
            Text("\(points) PTS").font(.f1Digits(14)).foregroundStyle(kind == .player ? Theme.dimText : .white)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(kind == .you ? Theme.accent.opacity(0.12) : kind == .ai ? Theme.violet.opacity(0.1) : .clear)
    }
}
#endif
