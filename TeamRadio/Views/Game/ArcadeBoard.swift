import SwiftUI

/// One line on an arcade leaderboard, either game.
struct ArcadeEntry: Identifiable, Equatable {
    let userId: String
    let name: String
    /// "0.150" for Lights Out, "71" for the Reaction Wall.
    let value: String
    let rank: Int
    var id: String { userId }
}

struct ArcadeStanding: Equatable {
    let total: Int
    let top: [ArcadeEntry]
    let me: ArcadeEntry?
}

/// The two arcade games' boards, in one shape.
enum ArcadeGame {
    case lightsOut, wall

    var weekTitle: String { self == .lightsOut ? "FASTEST THIS WEEK" : "MOST POINTS THIS WEEK" }
    var title: String { self == .lightsOut ? "LIGHTS OUT" : "REACTION WALL" }
    var emptyText: String { self == .lightsOut ? "No times yet this week. Set the first one." : "No runs yet this week. Set the first score." }

    /// `week`: nil for this week, "last", or "all" for all-time bests.
    func standing(user: String?, week: String? = nil, limit: Int? = nil) async -> ArcadeStanding? {
        switch self {
        case .lightsOut:
            guard let b = await LeaderboardService.reaction(user: user, name: nil, ms: nil, week: week, limit: limit) else { return nil }
            return Self.from(b)
        case .wall:
            guard let b = await LeaderboardService.wall(user: user, name: nil, score: nil, week: week, limit: limit) else { return nil }
            return Self.from(b)
        }
    }

    static func from(_ b: LeaderboardService.ReactionBoard) -> ArcadeStanding {
        let time = { (ms: Int) in String(format: "%.3f", Double(ms) / 1000) }
        return ArcadeStanding(total: b.total,
                              top: b.top.map { ArcadeEntry(userId: $0.userId, name: $0.name, value: time($0.ms), rank: $0.rank) },
                              me: b.me.map { ArcadeEntry(userId: "me", name: $0.name, value: time($0.ms), rank: $0.rank) })
    }

    static func from(_ b: LeaderboardService.WallBoard) -> ArcadeStanding {
        ArcadeStanding(total: b.total,
                       top: b.top.map { ArcadeEntry(userId: $0.userId, name: $0.name, value: "\($0.score)", rank: $0.rank) },
                       me: b.me.map { ArcadeEntry(userId: "me", name: $0.name, value: "\($0.score)", rank: $0.rank) })
    }
}

private let gold = Color(red: 1, green: 0.8, blue: 0.25)

/// Metallic gold, silver and bronze: a bright top, a deeper base and a
/// glow of the same colour.
struct Medal {
    let light: Color
    let deep: Color
    let glow: Color

    var gradient: LinearGradient { LinearGradient(colors: [light, deep], startPoint: .top, endPoint: .bottom) }

    static let gold = Color(red: 1, green: 0.75, blue: 0.15)
    static let goldLight = Color(red: 1, green: 0.88, blue: 0.5)
    static let goldGradient = LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.6), Color(red: 1, green: 0.68, blue: 0.1)],
                                             startPoint: .top, endPoint: .bottom)

    static func of(_ rank: Int) -> Medal? {
        switch rank {
        case 1: Medal(light: Color(red: 1, green: 0.93, blue: 0.45), deep: Color(red: 1, green: 0.62, blue: 0.08),
                      glow: Color(red: 1, green: 0.75, blue: 0.15))
        case 2: Medal(light: .white, deep: Color(red: 0.6, green: 0.68, blue: 0.8),
                      glow: Color(red: 0.75, green: 0.85, blue: 1))
        case 3: Medal(light: Color(red: 1, green: 0.72, blue: 0.45), deep: Color(red: 0.78, green: 0.36, blue: 0.14),
                      glow: Color(red: 1, green: 0.5, blue: 0.2))
        default: nil
        }
    }
}

/// A medal disc for the rank column: glowing for the top three.
private struct RankBadge: View {
    let rank: Int

    var body: some View {
        ZStack {
            if let medal = Medal.of(rank) {
                Circle().fill(medal.gradient)
                    .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1))
                    .shadow(color: medal.glow.opacity(0.7), radius: 6)
            }
            Text("\(rank)").font(.f1Digits(14)).foregroundStyle(Medal.of(rank) != nil ? Theme.onAccent : Theme.dimText)
        }
        .frame(width: 28, height: 28)
    }
}

/// This week's board under the game (approved draft B,
/// build/mockups/arcade-boards.png): a podium for the top three and your
/// place on one line. Always the same height, loading or empty, so the
/// screen never jumps when the scores arrive.
struct ArcadeBoardCard: View {
    let game: ArcadeGame
    /// nil while loading.
    let standing: ArcadeStanding?
    let loaded: Bool
    /// A better time this week: your line lights up gold.
    var celebrate = false
    /// Places just gained this week.
    var climb: Int? = nil
    let hasName: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 0) {
                HStack {
                    Text(game.weekTitle).font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(gold)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("FULL BOARD").font(.f1(10, weight: .heavy)).tracking(1)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if loaded, let standing, standing.top.isEmpty {
                    Text(game.emptyText)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.dimText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 14)
                } else if loaded && standing == nil {
                    Text("The board isn't reachable right now.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.dimText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 10) {
                        podium
                        you
                    }
                    .redacted(reason: standing == nil ? .placeholder : [])
                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 12)
            .frame(height: 172)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.glassStroke))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.25), value: standing)
    }

    /// P2, P1, P3 under a gold spotlight; an empty step stays in place
    /// until someone takes it.
    private var podium: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach([2, 1, 3], id: \.self) { rank in
                step(rank, standing.map { s in s.top.first { $0.rank == rank } } ?? placeholder(rank))
            }
        }
        .padding(.horizontal, 14)
        .background(alignment: .bottom) {
            // tall enough for the light to fade out before its edge
            RadialGradient(colors: [gold.opacity(0.3), .clear], center: .bottom, startRadius: 0, endRadius: 130)
                .frame(width: 320, height: 150)
                .allowsHitTesting(false)
        }
    }

    private func placeholder(_ rank: Int) -> ArcadeEntry {
        ArcadeEntry(userId: "\(rank)", name: "Player", value: game == .lightsOut ? "0.000" : "00", rank: rank)
    }

    private func step(_ rank: Int, _ entry: ArcadeEntry?) -> some View {
        VStack(spacing: 3) {
            Text(entry?.name ?? "–")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(entry?.value ?? " ")
                .font(.f1Digits(13))
                .foregroundStyle(Theme.dimText)
            let medal = Medal.of(rank)!
            let shape = UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7)
            Text("\(rank)")
                .font(.f1(19).italic())
                .foregroundStyle(Theme.onAccent)
                .shadow(color: .white.opacity(0.6), radius: 0, y: 1)
                .frame(maxWidth: .infinity)
                .frame(height: rank == 1 ? 44 : rank == 2 ? 34 : 26)
                .background(shape.fill(medal.gradient))
                // a lit top edge and a halo, strongest on the winner's step
                .overlay(alignment: .top) { shape.fill(.white.opacity(0.7)).frame(height: 2).padding(.horizontal, 3) }
                .shadow(color: medal.glow.opacity(0.9), radius: 3)
                .shadow(color: medal.glow.opacity(rank == 1 ? 0.9 : 0.65), radius: rank == 1 ? 20 : 12)
                .opacity(entry == nil ? 0.3 : 1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// Your place this week, or how to get one.
    private var you: some View {
        HStack(spacing: 8) {
            Text("YOU").font(.f1(12).italic()).foregroundStyle(Theme.accent)
            if let me = standing?.me, let total = standing?.total {
                Text("P\(me.rank) OF \(total)").font(.f1(11, weight: .heavy)).tracking(1).foregroundStyle(.white)
                if let climb, climb > 0 {
                    Text("▲ \(climb)")
                        .font(.f1(10, weight: .heavy))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Medal.goldGradient))
                }
                Spacer()
                Text(me.value).font(.f1Digits(15)).foregroundStyle(.white)
            } else {
                Text(hasName ? "NOT ON THE BOARD YET" : "PICK A PADDOCK NAME TO JOIN")
                    .font(.f1(11, weight: .heavy)).tracking(1).foregroundStyle(Theme.dimText)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Capsule().fill(celebrate ? Medal.gold.opacity(0.18) : Theme.accent.opacity(0.14)))
        .overlay(Capsule().strokeBorder(celebrate ? AnyShapeStyle(Medal.goldGradient) : AnyShapeStyle(Theme.accent.opacity(0.5)),
                                        lineWidth: celebrate ? 1.5 : 1))
        .shadow(color: celebrate ? Medal.gold.opacity(0.6) : .clear, radius: 10)
        .animation(.easeOut(duration: 0.3), value: celebrate)
        .padding(.horizontal, 14)
    }
}

/// Every player: this week, all-time or last week, with your line pinned
/// to the bottom while it's off screen.
struct ArcadeFullBoard: View {
    let game: ArcadeGame
    let userId: String?

    enum Tab: String, CaseIterable {
        case week = "THIS WEEK", all = "ALL-TIME", last = "LAST WEEK"
        var query: String? { switch self { case .week: nil; case .all: "all"; case .last: "last" } }
    }

    @State private var tab: Tab = .week
    @State private var standing: ArcadeStanding?
    @State private var loading = true
    @State private var meVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TrioSlashes(height: 18)
                Text(game.title).font(.f1(22).italic()).foregroundStyle(Theme.chromeText)
            }
            .padding(.top, 22)
            HStack(spacing: 8) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Button { tab = t } label: { NeonChip(title: t.rawValue, tint: Theme.accent, selected: tab == t) }
                        .buttonStyle(.plain)
                }
            }
            if let standing {
                Text("\(standing.total) \(standing.total == 1 ? "PLAYER" : "PLAYERS")")
                    .font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.faintText)
            }
            list
        }
        .padding(.horizontal, 16)
        .task(id: tab) { await load() }
    }

    @ViewBuilder
    private var list: some View {
        if loading && standing == nil {
            ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.top, 40)
            Spacer()
        } else if let standing, !standing.top.isEmpty {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(standing.top) { entry in
                        let mine = entry.rank == standing.me?.rank
                        line(entry, mine: mine)
                            .modifier(FullyVisible(enabled: mine) { meVisible = $0 })
                        Divider().overlay(Color.white.opacity(0.05))
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let me = standing.me, !meVisible {
                    line(me, mine: true)
                        .background(Theme.background)
                        .overlay(alignment: .top) { Rectangle().fill(Theme.accent.opacity(0.5)).frame(height: 1) }
                        .shadow(color: .black.opacity(0.6), radius: 12, y: -6)
                }
            }
        } else {
            Text(standing == nil ? "The board isn't reachable right now." : tab == .all ? "No scores yet." : game.emptyText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.dimText)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            Spacer()
        }
    }

    private func line(_ entry: ArcadeEntry, mine: Bool) -> some View {
        HStack(spacing: 12) {
            RankBadge(rank: entry.rank)
                .frame(width: 30)
            Avatar(name: entry.name, size: 28)
            Text(mine ? "You" : entry.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(mine ? Theme.accent : .white)
                .lineLimit(1)
            Spacer()
            Text(entry.value).font(.f1Digits(15)).foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .frame(height: 46)
        .background(mine ? Theme.accent.opacity(0.14) : .clear)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        loading = true
        meVisible = false
        standing = await game.standing(user: userId, week: tab.query, limit: 500)
        loading = false
    }
}

/// Reports whether a row is (nearly) fully on screen; before iOS 18, when
/// it's laid out at all.
private struct FullyVisible: ViewModifier {
    let enabled: Bool
    let changed: (Bool) -> Void

    func body(content: Content) -> some View {
        if !enabled {
            content
        } else if #available(iOS 18, *) {
            content.onScrollVisibilityChange(threshold: 0.95, changed)
        } else {
            content.onAppear { changed(true) }.onDisappear { changed(false) }
        }
    }
}
