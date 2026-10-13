import SwiftUI

struct ContentView: View {
    @State private var model = RaceViewModel()
    @State private var showAbout = false
    @State private var dotd = DotdModel()
    @State private var showDotd = false
    @State private var showEmily = false
    /// The race strip is open: the page holds still meanwhile.
    @State private var raceDock = false
    /// Which way the last race switch went, so the page follows the card.
    @State private var raceEdge: Edge = .trailing

    /// The schedule and circuit are on screen (false while a switch swaps them).
    @State private var sectionsShown = true

    /// Switching race: the countdown stays and updates in place, its digits
    /// rolling to the new race; the schedule and circuit slip out, are
    /// swapped while hidden (so no rebuild ever shows as a stutter), then
    /// rise back in one after the other. Map and weather load after that.
    /// nil goes back to the next race.
    private func switchRace(to race: Race?) {
        sectionsShown = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            model.show(race)
            try? await Task.sleep(for: .milliseconds(40))
            sectionsShown = true
            await model.refreshExtras()
        }
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
            guard GameFeature.isEnabled, !model.season.isEmpty else { return }
            // Before the results are in, the vote lists the championship order.
            let standings = (try? await F1API.driverStandings(limit: 30)) ?? []
            let drivers = standings.map {
                GameDriver(id: $0.driver.driverId, code: $0.driver.shortCode, familyName: $0.driver.familyName,
                           number: $0.driver.permanentNumber, teamId: $0.teamId)
            }
            await dotd.load(season: model.season, fallbackDrivers: drivers)
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
    }

    private var loadedContent: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // The very top of the page (the LIVE bar included), where a
                // pick from the season list glides back to.
                VStack(alignment: .leading, spacing: 22) {
                    if let race = model.nextRace {
                        // Broadcast-style LIVE bar sits above everything, so the
                        // helmet below still hangs over the race card.
                        LiveSessionBanner(race: race)
                    }

                    HeaderView(onInfo: { showAbout = true })
                }
                .padding(.bottom, -6)
                // the helmet hangs over the race card, so the header draws on top
                .zIndex(1)
                .id("top")

                if let race = model.displayRace {

                    RaceHeroCarousel(season: model.season, race: race, dockActive: $raceDock, edge: $raceEdge,
                                     nextId: model.nextRace?.id, onBack: backToNextRace) { picked in
                        switchRace(to: picked)
                    }
                    .id("hero")

                    CountdownView(race: race)

                    // The weekend's sessions always right under the countdown.
                    VStack {
                        WeekendScheduleView(race: race, weather: model.weather, weatherLoading: model.extrasLoading)
                            .id(race.id)
                    }
                    .cascade(sectionsShown, delay: 0)
                    .id("schedule")

                    // ...and the circuit right after the weekend's sessions.
                    VStack {
                        if let map = model.trackMap {
                            // fades only: the 3D scene is too heavy to slide
                            TrackSectionView(map: map, circuit: race.circuit)
                                .id(race.circuit.circuitId)
                        } else if model.extrasLoading {
                            TrackPlaceholder()
                        }
                    }
                    .cascade(sectionsShown, delay: 0.08)
                    .id("trackSection")

                    #if DEBUG
                    if BlendDraft.gameZoneInApp {
                        GameZoneDraft(variant: UserDefaults.standard.string(forKey: "GameZoneDraft") ?? "").id("gameZone")
                    }
                    #endif
                    // The fan vote and the AI race engineer; the games
                    // themselves live in the Games tab.
                    if GameFeature.isEnabled, !model.isBrowsing {
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            VStack(spacing: 14) {
                                if dotd.race != nil {
                                    DotdBoldCard(model: dotd, now: context.date, onVote: { showDotd = true })
                                }
                                EmilyBar(onTap: { showEmily = true })
                            }
                        }
                        .transaction(value: model.isBrowsing) { $0.animation = nil }
                    }

                    if !Self.demoMode {
                        InviteBanner()
                    }
                } else {
                    SeasonOverBanner()
                }

                // (The championship lives in the Standings tab, not here.)

                if model.displayRace != nil {
                    // Settings for every session, just above the season's races.
                    SessionAlertsCard(season: model.season)
                        .id("alerts")
                }

                if !model.season.isEmpty {
                    SeasonView(season: model.season, nextRaceId: model.nextRace?.id,
                               selectedId: model.displayRace?.id) { race in
                        pickFromSeason(race, proxy: proxy)
                    }
                    .id("season")
                }

                FooterView()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
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
        .task {
            // -SeasonTap N: scroll to the season list and pick round N there
            let n = UserDefaults.standard.integer(forKey: "SeasonTap")
            guard n > 0 else { return }
            try? await Task.sleep(for: .seconds(4))
            guard model.season.indices.contains(n - 1) else { return }
            proxy.scrollTo("season", anchor: .bottom)
            try? await Task.sleep(for: .seconds(1.5))
            pickFromSeason(model.season[n - 1], proxy: proxy)
        }
        .task {
            // -RaceCycle N: switch race N times (ahead, ahead, back to the
            // next race …) for profiling the switch
            let n = UserDefaults.standard.integer(forKey: "RaceCycle")
            guard n > 0 else { return }
            try? await Task.sleep(for: .seconds(5))
            for i in 0..<n {
                let base = model.season.firstIndex { $0.id == model.nextRace?.id } ?? 0
                let step = i % 3
                let j = base + step + 1
                let target = step == 2 || !model.season.indices.contains(j) ? nil : model.season[j]
                switchRace(to: target)
                try? await Task.sleep(for: .seconds(2))
            }
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
    /// A race tapped in the season list at the bottom of the page.
    private func pickFromSeason(_ race: Race, proxy: ScrollViewProxy) {
        let from = model.season.firstIndex { $0.id == model.displayRace?.id } ?? 0
        raceEdge = (model.season.firstIndex { $0.id == race.id } ?? 0) >= from ? .trailing : .leading
        // Glide all the way up first, then switch: switching changes the
        // page's height, which stopped the glide short when both ran at once.
        withAnimation(.easeInOut(duration: 0.45)) { proxy.scrollTo("top", anchor: .top) }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            switchRace(to: race)
        }
    }

    /// The card's "next race" button: back from browsing.
    private func backToNextRace() {
        let from = model.season.firstIndex { $0.id == model.displayRace?.id } ?? 0
        let to = model.season.firstIndex { $0.id == model.nextRace?.id } ?? 0
        raceEdge = to >= from ? .trailing : .leading
        switchRace(to: nil)
    }
}

private extension View {
    /// Slips out fast when hidden, rises back in with a soft spring after
    /// `delay` when shown (opacity and offset only, so it stays cheap).
    func cascade(_ shown: Bool, delay: Double) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 22)
            .animation(shown ? .spring(response: 0.45, dampingFraction: 0.8).delay(delay) : .easeIn(duration: 0.1),
                       value: shown)
    }
}

// MARK: - Header

/// The header's About & settings button: a dark glass disc with a steering
/// wheel, inside a slowly turning ring in the trio colours.
struct CockpitButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let angle = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8) / 8 * 360
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [Theme.accent, Theme.violet, Theme.live, Theme.accent], center: .center),
                        lineWidth: 2.5)
                    .rotationEffect(.degrees(angle))
                    .shadow(color: Theme.accent.opacity(0.6), radius: 5)
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
                    .padding(3.5)
                    .overlay(
                        Circle()
                            .fill(LinearGradient(colors: [.white.opacity(0.16), .clear], startPoint: .top, endPoint: .center))
                            .padding(3.5)
                    )
                Image(systemName: "steeringwheel")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.chromeText)
            }
            .frame(width: 42, height: 42)
        }
    }
}

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
                    Button(action: onInfo) { CockpitButton() }
                        .buttonStyle(.plain)
                        .accessibilityLabel("About and settings")
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
