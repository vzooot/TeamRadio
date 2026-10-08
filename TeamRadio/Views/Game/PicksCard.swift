import SwiftUI

/// The prediction game on the Countdown tab, under the countdown.
/// Figma: Prediction Game → Game/Picks card.
struct PicksCard: View {
    @Bindable var game: GameViewModel
    let onOpen: () -> Void
    let onShowResult: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            card(now: context.date)
        }
    }

    @ViewBuilder
    private func card(now: Date) -> some View {
        let state = game.cardState(at: now)
        VStack(alignment: .leading, spacing: 14) {
            header(state)
            switch game.access {
            case .checking:
                ProgressView().tint(Theme.accent).frame(maxWidth: .infinity)
            case .needsICloud:
                note("Sign in to iCloud in Settings to play. Your iCloud account is your player identity.")
            case .needsName:
                note("Pick a Paddock name in the Paddock tab first. It's how you appear on the leaderboard.")
            case .ready:
                content(state, now: now)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Theme.card, Color(red: 0.065, green: 0.073, blue: 0.105)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
                .trioGlow(cornerRadius: 20)
        )
    }

    private func header(_ state: GameViewModel.CardState) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow(state))
                    .font(.f1(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                Text(isScored(state) ? "YOUR RESULT" : "YOUR PICKS")
                    .font(.f1(24))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            if game.access == .ready { StatusPill(state: state) }
        }
    }

    private func eyebrow(_ state: GameViewModel.CardState) -> String {
        if case let .scored(race, _, _) = state {
            return "PREDICTION GAME · R\(race.round) \(Self.shortName(race))"
        }
        guard let race = game.race else { return "PREDICTION GAME" }
        return "PREDICTION GAME · R\(race.round) \(Self.shortName(race))"
    }

    static func shortName(_ race: Race) -> String {
        race.raceName.replacingOccurrences(of: " Grand Prix", with: "").uppercased()
    }

    private func isScored(_ state: GameViewModel.CardState) -> Bool {
        if case .scored = state { return true }
        return false
    }

    @ViewBuilder
    private func content(_ state: GameViewModel.CardState, now: Date) -> some View {
        switch state {
        case .open:
            Text("Call pole, the podium, fastest lap and this week's wildcard. Picks lock when qualifying starts.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.dimText)
                .fixedSize(horizontal: false, vertical: true)
            lockCountdown(now: now)
            Button(action: onOpen) {
                Text("MAKE YOUR PICKS")
            }
            .buttonStyle(GamePrimaryButtonStyle())

        case .picked, .locked:
            PicksStrip(game: game, prediction: game.saved?.prediction ?? game.draft, score: nil)
            if let label = game.wildcard.label(for: (game.saved?.prediction ?? game.draft).wildcard) {
                Text("Wildcard: \(game.wildcard.question) · \(label)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dimText)
            }
            if state == .picked {
                Text("Locks in \(Self.remaining(until: game.lockDate, now: now)) · change them any time before qualifying")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faintText)
                Button(action: onOpen) {
                    Text("EDIT PICKS")
                }
                .buttonStyle(GameOutlineButtonStyle())
            } else {
                Label("Locked at qualifying · scored after the race", systemImage: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dimText)
            }

        case .missed:
            note("Picks for this round closed when qualifying started. The next round opens after the race.")

        case let .scored(_, score, prediction):
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("+\(score.total)")
                        .font(.f1Digits(56))
                    Text("PTS")
                        .font(.f1(17))
                }
                .foregroundStyle(Theme.accent)
                .shadow(color: Theme.accent.opacity(0.5), radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(score.exactPicks) exact picks")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Leaderboard comes with the next update")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dimText)
                }
            }
            PicksStrip(game: game, prediction: prediction, score: score)
            Button(action: onShowResult) {
                Text("SEE BREAKDOWN")
            }
            .buttonStyle(GameOutlineButtonStyle())
        }
    }

    private func lockCountdown(now: Date) -> some View {
        HStack(spacing: 8) {
            Text("LOCKS IN")
                .font(.f1(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.faintText)
            ForEach(Self.parts(until: game.lockDate, now: now), id: \.self) { part in
                Text(part)
                    .font(.f1Digits(17))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.08)))
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.dimText)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "2D", "14H", "32M" until the lock.
    static func parts(until date: Date?, now: Date) -> [String] {
        guard let date else { return [] }
        let left = max(0, Int(date.timeIntervalSince(now)))
        let d = left / 86400, h = left % 86400 / 3600, m = left % 3600 / 60
        return d > 0 ? ["\(d)D", "\(h)H", "\(m)M"] : ["\(h)H", "\(m)M"]
    }

    static func remaining(until date: Date?, now: Date) -> String {
        parts(until: date, now: now).joined(separator: " ").lowercased()
    }
}

private struct StatusPill: View {
    let state: GameViewModel.CardState

    var body: some View {
        let (text, color): (String, Color) = switch state {
        case .open: ("OPEN", Theme.accent)
        case .picked: ("PICKED ✓", Color(red: 0.2, green: 0.9, blue: 0.6))
        case .locked: ("LOCKED", Theme.dimText)
        case .missed: ("CLOSED", Theme.faintText)
        case .scored: ("SCORED", Theme.violet)
        }
        Text(text)
            .font(.f1(11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

/// POLE · P1 · P2 · P3 · FL in five small tiles, with points once scored.
struct PicksStrip: View {
    let game: GameViewModel
    let prediction: Prediction
    let score: ScoreBreakdown?

    var body: some View {
        let picks: [(String, String?, ScoreBreakdown.Kind)] = [
            ("POLE", prediction.pole, .pole), ("P1", prediction.p1, .p1), ("P2", prediction.p2, .p2),
            ("P3", prediction.p3, .p3), ("FL", prediction.fastestLap, .fastestLap),
        ]
        HStack(spacing: 6) {
            ForEach(picks, id: \.0) { label, id, kind in
                let driver = game.driver(id)
                VStack(spacing: 3) {
                    Text(label)
                        .font(.f1(11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.faintText)
                    Text(driver?.code ?? "—")
                        .font(.f1(17))
                        .foregroundStyle(.white)
                    Capsule()
                        .fill(Theme.teamColor(driver?.teamId))
                        .frame(width: 22, height: 3)
                    if let item = score?.items.first(where: { $0.kind == kind }) {
                        Text(Self.mark(item))
                            .font(.f1(11, weight: .bold))
                            .foregroundStyle(Self.color(item.outcome))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            }
        }
    }

    static func mark(_ item: ScoreBreakdown.Item) -> String {
        switch item.outcome {
        case .exact: "✓ \(item.points)"
        case .partial: "~ \(item.points)"
        case .miss: "✗ 0"
        }
    }

    static func color(_ outcome: ScoreBreakdown.Outcome) -> Color {
        switch outcome {
        case .exact: Color(red: 0.2, green: 0.78, blue: 0.35)
        case .partial: Theme.accent
        case .miss: Color(red: 1, green: 0.4, blue: 0.35)
        }
    }
}

struct GamePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.f1(15).italic())
            .tracking(2)
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentGradient))
            .shadow(color: Theme.accent.opacity(0.5), radius: 10)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct GameOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.f1(12, weight: .bold))
            .tracking(1)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accent.opacity(0.5)))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
