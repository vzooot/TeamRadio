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
        if case let .scored(race, _, _) = state { return "PREDICTION GAME · R\(race.round)" }
        guard let race = game.race else { return "PREDICTION GAME" }
        return "PREDICTION GAME · R\(race.round)"
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
            Text("Call pole, the podium, fastest lap and this week's wildcard. Pole locks when qualifying starts, the rest when the race starts.")
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
                Text(Self.lockStatus(game, now: now))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faintText)
                Button(action: onOpen) {
                    Text("EDIT PICKS")
                }
                .buttonStyle(GameOutlineButtonStyle())
            } else {
                Label("All picks locked · scored after the race", systemImage: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dimText)
            }

        case .missed:
            note("Picks for this round closed when the race started. The next round opens after the race.")

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
                    if let me = game.lastBoard?.me, let total = game.lastBoard?.total {
                        Text("\(me.rank.ordinal) of \(total.formatted())")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(score.exactPicks) exact picks")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    if let strategist = game.lastBoard?.strategist {
                        Text(score.total > strategist.points ? "You beat the \(strategist.name) ✓"
                             : score.total == strategist.points ? "Level with the \(strategist.name)"
                             : "\(strategist.name) scored \(strategist.points)")
                            .font(.system(size: 12))
                            .foregroundStyle(score.total > strategist.points ? PicksStrip.color(.exact) : Theme.dimText)
                    } else {
                        Text("Official rank once the race is scored")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.dimText)
                    }
                }
            }
            if let comment = game.lastBoard?.me?.comment {
                RadioComment(text: comment)
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
            let next = game.nextLock(at: now)
            Text(next?.group == .race ? "RACE PICKS LOCK IN" : "POLE LOCKS IN")
                .font(.f1(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.faintText)
            ForEach(Self.parts(until: next?.date, now: now), id: \.self) { part in
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

    /// "Pole locks in 1d 3h · race picks in 2d 5h", or the race only once
    /// qualifying has started.
    static func lockStatus(_ game: GameViewModel, now: Date) -> String {
        let race = "race picks lock in \(remaining(until: game.lockDate(.race), now: now))"
        if game.isLocked(.quali, at: now) { return "Pole locked · " + race }
        return "Pole locks in \(remaining(until: game.lockDate(.quali), now: now)) · " + race
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

/// The AI post-race comment, styled as a radio message and labelled as AI.
struct RadioComment: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.violet)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .font(.system(size: 13, weight: .medium).italic())
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                Text("AI RACE ENGINEER")
                    .font(.f1(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.violet)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.violet.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.violet.opacity(0.35)))
    }
}

extension Int {
    /// 1st, 2nd, 3rd, 41st…
    var ordinal: String {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        f.locale = Locale(identifier: "en")
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
