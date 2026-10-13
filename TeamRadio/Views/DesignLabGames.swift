#if DEBUG
import SwiftUI

// Debug-only drafts for the Games tab (hub layouts A/B/C) and the new
// Reaction Wall game (W1 grid, W2 arcs, W3 steering wheel). Launch with
// `-DesignLab gamesA` … `wall3` (add `-DemoGame YES` for scored picks).
// Nothing here ships.

// MARK: - Live data for the hub drafts

@Observable
@MainActor
final class DraftGameData {
    let race = RaceViewModel()
    let game = GameViewModel()
    let dotd = DotdModel()
    private var started = false

    func load() async {
        guard !started else { return }
        started = true
        await race.load()
        await game.load(race: race.nextRace, season: race.season)
        await dotd.load(season: race.season, fallbackDrivers: game.drivers)
    }
}

// MARK: - Shared draft pieces

/// The iOS 26 floating tab bar, drawn so each layout shows where Games sits.
private struct DraftTabBar: View {
    let items: [(title: String, symbol: String)]
    let selected: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                VStack(spacing: 3) {
                    Image(systemName: item.symbol).font(.system(size: 19, weight: .semibold))
                    Text(item.title).font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(i == selected ? Theme.accent : .white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(i == selected ? 0.12 : 0)))
            }
        }
        .padding(5)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }

    static let tabs = (
        countdown: (title: "Countdown", symbol: "flag.checkered"),
        results: (title: "Results", symbol: "trophy.fill"),
        standings: (title: "Standings", symbol: "list.number"),
        championship: (title: "Championship", symbol: "trophy.fill"),
        games: (title: "Games", symbol: "gamecontroller.fill"),
        paddock: (title: "Paddock", symbol: "bubble.left.and.bubble.right.fill"),
        news: (title: "News", symbol: "newspaper.fill")
    )
}

private struct DraftNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.violet)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.violet.opacity(0.6)))
    }
}

private struct GamesTitle: View {
    var sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                TrioSlashes(height: 26)
                Text("GAMES").font(.f1(34).italic()).foregroundStyle(Theme.chromeText)
            }
            Text(sub).font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.dimText)
        }
    }
}

/// Small static wall for tiles and cards.
private struct MiniWall: View {
    var columns = 3
    var rows = 3
    var lit: Set<Int> = [1, 5]
    var size: CGFloat = 26

    var body: some View {
        Grid(horizontalSpacing: size * 0.25, verticalSpacing: size * 0.25) {
            ForEach(0..<rows, id: \.self) { r in
                GridRow {
                    ForEach(0..<columns, id: \.self) { c in
                        WallPad(lit: lit.contains(r * columns + c), size: size)
                    }
                }
            }
        }
    }
}

/// Live rank strip in the broadcast style: a slanted position tag, then
/// the season numbers.
private struct PlayerStrip: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("P12")
                .font(.f1(26).italic())
                .foregroundStyle(Theme.onAccent)
                .padding(.leading, 16).padding(.trailing, 22)
                .frame(height: 58)
                .background(SlantShape().fill(Theme.accentGradient))
            VStack(alignment: .leading, spacing: 2) {
                Text("OF 340 PLAYERS").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                Text("86 PTS").font(.f1Digits(20)).foregroundStyle(.white)
            }
            .padding(.leading, 6)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("VS AI STRATEGIST").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                HStack(spacing: 6) {
                    Text("86").font(.f1Digits(20)).foregroundStyle(Theme.accent)
                    Text("–").foregroundStyle(Theme.dimText)
                    Text("71").font(.f1Digits(20)).foregroundStyle(Theme.violet)
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 58)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.glassStroke))
    }
}

private struct SlantShape: Shape {
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

/// Arcade tile: photo for Lights Out, carbon with a live mini wall for the
/// Reaction Wall.
private struct ArcadeTile: View {
    enum Kind { case lightsOut, wall }
    let kind: Kind
    var height: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(kind == .wall ? "TRAINING" : "REACTION TEST")
                    .font(.f1(9, weight: .heavy)).tracking(1.5)
                    .foregroundStyle(kind == .wall ? Theme.accent : Theme.live)
                Spacer()
                if kind == .wall {
                    Text("NEW").font(.f1(9, weight: .heavy)).foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accent))
                }
            }
            Spacer()
            Text(kind == .wall ? "REACTION\nWALL" : "LIGHTS\nOUT")
                .font(.f1(21).italic()).foregroundStyle(Theme.chromeText)
                .lineSpacing(-4)
            HStack(spacing: 8) {
                LEDText(text: kind == .wall ? "42" : "0.231", pitch: 2.6,
                        color: kind == .wall ? Theme.accent : Color(red: 1, green: 0.42, blue: 0.12))
                Text(kind == .wall ? "hits · P3" : "best · P7")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background {
            ZStack {
                switch kind {
                case .lightsOut:
                    Color.clear.overlay(Image("LightsOutHero").resizable().scaledToFill())
                    LinearGradient(colors: [.clear, Theme.background.opacity(0.95)], startPoint: .center, endPoint: .bottom)
                case .wall:
                    CarbonFiber()
                    MiniWall(columns: 3, rows: 2, lit: [2, 3], size: 30)
                        .offset(y: -22)
                    LinearGradient(colors: [.clear, Theme.background.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(kind == .wall ? AnyShapeStyle(Theme.accent.opacity(0.6)) : AnyShapeStyle(Theme.glassStroke)))
    }
}

private struct LeaderboardsRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach([("globe.europe.africa.fill", "GLOBAL", "P12 of 340"), ("person.2.fill", "LEAGUES", "2 leagues")], id: \.1) { icon, title, sub in
                HStack(spacing: 10) {
                    Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.f1(13).italic()).foregroundStyle(.white)
                        Text(sub).font(.system(size: 11)).foregroundStyle(Theme.dimText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.faintText)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            }
        }
    }
}

/// Hub skeleton: scrolling content with the drawn tab bar pinned below.
private struct HubFrame<Content: View>: View {
    let tabs: [(title: String, symbol: String)]
    let selected: Int
    let note: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DraftNote(text: note)
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) { DraftTabBar(items: tabs, selected: selected) }
    }
}

// MARK: - Hub A: pit wall (Games in the middle; News moves into Paddock)

struct GamesHubA: View {
    @State private var data = DraftGameData()

    var body: some View {
        let t = DraftTabBar.tabs
        HubFrame(tabs: [t.countdown, t.results, t.games, t.standings, t.paddock], selected: 2,
                 note: "A · Games in the middle · News moves into Paddock") {
            GamesTitle(sub: "ROUND 18 · UNITED STATES")
            PlayerStrip()
            PicksHero(game: data.game, state: data.game.cardState(at: .now), now: .now,
                      seasonRounds: data.race.season.count, onPicks: {}, onResult: {})
            SectionTitle("ARCADE")
            HStack(spacing: 12) {
                ArcadeTile(kind: .wall)
                ArcadeTile(kind: .lightsOut)
            }
            if data.dotd.race != nil { DotdBoldCard(model: data.dotd, now: .now, onVote: {}) }
            EmilyBar(onTap: {})
            SectionTitle("LEADERBOARDS")
            LeaderboardsRow()
        }
        .task { await data.load() }
    }
}

// MARK: - Hub B: arcade hero (Results + Standings become one tab)

struct GamesHubB: View {
    @State private var data = DraftGameData()

    var body: some View {
        let t = DraftTabBar.tabs
        HubFrame(tabs: [t.countdown, t.games, t.championship, t.paddock, t.news], selected: 1,
                 note: "B · Results + Standings become one tab") {
            GamesTitle(sub: "PREDICT · PLAY · BEAT THE AI")
            WallHeroCard()
            SectionTitle("THIS WEEKEND")
            PicksHero(game: data.game, state: data.game.cardState(at: .now), now: .now,
                      seasonRounds: data.race.season.count, onPicks: {}, onResult: {})
            if data.dotd.race != nil { DotdBoldCard(model: data.dotd, now: .now, onVote: {}) }
            LightsStrip(onPlay: {})
            EmilyBar(onTap: {})
        }
        .task { await data.load() }
    }
}

/// The new game as the one bold filled card, InviteBanner-style.
private struct WallHeroCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("NEW · TRAINING")
                    .font(.f1(10, weight: .heavy)).tracking(2)
                    .foregroundStyle(Theme.onAccent.opacity(0.75))
                Text("REACTION\nWALL").font(.f1(34)).foregroundStyle(Theme.onAccent).lineSpacing(-6)
                Text("Hit every light the moment it flashes. 60 seconds, like the drivers' reflex trainer.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.onAccent.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Text("PLAY ▸")
                    .font(.f1(14).italic()).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.onAccent))
            }
            Spacer(minLength: 0)
            MiniWall(columns: 2, rows: 3, lit: [1, 4], size: 44)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.onAccent.opacity(0.85)))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Theme.accent, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.35)))
        )
    }
}

// MARK: - Hub C: segmented (Predict | Arcade | Ranks), Arcade shown

struct GamesHubC: View {
    var body: some View {
        let t = DraftTabBar.tabs
        HubFrame(tabs: [t.countdown, t.games, t.results, t.standings, t.paddock], selected: 1,
                 note: "C · Segments inside Games · News moves into Paddock") {
            GamesTitle(sub: "ARCADE · WEEK 42")
            HStack(spacing: 8) {
                NeonChip(title: "PREDICT", tint: Theme.accent, selected: false)
                NeonChip(title: "ARCADE", tint: Theme.live, selected: true)
                NeonChip(title: "RANKS", tint: Theme.violet, selected: false)
            }
            ArcadeTile(kind: .wall, height: 230)
            ArcadeTile(kind: .lightsOut, height: 150)
            WeeklyBoards()
        }
    }
}

private struct WeeklyBoards: View {
    private let wall = [("1", "GridWalker", "61"), ("2", "Kimi_Fan", "58"), ("3", "You", "42")]
    private let lights = [("1", "Pole2Win", "0.168"), ("2", "Ledger44", "0.181"), ("7", "You", "0.231")]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THIS WEEK").font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Color(red: 1, green: 0.75, blue: 0.2))
            HStack(alignment: .top, spacing: 14) {
                column("MOST HITS", rows: wall, tint: Theme.accent)
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
                column("FASTEST START", rows: lights, tint: Theme.live)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }

    private func column(_ title: String, rows: [(String, String, String)], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(tint)
            ForEach(rows, id: \.1) { rank, name, value in
                HStack(spacing: 6) {
                    Text(rank).font(.f1(12)).foregroundStyle(Theme.dimText).frame(width: 14, alignment: .leading)
                    Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(name == "You" ? tint : .white).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(value).font(.f1Digits(12)).foregroundStyle(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reaction Wall game screens

private struct WallHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRAINING").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.accent)
                Text("REACTION WALL").font(.f1(28).italic()).foregroundStyle(Theme.chromeText)
            }
            Spacer()
            Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.dimText)
                .frame(width: 34, height: 34).background(Circle().fill(Color.white.opacity(0.06)))
        }
    }
}

/// W1: a 3×4 wall of lights on carbon; time, hits and best as neon tiles.
struct WallDraftGrid: View {
    var body: some View {
        VStack(spacing: 18) {
            DraftNote(text: "W1 · Light grid")
            WallHeader()
            HStack(spacing: 10) {
                NeonTile(value: 42, label: "SEC LEFT", hot: true)
                NeonTile(value: 37, label: "HITS")
                NeonTile(value: 61, label: "BEST", tint: Theme.violet)
            }
            MiniWall(columns: 3, rows: 4, lit: [4, 9], size: 88)
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(
                    CarbonFiber()
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.glassStroke))
                        .trioGlow(cornerRadius: 26)
                )
            Text("Hit each light the moment it flashes")
                .font(.system(size: 14)).foregroundStyle(Theme.dimText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// W2: lights on two arcs like the real reflex board, the score and the
/// clock in LEDs in the middle.
struct WallDraftArcs: View {
    private let outer = 7
    private let inner = 4
    private let litOuter: Set<Int> = [1]
    private let litInner: Set<Int> = [2]

    var body: some View {
        VStack(spacing: 18) {
            DraftNote(text: "W2 · Arcs like the real board")
            WallHeader()
            GeometryReader { geo in
                let w = geo.size.width
                let c = CGPoint(x: w / 2, y: w * 0.58)
                ZStack {
                    ForEach([0.43, 0.25], id: \.self) { r in
                        Circle()
                            .trim(from: 0.36, to: 1.14 - 0.36)
                            .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                            .rotationEffect(.degrees(90))
                            .frame(width: w * r * 2, height: w * r * 2)
                            .position(c)
                    }
                    ForEach(0..<outer, id: \.self) { i in
                        WallPad(lit: litOuter.contains(i), size: 62)
                            .position(point(i, of: outer, radius: w * 0.43, center: c, spread: 230))
                    }
                    ForEach(0..<inner, id: \.self) { i in
                        WallPad(lit: litInner.contains(i), tint: Theme.live, size: 54)
                            .position(point(i, of: inner, radius: w * 0.25, center: c, spread: 200))
                    }
                    VStack(spacing: 8) {
                        LEDText(text: "37", pitch: 6, color: Theme.accent)
                        Text("HITS").font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                    }
                    .position(x: c.x, y: c.y + 4)
                    VStack(spacing: 6) {
                        LEDText(text: "42", pitch: 4)
                        Text("SECONDS LEFT").font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                    }
                    .position(x: c.x, y: geo.size.height - 44)
                }
                .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Theme.glassStroke))
                .background(CarbonFiber().clipShape(RoundedRectangle(cornerRadius: 28)))
            }
            .aspectRatio(0.86, contentMode: .fit)
            Text("Cyan lights: hit them. Red ones: score double, but vanish faster.")
                .font(.system(size: 13)).foregroundStyle(Theme.dimText).multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func point(_ i: Int, of n: Int, radius: CGFloat, center: CGPoint, spread: Double) -> CGPoint {
        let start = -90 - spread / 2
        let angle = (start + spread * Double(i) / Double(n - 1)) * .pi / 180
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}

/// W3: the lights are the buttons of a steering wheel; the wheel's display
/// shows hits and time.
struct WallDraftWheel: View {
    var body: some View {
        VStack(spacing: 18) {
            DraftNote(text: "W3 · Steering wheel")
            WallHeader()
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    WheelShape()
                        .fill(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
                        .overlay(CarbonFiber().clipShape(WheelShape()).opacity(0.55))
                        .overlay(WheelShape().stroke(Theme.glassStroke, lineWidth: 1.5))
                        .shadow(color: Theme.accent.opacity(0.22), radius: 24)
                    // rubber grips
                    ForEach([0.075, 0.925], id: \.self) { x in
                        Capsule()
                            .fill(LinearGradient(colors: [Color(white: 0.11), Color(white: 0.02)], startPoint: .leading, endPoint: .trailing))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
                            .frame(width: w * 0.12, height: h * 0.56)
                            .rotationEffect(.degrees(x < 0.5 ? 7 : -7))
                            .position(x: w * x, y: h * 0.56)
                    }
                    // shift lights
                    HStack(spacing: 5) {
                        ForEach(0..<15, id: \.self) { i in
                            let color: Color = i < 5 ? .green : i < 10 ? Theme.live : Theme.accent
                            Circle().fill(i < 8 ? color : color.opacity(0.15))
                                .frame(width: 9, height: 9)
                                .shadow(color: i < 8 ? color : .clear, radius: 4)
                        }
                    }
                    .position(x: w / 2, y: h * 0.11)
                    // display
                    VStack(spacing: 6) {
                        HStack(spacing: 18) {
                            LEDText(text: "37", pitch: 4.6, color: Theme.accent)
                            LEDText(text: "42", pitch: 4.6)
                        }
                        HStack(spacing: 34) {
                            Text("HITS"); Text("SEC")
                        }
                        .font(.f1(8, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                    }
                    .frame(width: w * 0.42, height: h * 0.20)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.14)))
                    .position(x: w / 2, y: h * 0.29)
                    // buttons either side of the display
                    ForEach(Array([(0.22, 0.24, false), (0.22, 0.42, true), (0.78, 0.24, false), (0.78, 0.42, false)].enumerated()), id: \.offset) { _, b in
                        WallPad(lit: b.2, size: 50).position(x: w * b.0, y: h * b.1)
                    }
                    // rotaries and the centre button
                    WheelRotary().frame(width: 58, height: 58).position(x: w * 0.33, y: h * 0.60)
                    WheelRotary().frame(width: 58, height: 58).position(x: w * 0.67, y: h * 0.60)
                    WallPad(lit: true, tint: Theme.live, size: 46).position(x: w / 2, y: h * 0.53)
                    WallPad(lit: false, size: 40).position(x: w / 2, y: h * 0.70)
                }
            }
            .frame(height: 420)
            Text("Hit the buttons as they light up. Shift lights come later.")
                .font(.system(size: 13)).foregroundStyle(Theme.dimText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// A modern F1 wheel outline: arched top, grips flaring down either side,
/// a shallow notch at the bottom.
private struct WheelShape: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var p = Path()
        p.move(to: pt(0.16, 0.06))
        p.addQuadCurve(to: pt(0.84, 0.06), control: pt(0.5, -0.02))
        p.addQuadCurve(to: pt(0.99, 0.30), control: pt(0.97, 0.08))
        p.addQuadCurve(to: pt(0.92, 0.92), control: pt(1.02, 0.80))
        p.addQuadCurve(to: pt(0.80, 0.84), control: pt(0.84, 0.97))
        p.addQuadCurve(to: pt(0.50, 0.82), control: pt(0.66, 0.76))
        p.addQuadCurve(to: pt(0.20, 0.84), control: pt(0.34, 0.76))
        p.addQuadCurve(to: pt(0.08, 0.92), control: pt(0.16, 0.97))
        p.addQuadCurve(to: pt(0.01, 0.30), control: pt(-0.02, 0.80))
        p.addQuadCurve(to: pt(0.16, 0.06), control: pt(0.03, 0.08))
        p.closeSubpath()
        return p
    }
}

/// A rotary switch: knurled ring, pointer and position ticks.
private struct WheelRotary: View {
    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                Capsule().fill(i == 3 ? Theme.accent : Color.white.opacity(0.3))
                    .frame(width: 2, height: 5)
                    .offset(y: -27)
                    .rotationEffect(.degrees(-135 + Double(i) * 30))
            }
            Circle().fill(LinearGradient(colors: [Color(white: 0.30), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
                .padding(9)
            Circle().strokeBorder(Color.black.opacity(0.6), style: StrokeStyle(lineWidth: 3, dash: [1.5, 2])).padding(10)
            Capsule().fill(Theme.accent).frame(width: 3, height: 12).offset(y: -10).rotationEffect(.degrees(-45))
        }
    }
}
#endif
