import SwiftUI

/// The Games tab, games only: the player's season standing, the picks card,
/// the arcade (Reaction Wall and Lights Out) and the leaderboards. Driver
/// of the day and Ask Emily live on the Countdown tab. Layout A, "pit wall":
/// Marketing/drafts/2026-10-13/games-tab-A-B-C.png
/// Everything the Games tab shows. The app starts loading it at launch, so
/// the first visit opens on a finished page instead of cards arriving (and
/// animating) one by one.
@Observable
@MainActor
final class GamesModel {
    let game = GameViewModel()
    var season: [Race] = []
    var nextRace: Race?
    var userId: String?
    var seasonBoard: LeaderboardService.Board?
    var wallBoard: LeaderboardService.WallBoard?
    var lightsBoard: LeaderboardService.ReactionBoard?
    /// The first load is done; the page shows from then on.
    var ready = false

    func load() async {
        async let next = try? F1API.nextRace()
        async let calendar = try? F1API.season()
        let (race, races) = await (next, calendar)
        nextRace = race ?? nil
        season = races ?? []
        guard GameFeature.isEnabled else { ready = true; return }
        await game.load(race: nextRace, season: season)
        #if DEBUG
        // -FakePicks YES: a signed-in player with three picks, for screenshots
        if UserDefaults.standard.bool(forKey: "FakePicks"), game.drivers.count > 2 {
            game.access = .ready
            game.draft.pole = game.drivers[1].id
            game.draft.p1 = game.drivers[0].id
            game.draft.p2 = game.drivers[2].id
        }
        #endif
        userId = await ChatService.currentUserId()
        let year = nextRace?.season ?? season.last?.season ?? String(Calendar.current.component(.year, from: .now))
        let user = userId
        async let board = try? LeaderboardService.board(scope: .season, year: year, user: user)
        // Warms the cache for the AI duel, which the picks card fetches itself.
        async let duel = user == nil ? nil : LeaderboardService.history(user: user!)
        seasonBoard = await board
        _ = await duel
        await loadArcadeBoards()
        #if DEBUG
        // -DemoGame YES: a made-up season table for store screenshots
        if UserDefaults.standard.string(forKey: "DemoGame") != nil {
            let names = ["Pole2Win", "GridWalker", "Kimi_Fan", "ApexHunter", "Ledger44", "LateBraker", "DRS_Train",
                         "Undercut", "SlowButton", "TurboTom", "BoxBoxBox", "You", "Slipstream", "Parc_Ferme"]
            let points = [128, 121, 117, 109, 104, 101, 97, 95, 92, 90, 88, 86, 84, 81]
            let top = zip(names, points).enumerated().map { i, e in
                LeaderboardService.Entry(userId: e.0 == "You" ? "me" : "p\(i)", name: e.0, points: e.1, exact: 3, rank: i + 1)
            }
            seasonBoard = LeaderboardService.Board(total: 340, top: top,
                                                   me: .init(userId: "me", name: "You", points: 86, exact: 4, rank: 12, comment: nil),
                                                   strategist: .init(name: "AI Strategist", points: 71, exact: 2))
        }
        #endif
        ready = true
    }

    func loadArcadeBoards() async {
        async let wall = LeaderboardService.wall(user: userId, name: nil, score: nil)
        async let lights = LeaderboardService.reaction(user: userId, name: nil, ms: nil)
        (wallBoard, lightsBoard) = await (wall, lights)
    }
}

struct GamesView: View {
    let model: GamesModel
    private var game: GameViewModel { model.game }

    @State private var showPicks = false
    @State private var showResult = false
    @State private var showLightsOut = false
    @State private var showWall = false
    @State private var showLeaderboard = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(colors: [Theme.accent.opacity(0.12), .clear], center: .top, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.violet.opacity(0.10), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 460)
                .ignoresSafeArea()

            if !model.ready {
                ProgressView().tint(Theme.accent)
            } else {
            ScrollViewReader { proxy in
                ScrollView {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        content(now: context.date)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .refreshable { await model.load() }
                #if DEBUG
                .task {
                    // -GamesScroll arcade: jump down to the arcade, for screenshots
                    guard let id = UserDefaults.standard.string(forKey: "GamesScroll") else { return }
                    try? await Task.sleep(for: .seconds(5))
                    proxy.scrollTo(id, anchor: .top)
                }
                #endif
            }
            .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.ready)
        .fullScreenCover(isPresented: $showWall, onDismiss: { Task { await model.loadArcadeBoards() } }) {
            ReactionWallView()
        }
        .fullScreenCover(isPresented: $showLightsOut, onDismiss: { Task { await model.loadArcadeBoards() } }) {
            LightsOutView()
        }
        .sheet(isPresented: $showPicks) {
            PicksSheet(game: game)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showResult) {
            if case let .scored(race, score, prediction) = game.cardState(at: .now) {
                ResultSheet(game: game, race: race, score: score, prediction: prediction)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.background)
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    TrioSlashes(height: 18)
                    Text("LEADERBOARD").font(.f1(22).italic()).foregroundStyle(Theme.chromeText)
                }
                .padding(.horizontal, 16)
                .padding(.top, 22)
                LeaderboardView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.background)
        }
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            title
            RankBoard(board: model.seasonBoard, onOpen: { showLeaderboard = true })
            PicksHero(game: game, state: game.cardState(at: now), now: now, seasonRounds: model.season.count,
                      onPicks: { showPicks = true }, onResult: { showResult = true })
            SectionTitle("ARCADE")
                .id("arcade")
            HStack(spacing: 12) {
                ArcadeTile(kind: .wall, rank: model.wallBoard?.me?.rank) { showWall = true }
                ArcadeTile(kind: .lightsOut, rank: model.lightsBoard?.me?.rank) { showLightsOut = true }
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                TrioSlashes(height: 26)
                Text("GAMES").font(.f1(34).italic()).foregroundStyle(Theme.chromeText)
            }
            Text(model.nextRace.map { "ROUND \($0.round) · \(PicksCard.shortName($0))" } ?? "PREDICT · PLAY · BEAT THE AI")
                .font(.f1(11, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Theme.dimText)
        }
    }

}

// MARK: - Pieces

/// The player's season standing as the leaderboard itself (approved draft
/// C, Marketing/drafts/2026-10-13/leaderboard-A-B-C.png): a slanted
/// position tag, points and the score against the AI Strategist, then the
/// players just above and below in timing-tower lines, and one link to the
/// full leaderboard (season, last round and leagues).
private struct RankBoard: View {
    let board: LeaderboardService.Board?
    let onOpen: () -> Void

    private var leader: Int { board?.top.first?.points ?? 0 }

    /// The player with their neighbours; the top three until they're ranked.
    private var lines: [LeaderboardService.Entry] {
        guard let board else { return [] }
        guard let me = board.me else { return Array(board.top.prefix(3)) }
        let window = me.rank == 1 ? 1...3 : (me.rank - 1)...(me.rank + 1)
        let around = board.top.filter { window.contains($0.rank) }
        return around.isEmpty ? Array(board.top.prefix(1)) : around
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) { summary }
                .buttonStyle(.plain)
            if !lines.isEmpty {
                Divider().overlay(Color.white.opacity(0.08))
                ForEach(lines) { entry in
                    Button(action: onOpen) { line(entry) }
                        .buttonStyle(.plain)
                }
            }
            // One way in: the leaderboard switches between the season, the
            // last round and the player's leagues itself.
            link("list.number", "FULL LEADERBOARD", action: onOpen)
                .padding(.vertical, 12)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke))
    }

    private var summary: some View {
        HStack(spacing: 0) {
            Text(board?.me.map { "P\($0.rank)" } ?? "P–")
                .font(.f1(30).italic())
                .foregroundStyle(Theme.onAccent)
                .padding(.leading, 16)
                .padding(.trailing, 24)
                .frame(height: 64)
                .background(SlantShape().fill(Theme.accentGradient))
            VStack(alignment: .leading, spacing: 2) {
                if let me = board?.me, let total = board?.total {
                    Text("OF \(total) \(total == 1 ? "PLAYER" : "PLAYERS") · SEASON")
                        .font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                    Text("\(me.points) PTS").font(.f1Digits(22)).foregroundStyle(.white)
                } else {
                    Text("NOT RANKED YET").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                    Text("Make your picks").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                }
            }
            .padding(.leading, 8)
            Spacer(minLength: 4)
            if let ai = board?.strategist {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("VS AI").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                    HStack(spacing: 4) {
                        Text("\(board?.me?.points ?? 0)").font(.f1Digits(20)).foregroundStyle(Theme.accent)
                        Text("–").foregroundStyle(Theme.dimText)
                        Text("\(ai.points)").font(.f1Digits(20)).foregroundStyle(Theme.violet)
                    }
                }
                .padding(.trailing, 16)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Timing-tower line: boxed position, a tick, name, gap to the leader.
    private func line(_ entry: LeaderboardService.Entry) -> some View {
        let isMe = entry.userId == board?.me?.userId
        return HStack(spacing: 10) {
            Text("\(entry.rank)")
                .font(.f1Digits(15))
                .foregroundStyle(entry.rank <= 3 ? Theme.onAccent : .white)
                .frame(width: 30, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(Self.positionFill(entry.rank)))
            Rectangle().fill(isMe ? Theme.accent : Color.white.opacity(0.25)).frame(width: 3, height: 20)
            Text(isMe ? "YOU" : entry.name.uppercased())
                .font(.f1(14).italic())
                .foregroundStyle(isMe ? Theme.accent : .white)
                .lineLimit(1)
            Spacer()
            Text(entry.rank == 1 ? "\(entry.points) PTS" : "+\(leader - entry.points)")
                .font(.f1Digits(14))
                .foregroundStyle(entry.rank == 1 ? .white : Theme.dimText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isMe ? Theme.accent.opacity(0.12) : .clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private static func positionFill(_ rank: Int) -> AnyShapeStyle {
        switch rank {
        case 1: AnyShapeStyle(Color(red: 1, green: 0.78, blue: 0.25))
        case 2, 3: AnyShapeStyle(Color.white.opacity(0.85))
        default: AnyShapeStyle(Color.white.opacity(0.08))
        }
    }

    private func link(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
                Text(title).font(.f1(11, weight: .heavy)).tracking(1)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

/// Arcade tile: carbon with lights for the Reaction Wall, the photo for
/// Lights Out; best score in LEDs and the weekly position.
private struct ArcadeTile: View {
    enum Kind { case lightsOut, wall }
    let kind: Kind
    let rank: Int?
    let onPlay: () -> Void
    @AppStorage("wallBest") private var wallBest = 0
    @AppStorage("lightsOutBest") private var lightsBest: Double = 0

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(kind == .wall ? "TRAINING" : "REACTION TEST")
                        .font(.f1(9, weight: .heavy)).tracking(1.5)
                        .foregroundStyle(kind == .wall ? Theme.accent : Theme.live)
                    Spacer()
                    if kind == .wall, wallBest == 0 {
                        Text("NEW").font(.f1(9, weight: .heavy)).foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent))
                    }
                }
                Spacer()
                Text(kind == .wall ? "REACTION\nWALL" : "LIGHTS\nOUT")
                    .font(.f1(21).italic())
                    .foregroundStyle(Theme.chromeText)
                    .lineSpacing(-4)
                HStack(spacing: 8) {
                    LEDText(text: best, pitch: 2.6,
                            color: kind == .wall ? Theme.accent : Color(red: 1, green: 0.42, blue: 0.12))
                    Text(caption)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 200)
            .background {
                ZStack {
                    switch kind {
                    case .lightsOut:
                        Color.clear.overlay(Image("LightsOutHero").resizable().scaledToFill())
                    case .wall:
                        CarbonFiber()
                        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(0..<2, id: \.self) { r in
                                GridRow {
                                    ForEach(0..<3, id: \.self) { c in
                                        WallPad(lit: r * 3 + c == 2 || r * 3 + c == 3, size: 30)
                                    }
                                }
                            }
                        }
                        .offset(y: -22)
                    }
                    LinearGradient(colors: [.clear, Theme.background.opacity(0.92)], startPoint: .center, endPoint: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                // The photo is wider than the tile: clipping hides the rest
                // but it still caught taps over the neighbouring tile.
                .allowsHitTesting(false)
            }
            .overlay(RoundedRectangle(cornerRadius: 20)
                .strokeBorder(kind == .wall ? AnyShapeStyle(Theme.accent.opacity(0.6)) : AnyShapeStyle(Theme.glassStroke)))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind == .wall ? "Play Reaction Wall" : "Play Lights Out")
    }

    private var best: String {
        switch kind {
        case .wall: wallBest > 0 ? "\(wallBest)" : "--"
        case .lightsOut: lightsBest > 0 ? String(format: "%.3f", lightsBest) : "-.---"
        }
    }

    private var caption: String {
        let unit = kind == .wall ? "pts" : "best"
        if let rank { return "\(unit) · P\(rank)" }
        return kind == .wall ? (wallBest > 0 ? "your best" : "60 seconds") : (lightsBest > 0 ? "your best" : "beat 0.200")
    }
}
