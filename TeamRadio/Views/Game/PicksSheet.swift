import SwiftUI

/// Pole → podium → fastest lap → wildcard → review, then "Lock in".
/// Figma: Prediction Game → Picks — podium / Picks — review.
struct PicksSheet: View {
    @Bindable var game: GameViewModel
    @Environment(\.dismiss) private var dismiss

    enum Step: Int, CaseIterable {
        case pole, podium, fastestLap, wildcard, review

        var title: String {
            switch self {
            case .pole: "WHO TAKES POLE?"
            case .podium: "PICK THE PODIUM"
            case .fastestLap: "FASTEST LAP"
            case .wildcard: "THE WILDCARD"
            case .review: "REVIEW YOUR PICKS"
            }
        }

        var caption: String {
            switch self {
            case .pole: "POLE"
            case .podium: "PODIUM"
            case .fastestLap: "FASTEST LAP"
            case .wildcard: "WILDCARD"
            case .review: "REVIEW"
            }
        }
    }

    @State private var step: Step = .pole
    /// Which podium slot (0…2) the next driver tap fills.
    @State private var activeSlot = 0

    init(game: GameViewModel) {
        self.game = game
        // Returning players land on the review with everything filled in.
        let poleClosed = game.isLocked(.quali, at: .now)
        _step = State(initialValue: game.draft.isComplete ? .review : poleClosed ? .podium : .pole)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    stepBar
                    switch step {
                    case .pole:
                        if game.isLocked(.quali, at: .now) {
                            lockedNote("Pole locked when qualifying started.")
                        } else {
                            driverGrid(selected: game.draft.pole) { game.draft.pole = $0; advance() }
                        }
                    case .podium: podium
                    case .fastestLap: driverGrid(selected: game.draft.fastestLap) { game.draft.fastestLap = $0; advance() }
                    case .wildcard: wildcard
                    case .review: review
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            bottomBar
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let race = game.race {
                Text("R\(race.round) · \(race.raceName.uppercased())")
                    .font(.f1(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.accent)
            }
            Text(step.title)
                .font(.f1(24))
                .foregroundStyle(.white)
        }
    }

    private var stepBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Theme.accent : Color.white.opacity(0.06))
                        .frame(height: 4)
                        .shadow(color: s == step ? Theme.accent.opacity(0.8) : .clear, radius: 4)
                        .onTapGesture { if isReachable(s) { withAnimation { step = s } } }
                }
            }
            Text("STEP \(step.rawValue + 1) OF \(Step.allCases.count) · \(step.caption)")
                .font(.f1(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.dimText)
        }
    }

    private func isReachable(_ s: Step) -> Bool {
        s.rawValue <= step.rawValue || game.draft.isComplete
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { step = game.draft.isComplete ? .review : next }
    }

    // MARK: - Podium

    private var podium: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { slot in
                    PodiumSlotView(position: slot + 1, driver: game.driver(game.draft.podium[slot]),
                                   active: slot == activeSlot)
                        .onTapGesture { activeSlot = slot }
                }
            }
            Text("Tap a driver for P\(activeSlot + 1). Tap a filled slot to change it.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.dimText)
            driverGrid(selected: nil, slotOf: { id in
                game.draft.podium.firstIndex(of: id).map { "P\($0 + 1)" }
            }) { id in
                setPodium(id)
            }
        }
    }

    private func setPodium(_ id: String) {
        var podium = game.draft.podium
        // Picking a driver already on the podium moves them.
        if let existing = podium.firstIndex(of: id) { podium[existing] = nil }
        podium[activeSlot] = id
        game.draft.p1 = podium[0]
        game.draft.p2 = podium[1]
        game.draft.p3 = podium[2]
        if let empty = podium.firstIndex(where: { $0 == nil }) {
            activeSlot = empty
        } else {
            advance()
        }
    }

    // MARK: - Driver grid

    private func driverGrid(selected: String?, slotOf: ((String) -> String?)? = nil,
                            onPick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALL DRIVERS · BY CHAMPIONSHIP")
                .font(.f1(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.faintText)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(game.drivers) { driver in
                    let tag = slotOf?(driver.id)
                    DriverTile(driver: driver, selected: driver.id == selected || tag != nil, tag: tag)
                        .onTapGesture { onPick(driver.id) }
                }
            }
        }
    }

    // MARK: - Wildcard

    private var wildcard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(game.wildcard.question)
                .font(.f1(20))
                .foregroundStyle(.white)
            ForEach(game.wildcard.answers) { answer in
                let picked = game.draft.wildcard == answer.id
                Button {
                    game.draft.wildcard = answer.id
                    advance()
                } label: {
                    Text(answer.label.uppercased())
                        .font(.f1(17))
                        .foregroundStyle(picked ? .white : Theme.dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(picked ? Theme.accent.opacity(0.12) : Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(picked ? Theme.accent : Color.white.opacity(0.08), lineWidth: picked ? 1.5 : 1))
                }
                .buttonStyle(.plain)
            }
            Text("Worth \(GameRules.wildcard) points. Answered automatically from the official results.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.faintText)
        }
    }

    // MARK: - Review

    private var review: some View {
        VStack(alignment: .leading, spacing: 8) {
            reviewRow("POLE", game.draft.pole, edit: .pole, group: .quali)
            reviewRow("WINNER · P1", game.draft.p1, edit: .podium, slot: 0)
            reviewRow("P2", game.draft.p2, edit: .podium, slot: 1)
            reviewRow("P3", game.draft.p3, edit: .podium, slot: 2)
            reviewRow("FASTEST LAP", game.draft.fastestLap, edit: .fastestLap)
            row(label: "WILDCARD", value: "\(game.wildcard.label(for: game.draft.wildcard) ?? "—")  ·  \(game.wildcard.question)",
                color: Theme.accent, edit: .wildcard)

            if let next = game.nextLock(at: .now) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(PickGroup.allCases, id: \.self) { group in
                        if let lock = game.lockDate(group) {
                            Text("🔒 \(group == .quali ? "POLE" : "RACE PICKS") · \(lock.formatted(.dateTime.weekday(.abbreviated).hour().minute()).uppercased())\(lock > .now ? " · IN \(PicksCard.remaining(until: lock, now: .now).uppercased())" : " · LOCKED")")
                                .font(.f1(11, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(group == next.group ? Theme.accent : Theme.dimText)
                        }
                    }
                    Text("Each pick locks when its session starts: pole at qualifying, the rest at the race. Until then you can change them as often as you like.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dimText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accent.opacity(0.35)))
                .padding(.top, 6)
            }
            Text("Up to \(GameRules.maximum) points: pole \(GameRules.pole) · winner \(GameRules.winner) · P2 \(GameRules.second) · P3 \(GameRules.third) · fastest lap \(GameRules.fastestLap) · wildcard \(GameRules.wildcard) · perfect podium +\(GameRules.perfectPodium). A podium driver in the wrong slot still earns \(GameRules.podiumWrongSlot).")
                .font(.system(size: 12))
                .foregroundStyle(Theme.faintText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func reviewRow(_ label: String, _ id: String?, edit: Step, slot: Int? = nil, group: PickGroup = .race) -> some View {
        let driver = game.driver(id)
        return row(label: label, value: driver.map { "\($0.code)  ·  \($0.familyName)" } ?? "—",
                   color: Theme.teamColor(driver?.teamId), edit: edit, slot: slot, group: group)
    }

    private func lockedNote(_ text: String) -> some View {
        Label(text, systemImage: "lock.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.dimText)
            .padding(.vertical, 20)
    }

    private func row(label: String, value: String, color: Color, edit: Step, slot: Int? = nil, group: PickGroup = .race) -> some View {
        HStack(spacing: 12) {
            Capsule().fill(color).frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.f1(11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.faintText)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if game.isLocked(group, at: .now) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faintText)
            } else {
                Button("Edit") {
                    if let slot { activeSlot = slot }
                    withAnimation { step = edit }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let error = game.errorText {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.live)
            }
            if step == .review {
                Button {
                    Task { if await game.lockIn() { dismiss() } }
                } label: {
                    if game.isSaving { ProgressView().tint(Theme.onAccent) } else { Text("LOCK IN PICKS") }
                }
                .buttonStyle(GamePrimaryButtonStyle())
                .disabled(!game.canLockIn(at: .now) || game.isSaving)
            } else if step == .podium, game.draft.podium.contains(where: { $0 == nil }) {
                Text("PICK \(missingSlots)")
                    .modifier(DisabledLabel())
            } else if step == .podium {
                Button("NEXT: FASTEST LAP") { advance() }
                    .buttonStyle(GamePrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    private var missingSlots: String {
        let missing = game.draft.podium.enumerated().filter { $0.element == nil }.map { "P\($0.offset + 1)" }
        return missing.count > 1 ? missing.dropLast().joined(separator: ", ") + " AND " + missing.last! : missing.joined()
    }
}

private struct DisabledLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.f1(15).italic())
            .tracking(2)
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentGradient))
            .opacity(0.4)
    }
}

/// Figma: Game/Driver tile.
struct DriverTile: View {
    let driver: GameDriver
    let selected: Bool
    let tag: String?

    var body: some View {
        HStack(spacing: 10) {
            Capsule().fill(Theme.teamColor(driver.teamId)).frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(driver.code)
                    .font(.f1(17))
                    .foregroundStyle(.white)
                Text(driver.familyName)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(tag ?? driver.number.map { "#\($0)" } ?? "")
                .font(.f1(12))
                .foregroundStyle(selected ? Theme.accent : Theme.faintText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Theme.accent.opacity(0.12) : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(selected ? Theme.accent : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1))
        .shadow(color: selected ? Theme.accent.opacity(0.45) : .clear, radius: 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Figma: Game/Podium slot.
struct PodiumSlotView: View {
    let position: Int
    let driver: GameDriver?
    let active: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("P\(position)")
                .font(.f1(14))
                .foregroundStyle(driver == nil && !active ? Theme.faintText : Theme.accent)
            if let driver {
                Text(driver.code)
                    .font(.f1(30))
                    .foregroundStyle(.white)
                Text(driver.familyName)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(1)
                Capsule().fill(Theme.teamColor(driver.teamId)).frame(width: 28, height: 4)
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(active ? Theme.accent : Theme.faintText)
                    .frame(height: 36)
                Text(active ? "Pick a driver" : "Empty")
                    .font(.system(size: 12))
                    .foregroundStyle(active ? Theme.accent : Theme.faintText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118)
        .background(RoundedRectangle(cornerRadius: 16).fill(active ? Theme.accent.opacity(0.12) : driver == nil ? Color.white.opacity(0.06) : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(active ? Theme.accent : Color.white.opacity(0.08),
                          style: StrokeStyle(lineWidth: active ? 1.5 : 1, dash: driver == nil ? [5, 4] : [])))
        .shadow(color: active ? Theme.accent.opacity(0.45) : .clear, radius: 8)
        .contentShape(Rectangle())
    }
}

/// The result breakdown after the race. Figma: Prediction Game → Result reveal.
struct ResultSheet: View {
    let game: GameViewModel
    let race: Race
    let score: ScoreBreakdown
    let prediction: Prediction

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("R\(race.round) · \(race.raceName.uppercased()) · SCORED")
                    .font(.f1(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.accent)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("+\(score.total)").font(.f1Digits(56))
                    Text("PTS").font(.f1(17))
                }
                .foregroundStyle(Theme.accent)
                .shadow(color: Theme.accent.opacity(0.6), radius: 12)

                ForEach(score.items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.outcome == .exact ? "checkmark" : item.outcome == .partial ? "arrow.left.arrow.right" : "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(PicksStrip.color(item.outcome))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(PicksStrip.color(item.outcome).opacity(0.18)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.kind.label)
                                .font(.f1(11, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.faintText)
                            Text(detail(item))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Spacer(minLength: 0)
                        Text(item.points > 0 ? "+\(item.points)" : "0")
                            .font(.f1(17))
                            .foregroundStyle(PicksStrip.color(item.outcome))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
                }
            }
            .padding(16)
            .padding(.top, 12)
        }
        .background(Theme.background)
    }

    private func detail(_ item: ScoreBreakdown.Item) -> String {
        if item.kind == .perfectPodium { return "All three in the right order" }
        let wildcard = Wildcard.forRound(race.roundNumber)
        func name(_ id: String?) -> String {
            item.kind == .wildcard ? (wildcard.label(for: id) ?? "—") : (game.driver(id)?.code ?? id ?? "—")
        }
        return "You: \(name(item.picked)) · Result: \(name(item.actual))"
    }
}
