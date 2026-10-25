#if DEBUG
import SwiftUI

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
