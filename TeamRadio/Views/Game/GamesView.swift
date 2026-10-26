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
        async let user = ChatService.currentUserId()
        let (race, races) = await (next, calendar)
        nextRace = race ?? nil
        season = races ?? []
        guard GameFeature.isEnabled else { ready = true; return }
        // The picks, the season table, the AI duel and the arcade boards all
        // load at once; one after another they kept the page waiting.
        userId = await user
        let year = nextRace?.season ?? season.last?.season ?? String(Calendar.current.component(.year, from: .now))
        let uid = userId
        async let picks: Void = game.load(race: nextRace, season: season)
        async let board = try? LeaderboardService.board(scope: .season, year: year, user: uid)
        // Warms the cache for the AI duel, which the picks card fetches itself.
        async let duel = uid == nil ? nil : LeaderboardService.history(user: uid!)
        async let arcade: Void = loadArcadeBoards()
        await picks
        seasonBoard = await board
        _ = await duel
        await arcade
        #if DEBUG
        // -FakePicks YES: a signed-in player with three picks, for screenshots
        if UserDefaults.standard.bool(forKey: "FakePicks"), game.drivers.count > 2 {
            game.access = .ready
            game.draft.pole = game.drivers[1].id
            game.draft.p1 = game.drivers[0].id
            game.draft.p2 = game.drivers[2].id
        }
        #endif
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
        // Bests sync in the background; the tiles follow when they change.
        if let userId { Task { await LeaderboardService.syncBests(user: userId) } }
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
            VStack(spacing: 12) {
                ArcadeBanner(kind: .lightsOut, rank: model.lightsBoard?.me?.rank,
                             players: model.lightsBoard?.total) { showLightsOut = true }
                ArcadeBanner(kind: .wall, rank: model.wallBoard?.me?.rank,
                             players: model.wallBoard?.total) { showWall = true }
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

/// The player's season standing (approved: the medallion with draft A,
/// build/mockups/season-tags.png + season-card.png): your position in a
/// glowing medallion, points and the gap to the leader on one line, then
/// you against the AI Strategist as a tug of war that says who leads by how
/// much, and one link to the full leaderboard (season, last round, leagues).
private struct RankBoard: View {
    let board: LeaderboardService.Board?
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) {
                VStack(spacing: 12) {
                    standing
                    if let ai = board?.strategist { duel(ai: ai.points) }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // One way in: the leaderboard switches between the season, the
            // last round and the player's leagues itself.
            link("list.number", "FULL LEADERBOARD", action: onOpen)
                .padding(.vertical, 12)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke))
    }

    /// Your position in the neon ring of the Lights Out start button, your
    /// points beside it.
    private var standing: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(white: 0.16), Color(white: 0.04)], center: .top, startRadius: 0, endRadius: 80))
                Circle().strokeBorder(Theme.accent, lineWidth: 4)
                    .shadow(color: Theme.accent.opacity(0.9), radius: 6)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 14)
                Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1).padding(9)
                Text(board?.me.map { "P\($0.rank)" } ?? "P–")
                    .font(.f1(26).italic())
                    .foregroundStyle(Theme.chromeText)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(12)
            }
            .frame(width: 86, height: 86)
            .opacity(board?.me == nil ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("SEASON").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Color.white.opacity(0.7))
                if let me = board?.me, let total = board?.total {
                    Text("\(me.points) PTS").font(.f1Digits(28)).foregroundStyle(Theme.chromeText)
                    Text(gapLine(me: me, total: total))
                        .font(.f1(10, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.dimText)
                        .lineLimit(1).minimumScaleFactor(0.8)
                } else {
                    Text("NOT RANKED YET").font(.f1Digits(20)).foregroundStyle(Theme.chromeText)
                    Text("MAKE YOUR PICKS").font(.f1(10, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.dimText)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// A glowing neon tube: a bright core fading into its colour.
    private func neonTube(_ tint: Color) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [.white.opacity(0.9), tint, tint.opacity(0.8)], startPoint: .top, endPoint: .bottom))
            .shadow(color: tint.opacity(0.9), radius: 6)
            .shadow(color: tint.opacity(0.4), radius: 12)
    }

    /// "Only player so far", "Leading 340 players", "Of 340 players · 42 behind P1".
    private func gapLine(me: LeaderboardService.Me, total: Int) -> String {
        if total == 1 { return "ONLY PLAYER SO FAR · SEASON" }
        if me.rank == 1 { return "LEADING \(total) PLAYERS · SEASON" }
        let behind = (board?.top.first?.points ?? me.points) - me.points
        return "OF \(total) PLAYERS · \(behind) BEHIND P1"
    }

    /// You against the AI Strategist: a bar pushed by each side's points,
    /// with who leads, and by how much, in words.
    private func duel(ai: Int) -> some View {
        let you = board?.me?.points ?? 0
        return VStack(spacing: 6) {
            HStack {
                Text("YOU \(you)").font(.f1(12, weight: .heavy)).foregroundStyle(Theme.accent)
                Spacer()
                Text(you == ai ? "LEVEL WITH THE AI" : you > ai ? "YOU LEAD BY \(you - ai)" : "AI LEADS BY \(ai - you)")
                    .font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(ai) AI").font(.f1(12, weight: .heavy)).foregroundStyle(Theme.violet)
            }
            GeometryReader { geo in
                let share = you + ai == 0 ? 0.5 : CGFloat(you) / CGFloat(you + ai)
                HStack(spacing: 3) {
                    neonTube(Theme.accent)
                        .frame(width: min(max(10, (geo.size.width - 3) * share), geo.size.width - 12))
                    neonTube(Theme.violet)
                }
            }
            .frame(height: 10)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You \(you) points, AI Strategist \(ai) points")
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


/// One full-width banner per arcade game (approved draft A,
/// build/mockups/games-banners.png): the game's art across it, title, best
/// in LEDs and your place on the left, a glowing play button on the right.
private struct ArcadeBanner: View {
    enum Kind { case lightsOut, wall }
    let kind: Kind
    let rank: Int?
    let players: Int?
    let onPlay: () -> Void
    @AppStorage("wallBest") private var wallBest = 0
    @AppStorage("lightsOutBest") private var lightsBest: Double = 0

    private var tint: Color { kind == .wall ? Theme.accent : Theme.live }
    private var ledColor: Color { kind == .wall ? Theme.accent : Color(red: 1, green: 0.42, blue: 0.12) }
    private var title: String { kind == .wall ? "REACTION WALL" : "LIGHTS OUT" }
    private var kicker: String { kind == .wall ? "TRAINING · 60 SECONDS" : "REACTION TEST" }
    private var best: String {
        kind == .wall ? (wallBest > 0 ? "\(wallBest)" : "--") : (lightsBest > 0 ? String(format: "%.3f", lightsBest) : "-.---")
    }
    private var rankText: String { rank.map { "P\($0)" + (players.map { " OF \($0)" } ?? "") } ?? "NOT RANKED" }

    var body: some View {
        Button(action: onPlay) { cinematic }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(title.capitalized)")
    }

    private var cinematic: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(kicker).font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(tint)
                Text(title).font(.f1(26).italic()).foregroundStyle(Theme.chromeText).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    LEDText(text: best, pitch: 2.6, color: ledColor)
                    Text("best · \(rankText.lowercased())").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                }
            }
            Spacer()
            Image(systemName: "play.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .overlay(Circle().strokeBorder(tint, lineWidth: 2.5))
                .shadow(color: tint.opacity(0.8), radius: 10)
        }
        .padding(16)
        .frame(height: 118)
        .background { art.overlay(LinearGradient(colors: [Theme.background.opacity(0.95), Theme.background.opacity(0.6), .clear],
                                                 startPoint: .leading, endPoint: .trailing)) }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(tint.opacity(0.55), lineWidth: 1.2))
        .shadow(color: tint.opacity(0.25), radius: 14)
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder
    private var art: some View {
        switch kind {
        case .lightsOut:
            Color.clear.overlay(Image("LightsOutHero").resizable().scaledToFill()).allowsHitTesting(false)
        case .wall:
            ZStack {
                CarbonFiber()
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(0..<2, id: \.self) { r in
                        GridRow { ForEach(0..<2, id: \.self) { c in WallPad(lit: r != c, size: 22) } }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 82)
            }
            .allowsHitTesting(false)
        }
    }
}
