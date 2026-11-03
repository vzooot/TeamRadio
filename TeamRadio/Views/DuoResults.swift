import SwiftUI

/// The iPhone Duo's Results tab held like a book. The left screen previews
/// what the right one picks: a round's classification (race, sprint or
/// qualifying) or the championship after that round (drivers or teams).
/// The right screen holds the selections and the season's rounds.
struct DuoResults: View {
    let halves: Halves
    let model: ResultsViewModel
    /// Results or standings on the display (the root's, so links and the
    /// title moment can open the standings).
    @Binding var page: ResultsHubView.Page

    private var show: ResultsHubView.Page { page }
    @State private var mode: ResultsView.Mode?
    @State private var teams = false
    /// Spoiler mode (shared with the phone pages): blurred until tapped.
    @AppStorage("spoilerMode") private var spoilerMode = false
    @State private var revealed = false

    private var isShielded: Bool { spoilerMode && !revealed }

    private var modes: [ResultsView.Mode] {
        model.calendarRace?.isSprintWeekend == true ? [.race, .sprint, .qualifying] : [.race, .qualifying]
    }

    /// Falls back to the first session that has results.
    private var resolved: ResultsView.Mode {
        if let mode, modes.contains(mode) { return mode }
        if model.raceResults?.isEmpty == false { return .race }
        if model.sprintResults?.isEmpty == false { return .sprint }
        if model.qualifyingResults?.isEmpty == false { return .qualifying }
        return .race
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                LoadingView()
            case .failed(let message):
                ErrorView(message: message) { Task { await model.load() } }
            case .loaded:
                DuoSideBySide(halves: halves) {
                    preview
                } right: {
                    selections
                }
            }
        }
        .task { await model.load() }
        .onChange(of: model.selectedRound) { _, _ in revealed = false }
        .onChange(of: spoilerMode) { _, _ in revealed = false }
    }

    // MARK: The preview

    private var previewTitle: String { show == .results ? resolved.rawValue : (teams ? "TEAMS" : "DRIVERS") }

    private var previewSubtitle: String {
        guard let race = model.calendarRace else { return "" }
        if show == .standings { return StandingsAfterRound.subtitle(model) }
        return "\(Flags.emoji(for: race.circuit.location.country)) \(race.raceName.uppercased()) · ROUND \(race.roundNumber)"
    }

    private var preview: some View {
        DuoScreen {
            DuoTitle(title: previewTitle, subtitle: previewSubtitle) {
                // spoiler mode: results and standings stay hidden until tapped
                Button {
                    spoilerMode.toggle()
                    revealed = false
                } label: {
                    Image(systemName: spoilerMode ? "eye.slash.fill" : "eye")
                        .font(.system(size: 17))
                        .foregroundStyle(spoilerMode ? Theme.accent : Theme.dimText)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.05))
                            .overlay(Circle().strokeBorder(spoilerMode ? Theme.accent.opacity(0.5) : Theme.cardStroke, lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spoilerMode ? "Show spoilers" : "Hide spoilers")
            }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if show == .results { session } else { StandingsAfterRound(model: model, teams: teams) }
                }
                .id("\(model.selectedRound ?? "")-\(show)-\(resolved)-\(teams)")
                .blur(radius: isShielded ? 18 : 0)
                .allowsHitTesting(!isShielded)
                .overlay(alignment: .top) {
                    if isShielded {
                        SpoilerShield(text: show == .results ? "Tap to reveal the results" : "Tap to reveal the standings")
                            .frame(height: 300)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { if isShielded { revealed = true } }
                .animation(.easeInOut(duration: 0.25), value: isShielded)
                .opacity(model.isSwitching ? 0.35 : 1)
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .refreshable { await model.load() }
        }
    }

    /// The classification for the session picked, or when it's due.
    @ViewBuilder
    private var session: some View {
        switch resolved {
        case .race:
            if let results = model.raceResults, !results.isEmpty {
                PodiumView(results: results)
                if let fastest = results.first(where: { $0.hasFastestLap }) {
                    FastestLapCard(result: fastest)
                }
                RaceClassificationView(results: results)
            } else {
                notYet("The grand prix hasn't been classified yet", at: model.calendarRace?.startDate)
            }
        case .sprint:
            if let results = model.sprintResults, !results.isEmpty {
                PodiumView(results: results)
                RaceClassificationView(results: results)
            } else {
                notYet("The sprint hasn't been classified yet", at: model.calendarRace?.sessions.first { $0.kind == .sprint }?.date)
            }
        case .qualifying:
            if let results = model.qualifyingResults, !results.isEmpty {
                QualifyingClassificationView(results: results)
            } else {
                notYet("Qualifying hasn't been classified yet", at: model.calendarRace?.sessions.first { $0.kind == .qualifying }?.date)
            }
        }
    }

    private func notYet(_ message: String, at date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("⏳ \(message.uppercased())")
                .font(.f1(16).italic())
                .foregroundStyle(.white)
            if let date, date > .now {
                Text("Scheduled for \(date.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.dimText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.glassStroke, lineWidth: 1)))
    }

    // MARK: The selections

    private var selections: some View {
        DuoScreen {
            DuoTitle(title: "SEASON", subtitle: "\(model.pickerRaces.count) ROUNDS RUN · PICK ONE")
        } content: {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ON THE DISPLAY")
                        .font(.f1(10, weight: .bold))
                        .tracking(2.5)
                        .foregroundStyle(Theme.dimText)
                    GlowSelector(options: [
                        .init(id: "results", title: "RESULTS", symbol: "flag.checkered", tint: Theme.accent),
                        .init(id: "standings", title: "STANDINGS", symbol: "trophy", tint: Theme.violet),
                    ], selected: show == .results ? "results" : "standings") {
                        page = $0 == "results" ? .results : .standings
                    }
                }
                if show == .results {
                    chips(modes.map(\.rawValue), selected: resolved.rawValue, tints: modes.map(Self.tint)) {
                        mode = ResultsView.Mode(rawValue: $0)
                    }
                } else {
                    chips(["DRIVERS", "CONSTRUCTORS"], selected: teams ? "CONSTRUCTORS" : "DRIVERS", tints: [Theme.accent, Theme.violet]) {
                        teams = $0 == "CONSTRUCTORS"
                    }
                }
                rounds
            }
            .padding(16)
        }
    }

    private static func tint(_ mode: ResultsView.Mode) -> Color {
        switch mode {
        case .race: Theme.live
        case .sprint: Theme.accent
        case .qualifying: Theme.violet
        }
    }

    /// A row of the app's neon chips.
    private func chips(_ titles: [String], selected: String, tints: [Color], onSelect: @escaping (String) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(titles.enumerated()), id: \.element) { index, title in
                Button { onSelect(title) } label: {
                    NeonChip(title: title, tint: tints[min(index, tints.count - 1)], selected: title == selected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(title == selected ? .isSelected : [])
            }
        }
    }

    /// The rounds run so far, the latest on top; tap one to preview it.
    private var rounds: some View {
        ScrollView {
            VStack(spacing: 0) {
                let list = Array(model.pickerRaces.reversed())
                ForEach(list) { race in
                    let on = race.round == model.selectedRound
                    Button {
                        Task { await model.select(round: race.round) }
                    } label: {
                        HStack(spacing: 12) {
                            Text("R\(race.roundNumber)")
                                .font(.f1(13).italic())
                                .foregroundStyle(on ? Theme.onAccent : Theme.dimText)
                                .frame(width: 44, height: 26)
                                .background(RoundedRectangle(cornerRadius: 7)
                                    .fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06))))
                            Text(Flags.emoji(for: race.circuit.location.country))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(race.raceName.uppercased())
                                    .font(.f1(14, weight: .bold))
                                    .foregroundStyle(on ? .white : .white.opacity(0.85))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(race.circuit.location.locality.uppercased())
                                    .font(.f1(10, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(Theme.dimText)
                            }
                            Spacer(minLength: 4)
                            if on {
                                Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(on ? Theme.accent.opacity(0.1) : .clear)
                        .overlay(alignment: .leading) {
                            if on { Rectangle().fill(Theme.accent).frame(width: 3) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Round \(race.roundNumber), \(race.raceName)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                    if race.id != list.last?.id { Divider().overlay(Color.white.opacity(0.06)) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke, lineWidth: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .scrollIndicators(.hidden)
    }
}
