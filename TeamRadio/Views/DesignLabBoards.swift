#if DEBUG
import SwiftUI

// Debug-only drafts: three ways to give the Games leaderboards a proper
// place (`-DesignLab boardA|boardB|boardC`). Mock numbers. Nothing ships.

private struct Row: Identifiable {
    let rank: Int
    let name: String
    let points: Int
    var me = false
    var ai = false
    var id: Int { rank }
}

private let top: [Row] = [
    Row(rank: 1, name: "Pole2Win", points: 128), Row(rank: 2, name: "GridWalker", points: 121),
    Row(rank: 3, name: "Kimi_Fan", points: 117), Row(rank: 4, name: "Ledger44", points: 109),
    Row(rank: 5, name: "ApexHunter", points: 104),
]
private let me = Row(rank: 12, name: "Vasse", points: 86, me: true)
private let ai = Row(rank: 15, name: "AI Strategist", points: 71, ai: true)
private let gold = Color(red: 1, green: 0.78, blue: 0.25)

private struct BoardHeader: View {
    let note: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.violet)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.violet.opacity(0.6)))
            HStack(spacing: 10) {
                TrioSlashes(height: 26)
                Text("GAMES").font(.f1(34).italic()).foregroundStyle(Theme.chromeText)
            }
            Text("ROUND 18 · UNITED STATES").font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.dimText)
        }
    }
}

private struct Placeholder: View {
    let text: String
    var height: CGFloat
    var body: some View {
        Text(text).font(.f1(12, weight: .heavy)).tracking(2).foregroundStyle(Theme.faintText)
            .frame(maxWidth: .infinity).frame(height: height)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}

private struct ScopeChips: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach(["GLOBAL", "LEAGUES"], id: \.self) { t in
                Text(t).font(.f1(10, weight: .heavy)).tracking(1)
                    .lineLimit(1).fixedSize()
                    .foregroundStyle(t == "GLOBAL" ? Theme.onAccent : Theme.dimText)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(t == "GLOBAL" ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06))))
            }
        }
    }
}

/// One timing-tower line: boxed position, a colour tick, name, gap to the leader.
private struct TowerLine: View {
    let row: Row
    var leader = 128
    var body: some View {
        HStack(spacing: 10) {
            Text("\(row.rank)")
                .font(.f1Digits(15)).foregroundStyle(row.rank <= 3 ? Theme.onAccent : .white)
                .frame(width: 30, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(row.rank == 1 ? AnyShapeStyle(gold) : row.rank <= 3 ? AnyShapeStyle(Color.white.opacity(0.85)) : AnyShapeStyle(Color.white.opacity(0.08))))
            Rectangle().fill(row.me ? Theme.accent : row.ai ? Theme.violet : Color.white.opacity(0.25)).frame(width: 3, height: 20)
            if row.ai { Image(systemName: "cpu").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.violet) }
            Text(row.me ? "YOU" : row.name.uppercased())
                .font(.f1(14).italic()).foregroundStyle(row.me ? Theme.accent : row.ai ? Theme.violet : .white).lineLimit(1)
            Spacer()
            Text(row.rank == 1 ? "\(row.points) PTS" : "+\(leader - row.points)")
                .font(.f1Digits(14)).foregroundStyle(row.rank == 1 ? .white : Theme.dimText)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(row.me ? Theme.accent.opacity(0.12) : row.ai ? Theme.violet.opacity(0.10) : .clear)
    }
}

// MARK: - A: timing tower under the rank strip

struct BoardDraftA: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BoardHeader(note: "A · Timing tower near the top")
                VStack(spacing: 0) {
                    HStack {
                        Text("STANDINGS").font(.f1(12, weight: .heavy)).tracking(2).foregroundStyle(.white)
                            .padding(.leading, 14).padding(.trailing, 20).frame(height: 30)
                            .background(SlantShape().fill(Theme.live))
                        Text("340 PLAYERS").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                            .lineLimit(1).fixedSize()
                        Spacer()
                        ScopeChips().padding(.trailing, 10)
                    }
                    .padding(.vertical, 10)
                    ForEach(top) { TowerLine(row: $0) }
                    Text("· · ·").font(.f1(12)).foregroundStyle(Theme.faintText).padding(.vertical, 2)
                    TowerLine(row: me)
                    TowerLine(row: ai)
                    HStack {
                        Text("FULL TABLE").font(.f1(12, weight: .heavy)).tracking(2).foregroundStyle(Theme.accent)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                Placeholder(text: "PICKS CARD", height: 220)
                Placeholder(text: "ARCADE", height: 160)
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }
}

// MARK: - B: podium card after the picks

struct BoardDraftB: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BoardHeader(note: "B · Podium card after the picks")
                Placeholder(text: "RANK STRIP", height: 58)
                Placeholder(text: "PICKS CARD", height: 150)
                VStack(spacing: 14) {
                    HStack {
                        TrioSlashes(height: 16)
                        Text("TOP OF THE PADDOCK").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                        Spacer()
                        ScopeChips()
                    }
                    HStack(alignment: .bottom, spacing: 10) {
                        step(top[1], height: 78, color: Color(white: 0.82))
                        step(top[0], height: 110, color: gold)
                        step(top[2], height: 58, color: Color(red: 0.86, green: 0.52, blue: 0.3))
                    }
                    HStack(spacing: 10) {
                        Text("P12").font(.f1(18).italic()).foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentGradient))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("YOU · 86 PTS").font(.f1(14).italic()).foregroundStyle(.white)
                            Text("31 points to the podium").font(.system(size: 12)).foregroundStyle(Theme.dimText)
                        }
                        Spacer()
                        Text("FULL TABLE ›").font(.f1(11, weight: .heavy)).tracking(1).foregroundStyle(Theme.accent)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(0.10)))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(colors: [gold.opacity(0.16), Theme.card], startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(gold.opacity(0.45)))
                )
                Placeholder(text: "ARCADE", height: 160)
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }

    private func step(_ row: Row, height: CGFloat, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(row.name).font(.f1(13).italic()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(row.points) PTS").font(.f1Digits(11)).foregroundStyle(Theme.dimText)
            Text("\(row.rank)")
                .font(.f1Digits(30)).foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity).frame(height: height)
                .background(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [color, color.opacity(0.55)], startPoint: .top, endPoint: .bottom)))
                .shadow(color: color.opacity(0.5), radius: 10)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - C: the rank strip grows into a mini tower

struct BoardDraftC: View {
    private let around = [Row(rank: 11, name: "TurboTom", points: 88), me, Row(rank: 13, name: "Slipstream", points: 84)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BoardHeader(note: "C · Your rank strip becomes the board")
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("P12").font(.f1(30).italic()).foregroundStyle(Theme.onAccent)
                            .padding(.leading, 16).padding(.trailing, 24).frame(height: 64)
                            .background(SlantShape().fill(Theme.accentGradient))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OF 340 PLAYERS · SEASON").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                            Text("86 PTS").font(.f1Digits(22)).foregroundStyle(.white)
                        }
                        .padding(.leading, 8)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("VS AI").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                            HStack(spacing: 4) {
                                Text("86").font(.f1Digits(20)).foregroundStyle(Theme.accent)
                                Text("–").foregroundStyle(Theme.dimText)
                                Text("71").font(.f1Digits(20)).foregroundStyle(Theme.violet)
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    Divider().overlay(Color.white.opacity(0.08))
                    ForEach(around) { TowerLine(row: $0, leader: 128) }
                    HStack(spacing: 0) {
                        footer("globe.europe.africa.fill", "GLOBAL TOP 100")
                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 22)
                        footer("person.2.fill", "LEAGUES · 2")
                    }
                    .padding(.vertical, 12)
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke))
                Placeholder(text: "PICKS CARD", height: 220)
                Placeholder(text: "ARCADE", height: 160)
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }

    private func footer(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
            Text(title).font(.f1(11, weight: .heavy)).tracking(1)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Theme.accent)
        .frame(maxWidth: .infinity)
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
#endif
