#if DEBUG
import SwiftUI

// Weekly arcade board drafts, shown in place of the current box with
// `-BoardDraft A|B|C` (`-BoardDraft full` shows the full board). Every
// draft keeps one fixed height whether it's loading, empty or full, so the
// screen never jumps.

struct BoardDraftRow: Identifiable {
    let rank: Int
    let name: String
    let ms: Int
    var me = false
    var id: Int { rank }
}

enum BoardDraftData {
    static let names = ["Vasse", "GridWalker", "Kimi_Fan", "ApexHunter", "Ledger44", "LateBraker", "DRS_Train", "Undercut",
                        "SlowButton", "TurboTom", "BoxBoxBox", "Slipstream", "Parc_Ferme", "Pole2Win", "Tifosi_Gio", "Sainz_Ops",
                        "You", "Lap1Hero", "Marbles", "Hairpin", "BlueFlag", "Kerbside", "DirtyAir", "Graining"]
    static let rows: [BoardDraftRow] = names.enumerated().map { i, name in
        BoardDraftRow(rank: i + 1, name: name, ms: 150 + i * 6 + (i > 10 ? i : 0), me: name == "You")
    }
    static let total = 48
    static var me: BoardDraftRow { rows[16] }
    static func time(_ ms: Int) -> String { String(format: "%.3f", Double(ms) / 1000) }
}

private let gold = Color(red: 1, green: 0.78, blue: 0.25)
private let silver = Color(white: 0.85)
private let bronze = Color(red: 0.86, green: 0.55, blue: 0.32)

private func medal(_ rank: Int) -> Color? {
    switch rank { case 1: gold; case 2: silver; case 3: bronze; default: nil }
}

/// The card every draft sits in: title, player count, body, full-board link.
private struct DraftCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FASTEST THIS WEEK").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(gold)
                Spacer()
                Text("\(BoardDraftData.total) PLAYERS").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.faintText)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            content
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "list.number").font(.system(size: 11, weight: .bold))
                Text("FULL BOARD").font(.f1(11, weight: .heavy)).tracking(1)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .frame(height: 214)
        .frame(maxWidth: 360)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.glassStroke))
    }
}

/// A: the top three with medals, a gap, then you.
struct BoardDraftTopThree: View {
    var body: some View {
        DraftCard {
            VStack(spacing: 2) {
                ForEach(BoardDraftData.rows.prefix(3)) { row($0) }
                Text("• • •").font(.system(size: 9)).foregroundStyle(Theme.faintText).padding(.vertical, 1)
                row(BoardDraftData.me)
            }
        }
    }

    private func row(_ r: BoardDraftRow) -> some View {
        HStack(spacing: 10) {
            ZStack {
                if let color = medal(r.rank) { Circle().fill(color) }
                Text("\(r.rank)").font(.f1Digits(13)).foregroundStyle(medal(r.rank) != nil ? Theme.onAccent : .white)
            }
            .frame(width: 24, height: 24)
            Text(r.me ? "You" : r.name).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(r.me ? Theme.accent : .white).lineLimit(1)
            Spacer()
            Text(BoardDraftData.time(r.ms)).font(.f1Digits(15)).foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(r.me ? Theme.accent.opacity(0.14) : .clear)
    }
}

/// B: a small podium, then your position on one line.
struct BoardDraftPodium: View {
    var body: some View {
        DraftCard {
            VStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach([1, 0, 2], id: \.self) { i in step(BoardDraftData.rows[i]) }
                }
                .padding(.horizontal, 14)
                HStack {
                    Text("YOU").font(.f1(12).italic()).foregroundStyle(Theme.accent)
                    Text("P\(BoardDraftData.me.rank) OF \(BoardDraftData.total)").font(.f1(11, weight: .heavy)).tracking(1).foregroundStyle(.white)
                    Spacer()
                    Text(BoardDraftData.time(BoardDraftData.me.ms)).font(.f1Digits(15)).foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(Theme.accent.opacity(0.14)))
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.5)))
                .padding(.horizontal, 14)
            }
        }
    }

    private func step(_ r: BoardDraftRow) -> some View {
        VStack(spacing: 3) {
            Text(r.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(BoardDraftData.time(r.ms)).font(.f1Digits(13)).foregroundStyle(Theme.dimText)
            Text("\(r.rank)")
                .font(.f1(18).italic())
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: r.rank == 1 ? 44 : r.rank == 2 ? 34 : 26)
                .background(UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6).fill(medal(r.rank)!))
        }
        .frame(maxWidth: .infinity)
    }
}

/// C: F1 timing tower: the leader, then you with the drivers either side,
/// each with the gap to the leader.
struct BoardDraftTower: View {
    var body: some View {
        DraftCard {
            VStack(spacing: 2) {
                row(BoardDraftData.rows[0])
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.horizontal, 14).padding(.vertical, 3)
                ForEach(BoardDraftData.rows[15...17]) { row($0) }
            }
        }
    }

    private func row(_ r: BoardDraftRow) -> some View {
        let leader = BoardDraftData.rows[0].ms
        return HStack(spacing: 10) {
            Text("\(r.rank)")
                .font(.f1Digits(14))
                .foregroundStyle(r.rank <= 3 ? Theme.onAccent : .white)
                .frame(width: 30, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(medal(r.rank) ?? Color.white.opacity(0.08)))
            Rectangle().fill(r.me ? Theme.accent : Color.white.opacity(0.25)).frame(width: 3, height: 18)
            Text(r.me ? "YOU" : r.name.uppercased()).font(.f1(13).italic())
                .foregroundStyle(r.me ? Theme.accent : .white).lineLimit(1)
            Spacer()
            Text(r.rank == 1 ? BoardDraftData.time(r.ms) : "+" + BoardDraftData.time(r.ms - leader))
                .font(.f1Digits(14))
                .foregroundStyle(r.rank == 1 ? .white : Theme.dimText)
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(r.me ? Theme.accent.opacity(0.14) : .clear)
    }
}

/// The full board (tap "FULL BOARD"): this week, all-time or last week,
/// every player in one list, with your line pinned to the bottom while it's
/// off screen.
struct BoardDraftFull: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(Color.white.opacity(0.25)).frame(width: 36, height: 5).frame(maxWidth: .infinity).padding(.top, 8)
            HStack(spacing: 8) {
                TrioSlashes(height: 18)
                Text("LIGHTS OUT").font(.f1(22).italic()).foregroundStyle(Theme.chromeText)
            }
            HStack(spacing: 8) {
                NeonChip(title: "THIS WEEK", tint: Theme.accent, selected: true)
                NeonChip(title: "ALL-TIME", tint: Theme.accent, selected: false)
                NeonChip(title: "LAST WEEK", tint: Theme.accent, selected: false)
            }
            Text("48 PLAYERS · WEEK OF 19 OCT").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.faintText)
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ForEach(BoardDraftData.rows.prefix(14)) { r in
                        line(r)
                        Divider().overlay(Color.white.opacity(0.05))
                    }
                    Spacer(minLength: 0)
                }
                line(BoardDraftData.me)
                    .background(Theme.background)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.accent.opacity(0.5)).frame(height: 1) }
                    .shadow(color: .black.opacity(0.6), radius: 12, y: -6)
            }
        }
        .padding(.horizontal, 16)
    }

    private func line(_ r: BoardDraftRow) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if let color = medal(r.rank) { Circle().fill(color) }
                Text("\(r.rank)").font(.f1Digits(14)).foregroundStyle(medal(r.rank) != nil ? Theme.onAccent : Theme.dimText)
            }
            .frame(width: 28, height: 28)
            Avatar(name: r.name, size: 28)
            Text(r.me ? "You" : r.name).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(r.me ? Theme.accent : .white)
            Spacer()
            Text(BoardDraftData.time(r.ms)).font(.f1Digits(15)).foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .frame(height: 46)
        .background(r.me ? Theme.accent.opacity(0.14) : .clear)
    }
}

/// `-BoardDraft` value → the draft that replaces the weekly box.
@ViewBuilder
func boardDraft() -> some View {
    switch UserDefaults.standard.string(forKey: "BoardDraft") {
    case "A": BoardDraftTopThree()
    case "B": BoardDraftPodium()
    case "C": BoardDraftTower()
    default: EmptyView()
    }
}
#endif
