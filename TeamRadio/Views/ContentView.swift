import SwiftUI

struct ContentView: View {
    @State private var model = RaceViewModel()
    @State private var showAbout = false
    @State private var game = GameViewModel()
    @State private var showPicks = false
    @State private var showResult = false
    @State private var showEmily = false
    @State private var dotd = DotdModel()
    @State private var showDotd = false
    @State private var showLightsOut = false
    /// The race strip is open: the page holds still meanwhile.
    @State private var raceDock = false
    /// Which way the last race switch went, so the page follows the card.
    @State private var raceEdge: Edge = .trailing

    /// The race's sections slide in from the side the card moved to (the
    /// old ones leave at once so nothing stacks).
    private var raceSwitch: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(x: raceEdge == .trailing ? 60 : -60)),
                    removal: .identity)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.live.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 460
            )
            .ignoresSafeArea()

            switch model.phase {
            case .loading:
                LoadingView()
            case .failed(let message):
                ErrorView(message: message) {
                    Task { await model.load() }
                }
            case .loaded:
                loadedContent
            }
        }
        .task {
            await model.load()
            // Keep scheduled alerts in sync with any calendar changes.
            await NotificationManager.reschedule(season: model.season)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .task(id: model.nextRace?.id) {
            guard GameFeature.isEnabled else { return }
            await game.load(race: model.nextRace, season: model.season)
            #if DEBUG
            // -FakePicks YES: a signed-in player with three picks, for screenshots
            if UserDefaults.standard.bool(forKey: "FakePicks"), game.drivers.count > 2 {
                game.access = .ready
                game.draft.pole = game.drivers[1].id
                game.draft.p1 = game.drivers[0].id
                game.draft.p2 = game.drivers[2].id
            }
            #endif
            await dotd.load(season: model.season, fallbackDrivers: game.drivers)
            #if DEBUG
            // -FakeVote YES: a cast vote and a three-way tally, for screenshots
            if UserDefaults.standard.bool(forKey: "FakeVote"), dotd.drivers.count > 2 {
                let d = dotd.drivers
                dotd.myVote = d[1].id
                dotd.tally = DotdService.Tally(total: 412, votes: [
                    .init(driverId: d[1].id, count: 214, pct: 52),
                    .init(driverId: d[0].id, count: 124, pct: 30),
                    .init(driverId: d[2].id, count: 74, pct: 18),
                ])
            }
            #endif
        }
        .fullScreenCover(isPresented: $showLightsOut) {
            LightsOutView()
        }
        .sheet(isPresented: $showDotd) {
            DotdSheet(model: dotd)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showEmily) {
            AskEmilyView()
                .presentationDetents([.large])
                .presentationBackground(Theme.background)
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
    }

    private var loadedContent: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let race = model.nextRace {
                    // Broadcast-style LIVE bar sits above everything, so the
                    // helmet below still hangs over the race card.
                    LiveSessionBanner(race: race)
                }

                HeaderView(onInfo: { showAbout = true })
                    .padding(.bottom, -6)
                    .id("top")

                if let race = model.displayRace {

                    RaceHeroCarousel(season: model.season, race: race, dockActive: $raceDock, edge: $raceEdge) { picked in
                        Task { await model.select(picked) }
                    }
                    .id("hero")

                    // Below the card, clear of the helmet.
                    if model.isBrowsing {
                        browsingBar(race)
                    }

                    CountdownView(race: race)
                        .id(race.id)
                        .transition(raceSwitch)

                    #if DEBUG
                    if BlendDraft.gameZoneInApp {
                        GameZoneDraft(variant: UserDefaults.standard.string(forKey: "GameZoneDraft") ?? "").id("gameZone")
                    }
                    #endif
                    if GameFeature.isEnabled, !model.isBrowsing, !Self.gameZoneDraft {
                        GameZone(game: game, dotd: dotd, seasonRounds: model.season.count,
                                 onPicks: { showPicks = true },
                                 onResult: { showResult = true },
                                 onVote: { showDotd = true },
                                 onLightsOut: { showLightsOut = true },
                                 onEmily: { showEmily = true })
                            .id("picks")
                    }

                    VStack {
                        WeekendScheduleView(race: race, weather: model.weather, weatherLoading: model.extrasLoading)
                            .id(race.id)
                            .transition(raceSwitch)
                    }
                    .id("schedule")

                    SessionAlertsCard(season: model.season)
                        .id("alerts")

                    if !Self.demoMode {
                        InviteBanner()
                    }

                    VStack {
                        if let map = model.trackMap {
                            TrackSectionView(map: map, circuit: race.circuit)
                                .id(race.circuit.circuitId)
                                .transition(raceSwitch)
                        } else if model.extrasLoading {
                            TrackPlaceholder()
                        }
                    }
                    .id("trackSection")
                } else {
                    SeasonOverBanner()
                }

                if !model.standings.isEmpty {
                    StandingsView(standings: model.standings)
                }

                if !model.season.isEmpty {
                    SeasonView(season: model.season, nextRaceId: model.nextRace?.id,
                               selectedId: model.displayRace?.id) { race in
                        let from = model.season.firstIndex { $0.id == model.displayRace?.id } ?? 0
                        raceEdge = (model.season.firstIndex { $0.id == race.id } ?? 0) >= from ? .trailing : .leading
                        Task { await model.select(race) }
                        withAnimation(.easeInOut(duration: 0.45)) { proxy.scrollTo("hero", anchor: .top) }
                    }
                }

                FooterView()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .animation(.snappy(duration: 0.4), value: model.displayRace?.id)
            .animation(.easeOut(duration: 0.3), value: model.extrasLoading)
        }
        .scrollDisabled(raceDock)
        .refreshable { await model.load() }
        #if DEBUG
        .task { await DemoDirector.shared.runIfNeeded() }
        .task {
            // -ScrollTo <id>: jump to a section for screenshots
            guard let id = UserDefaults.standard.string(forKey: "ScrollTo") else { return }
            try? await Task.sleep(for: .seconds(4))
            proxy.scrollTo(id, anchor: .top)
        }
        .onChange(of: DemoDirector.shared.scroll) { _, step in
            guard let step else { return }
            let id: String = step.target == "countdown" ? (model.displayRace?.id ?? "") : step.target
            withAnimation(.easeInOut(duration: step.duration)) { proxy.scrollTo(id, anchor: step.anchor) }
        }
        #endif
        }
    }

    /// Debug-only: the four game cards replaced by the game-zone design draft.
    private static var gameZoneDraft: Bool {
        #if DEBUG
        BlendDraft.gameZoneInApp
        #else
        false
        #endif
    }

    /// Debug-only demo recordings hide anything not yet released.
    private static var demoMode: Bool {
        #if DEBUG
        DemoDirector.shared.isActive
        #else
        false
        #endif
    }

    /// Shown while looking at a round other than the next one.
    private func browsingBar(_ race: Race) -> some View {
        HStack(spacing: 10) {
            Text(race.isPast ? "PAST ROUND" : "UPCOMING ROUND")
                .font(.f1(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.dimText)
            Spacer()
            Button {
                Task { await model.select(nil) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .bold))
                    Text("BACK TO NEXT RACE")
                        .font(.f1(11, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.accent.opacity(0.1))
                        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.top, -8)
    }
}

// MARK: - Header

struct HeaderView: View {
    var onInfo: (() -> Void)? = nil

    var body: some View {
        ZStack {
            HStack {
                // Screen blend melts the wordmark's black ground into the
                // page gradient, leaving only the glowing letters.
                Image("HeaderWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .blendMode(.screen)
                    .accessibilityLabel("Team Radio")

                Spacer()

                if let onInfo {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.dimText)
                    }
                    .buttonStyle(.plain)
                }
            }

            // The helmet (transparent PNG) sits centre stage and hangs over
            // the top edge of the race card below.
            Image("HeaderHelmet")
                .resizable()
                .scaledToFit()
                .frame(height: 172)
                .background(
                    // neon bloom: cyan off the visor side, red off the radio arcs
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.45)).frame(width: 130).offset(x: -34, y: 4).blur(radius: 36)
                        Circle().fill(Theme.live.opacity(0.4)).frame(width: 110).offset(x: 46, y: 0).blur(radius: 34)
                    }
                )
                .shadow(color: Theme.accent.opacity(0.45), radius: 18, y: 4)
                .padding(.top, -10)
                .padding(.bottom, -80)
                .accessibilityHidden(true)
        }
        .padding(.top, 4)
        .zIndex(1)
    }
}

// MARK: - Loading / error / empty states

struct LoadingView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            Text("🏁")
                .font(.system(size: 44))
                .scaleEffect(pulse ? 1.15 : 0.9)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
            Text("WARMING UP TYRES…")
                .font(.f1(15).italic())
                .tracking(3)
                .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.violet, Theme.live],
                                                startPoint: .leading, endPoint: .trailing))
        }
        .onAppear { pulse = true }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("🔴 RED FLAG")
                .font(.f1(24).italic())
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Text("RESTART RACE")
                    .font(.f1(15).italic())
                    .tracking(2)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(32)
    }
}

struct SeasonOverBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🏆 SEASON COMPLETE")
                .font(.f1(24).italic())
                .foregroundStyle(.white)
            Text("No more races on the current calendar. See you next season!")
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Toggle for on-device session alerts: one notification 15 minutes before
/// every upcoming session of the season.
struct SessionAlertsCard: View {
    let season: [Race]

    @State private var enabled = NotificationManager.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
            Image(systemName: enabled ? "bell.badge.fill" : "bell.slash")
                .font(.system(size: 20))
                .foregroundStyle(enabled ? Theme.accent : Theme.dimText)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("SESSION ALERTS")
                    .font(.f1(15).italic())
                    .foregroundStyle(.white)
                Text("A notification 15 minutes before every session")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dimText)
            }

            Spacer()

            Toggle("", isOn: $enabled)
                .labelsHidden()
                .tint(Theme.accent)
        }
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        LockScreenCountdownRow()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Theme.glassStroke, lineWidth: 1)
                )
        )
        #if DEBUG
        .onChange(of: DemoDirector.shared.alertsOn) { _, on in
            if let on { withAnimation { enabled = on } }
        }
        #endif
        .onChange(of: enabled) { old, wantsOn in
            guard old != wantsOn else { return }
            #if DEBUG
            if DemoDirector.shared.isActive { return }   // demo: on screen only
            #endif
            Task {
                let result = await NotificationManager.setEnabled(wantsOn, season: season)
                // Flips back if the user denied the permission prompt.
                if result != wantsOn { enabled = result }
            }
        }
    }
}

/// Impossible-to-miss banner shown at the very top while a session is on track.
struct LiveSessionBanner: View {
    let race: Race

    @State private var pulse = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let live = race.sessions.first {
                $0.date <= now && now < $0.date.addingTimeInterval($0.kind.expectedDuration)
            }

            if let live {
                HStack(spacing: 12) {
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .white, radius: pulse ? 10 : 2)
                        .scaleEffect(pulse ? 1.25 : 0.85)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(live.kind.rawValue.uppercased()) · LIVE NOW")
                            .font(.f1(20).italic())
                            .foregroundStyle(.white)
                        Text("\(Flags.emoji(for: race.circuit.location.country)) \(race.raceName)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        SessionClock(start: live.date)
                            .font(.f1Digits(19))
                            .foregroundStyle(.white)
                        Text("SESSION TIME")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Theme.live, Color(red: 0.55, green: 0.12, blue: 0.07)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .shadow(color: Theme.live.opacity(0.55), radius: 18, y: 4)
                )
                .onAppear { pulse = true }
            }
        }
    }
}

struct FooterView: View {
    var body: some View {
        Text("Data: Jolpica F1 API · Unofficial app, not associated with Formula 1")
            .font(.caption2)
            .foregroundStyle(Theme.faintText)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}

#Preview {
    ContentView()
}


/// How early the server starts the Lock Screen countdown for each session,
/// or off. One choice, applied to every session of the season. Sits inside
/// the Session Alerts card.
struct LockScreenCountdownRow: View {
    @State private var lead = PushSync.lead
    private let options: [(Int, String)] = [(0, "OFF"), (15, "15 MIN"), (60, "1 H"), (180, "3 H")]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: lead == 0 ? "lock.slash" : "lock.iphone")
                    .font(.system(size: 20))
                    .foregroundStyle(lead == 0 ? Theme.dimText : Theme.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LOCK SCREEN COUNTDOWN")
                        .font(.f1(15).italic())
                        .foregroundStyle(.white)
                    Text(lead == 0 ? "Off. Pin a session yourself with the pin button."
                         : "Appears by itself before every session, all season")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dimText)
                }
            }
            HStack(spacing: 6) {
                ForEach(options, id: \.0) { value, label in
                    Button { lead = value } label: {
                        NeonChip(title: label, tint: Theme.accent, selected: lead == value)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: lead) { _, value in PushSync.lead = value }
    }
}
