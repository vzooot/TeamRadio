import SwiftUI

/// The iPhone Duo's Countdown tab as two screens, each its title on top and
/// its box below. The left screen is the display: the race and its countdown
/// (the session chips, the ring clock, the start lights, the weather), or
/// the circuit, or the standings. Swipe it, or tap its arrows, to go
/// through the season's races. The right screen picks what the display
/// shows, and holds Ask Emily, the Lock Screen line, the weekend's
/// timetable, then the fan vote and the season.
struct DuoCountdown<Extras: View>: View {
    enum Show: String, CaseIterable {
        case countdown = "COUNTDOWN", circuit = "CIRCUIT", standings = "STANDINGS"

        var option: GlowSelector.Option {
            switch self {
            case .countdown: .init(id: rawValue, title: rawValue, symbol: "timer", tint: Theme.accent)
            case .circuit: .init(id: rawValue, title: rawValue, symbol: "point.topleft.down.to.point.bottomright.curvepath", tint: Theme.violet)
            case .standings: .init(id: rawValue, title: rawValue, symbol: "trophy", tint: Theme.live)
            }
        }
    }

    let halves: Halves
    let race: Race
    let model: RaceViewModel
    let standings: StandingsViewModel
    let onSettings: () -> Void
    let onEmily: () -> Void
    /// Go to another race of the season (nil: back to the next one).
    let onSelectRace: (Race?) -> Void
    @ViewBuilder let extras: Extras

    #if DEBUG
    // -DuoShow CIRCUIT|STANDINGS: open the display on it, for screenshots
    @State private var show: Show = Show(rawValue: UserDefaults.standard.string(forKey: "DuoShow") ?? "") ?? .countdown
    #else
    @State private var show: Show = .countdown
    #endif
    /// The session the countdown runs to (picked on the display; nil = the next one).
    @State private var selectedId: String?
    @AppStorage("spoilerMode") private var spoilerMode = false
    @State private var revealed = false

    var body: some View {
        Group {
            if halves.axis == .horizontal {
                DuoSideBySide(fold: halves.fold) {
                    display(wide: false)
                } right: {
                    deck
                }
            } else {
                // standing like a laptop: the display on top, the rest below
                GeometryReader { geo in
                    let first = max(0, halves.fold - 14)
                    VStack(spacing: 28) {
                        display(wide: true).frame(height: first)
                        deck.frame(height: max(0, geo.size.height - 8 - 28 - first))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .onChange(of: race.id) { _, _ in selectedId = nil }
        .onChange(of: spoilerMode) { _, _ in revealed = false }
    }

    // MARK: Sessions and races

    private func target(now: Date) -> WeekendSession? {
        if let selectedId, let chosen = race.sessions.first(where: { $0.id == selectedId }) { return chosen }
        if let live = race.sessions.first(where: { isLive($0, now) }) { return live }
        return race.sessions.first { $0.date > now } ?? race.sessions.last
    }

    private func isLive(_ session: WeekendSession, _ now: Date) -> Bool {
        session.date <= now && now < session.date.addingTimeInterval(session.kind.expectedDuration)
    }

    private static func tint(_ kind: WeekendSession.Kind) -> Color {
        switch kind {
        case .practice1, .practice2, .practice3: Theme.accent
        case .sprintQualifying, .qualifying: Theme.violet
        case .sprint, .race: Theme.live
        }
    }

    private var index: Int? { model.season.firstIndex { $0.id == race.id } }

    private func step(_ by: Int) {
        guard let index, model.season.indices.contains(index + by) else { return }
        let next = model.season[index + by]
        onSelectRace(next.id == model.nextRace?.id ? nil : next)
    }

    // MARK: The display

    private func display(wide: Bool) -> some View {
        DuoScreen(flag: show == .countdown ? Flags.emoji(for: race.circuit.location.country) : nil) {
            HeaderView(onInfo: onSettings)
                .padding(.bottom, -6)
        } content: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Group {
                    switch show {
                    case .countdown: countdownFace(now: context.date, wide: wide)
                    case .circuit: circuitFace
                    case .standings: standingsFace
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: show)
    }

    /// The race, its sessions, the ring clock, the start lights and the
    /// weather; swipe sideways for the previous or next race.
    private func countdownFace(now: Date, wide: Bool) -> some View {
        let session = target(now: now)
        return GeometryReader { geo in
            let board = (geo.size.width - 32) / 4.3
            if wide {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let next = model.nextRace { LiveSessionBanner(race: next) }
                        raceTitle
                        sessionChips(now: now, selected: session)
                        lights(now: now, session: session)
                        weatherLine(session)
                    }
                    clock(now: now, session: session, size: min(geo.size.height - 36, geo.size.width * 0.42))
                }
                .padding(16)
            } else {
                // the room the rest takes: title, chips, lights, weather
                let ring = max(150, min(geo.size.width - 60, geo.size.height - 236 - board))
                VStack(spacing: 10) {
                    // the broadcast LIVE bar while a session is on track
                    if let next = model.nextRace { LiveSessionBanner(race: next) }
                    raceTitle
                    sessionChips(now: now, selected: session)
                    Spacer(minLength: 0)
                    clock(now: now, session: session, size: ring)
                    Spacer(minLength: 0)
                    lights(now: now, session: session)
                    weatherLine(session)
                }
                .padding(16)
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
            guard abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
            step(drag.translation.width < 0 ? 1 : -1)
        })
    }

    /// The round with arrows to the races either side, the season or the
    /// way back, then the race. The header's helmet hangs over the middle
    /// of the first row, as over the race card on the phone.
    private var raceTitle: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                arrow("chevron.left", enabled: (index ?? 0) > 0, label: "Previous race") { step(-1) }
                Text("ROUND \(race.roundNumber)")
                    .font(.f1(13).italic())
                    .tracking(1)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 7))
                arrow("chevron.right", enabled: (index ?? 0) < model.season.count - 1, label: "Next race") { step(1) }
                Spacer()
                if model.isBrowsing {
                    Button { onSelectRace(nil) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward").font(.system(size: 9, weight: .bold))
                            Text("NEXT RACE").font(.f1(10, weight: .bold)).tracking(1)
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accent.opacity(0.1))
                            .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to next race")
                } else {
                    Text(race.season).font(.f1(15).italic()).foregroundStyle(Theme.dimText)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(race.raceName.uppercased())
                    .font(.f1(26).italic())
                    .foregroundStyle(Theme.chromeText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(race.circuit.circuitName) · \(race.circuit.location.locality)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func arrow(_ symbol: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.accent.opacity(0.1)).overlay(Circle().strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// The countdown card's session chips: tap one to count down to it.
    private func sessionChips(now: Date, selected: WeekendSession?) -> some View {
        HStack(spacing: 6) {
            ForEach(race.sessions) { session in
                let on = session.id == selected?.id
                Button { selectedId = session.id } label: {
                    NeonChip(title: session.kind.short, tint: Self.tint(session.kind), selected: on)
                        .opacity(session.date <= now && !on ? 0.45 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(session.kind.rawValue), \(session.date.formatted(.dateTime.weekday(.wide).hour().minute()))")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    /// The ring clock, or LIVE with the session clock, or complete.
    @ViewBuilder
    private func clock(now: Date, session: WeekendSession?, size: CGFloat) -> some View {
        if let session, isLive(session, now) {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Circle().fill(Theme.live).frame(width: 12, height: 12).shadow(color: Theme.live, radius: 6)
                    Text("\(session.kind.rawValue.uppercased()) IS LIVE").font(.f1(22).italic()).foregroundStyle(.white)
                }
                SessionClock(start: session.date).font(.f1Digits(30)).foregroundStyle(Theme.chromeText)
            }
            .frame(width: size, height: size)
        } else if let session, session.date > now {
            RingClock(remaining: session.date.timeIntervalSince(now),
                      caption: "\(session.kind.rawValue.uppercased()) · \(session.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()).uppercased())",
                      hot: session.kind == .race, size: size)
        } else {
            Text("🏁 \(session?.kind.rawValue.uppercased() ?? "SESSION") COMPLETE")
                .font(.f1(20).italic())
                .foregroundStyle(Theme.dimText)
                .frame(width: size, height: size)
        }
    }

    /// The countdown card's LED board at the display's width (drawn, so it
    /// stays sharp at any size): a light a day through race week, then the
    /// session's time, date, days and round in turn.
    private func lights(now: Date, session: WeekendSession?) -> some View {
        let raceStart = race.sessions.last { $0.kind == .race }?.date
        let cal = Calendar.current
        let days = raceStart.map { cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: $0)).day ?? 99 } ?? 99
        let lit = raceStart.map { now < $0 && days <= 4 ? 5 - days : 0 } ?? 0
        var pages: [String] = []
        if let session, session.date > now {
            let left = Int(session.date.timeIntervalSince(now))
            pages = [
                session.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)),
                session.date.formatted(.dateTime.day().month(.abbreviated)).uppercased(),
                left / 86400 > 1 ? "\(left / 86400) DAYS" : left / 86400 == 1 ? "1 DAY" : "\(left % 86400 / 3600) HRS",
                "RND \(race.round)",
            ]
        }
        return VStack(spacing: 4) {
            DotMatrixBoard(litLights: lit, pages: pages, standby: lit == 0).alignedToContent()
            if lit > 0 {
                Text(days == 0 ? "RACE DAY" : days == 1 ? "LIGHTS OUT TOMORROW" : "RACE WEEK")
                    .font(.f1(11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Theme.live)
                    .shadow(color: Theme.live.opacity(0.7), radius: 6)
            }
        }
    }

    /// Where, and the weather for the session picked.
    private func weatherLine(_ session: WeekendSession?) -> some View {
        let weather = session.flatMap { WeatherAPI.point(for: $0.date, in: model.weather) }
        return HStack(spacing: 8) {
            Image(systemName: "location.fill").font(.system(size: 11)).foregroundStyle(Theme.dimText)
            Text(race.circuit.location.locality.uppercased())
                .font(.f1(12, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.dimText)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let weather {
                Text(weather.symbol).font(.system(size: 16))
                Text("\(Int(weather.temperature.rounded()))°").font(.f1Digits(17)).foregroundStyle(.white)
                Text("\(weather.precipProbability)% RAIN")
                    .font(.f1(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(weather.precipProbability >= 40 ? Theme.accent : Theme.dimText)
            }
        }
    }

    /// The circuit card, with its turns and corner guide.
    private var circuitFace: some View {
        ScrollView {
            if let map = model.trackMap {
                TrackSectionView(map: map, circuit: race.circuit, compact: true)
                    .id(race.circuit.circuitId)
            } else if model.extrasLoading {
                TrackPlaceholder()
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 14)
        .padding(.top, 70)
    }

    /// The championship in the Standings tab's rows; hidden in spoiler mode.
    private var standingsFace: some View {
        let shielded = spoilerMode && !revealed
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("CHAMPIONSHIP")
                VStack(spacing: 0) {
                    let leader = Double(standings.drivers.first?.points ?? "") ?? 0
                    ForEach(standings.drivers) { entry in
                        FullDriverRow(entry: entry, leaderPoints: leader)
                            .opensProfile(.driver(entry.id))
                        if entry.id != standings.drivers.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke, lineWidth: 1)))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .blur(radius: shielded ? 18 : 0)
                .allowsHitTesting(!shielded)
                .overlay(alignment: .top) {
                    if shielded { SpoilerShield(text: "Tap to reveal the standings").frame(height: 300) }
                }
                .contentShape(Rectangle())
                .onTapGesture { if shielded { revealed = true } }
            }
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 14)
        .padding(.top, 70)
    }

    // MARK: The other screen

    private var deck: some View {
        DuoScreen {
            DuoTitle(title: "WEEKEND",
                     subtitle: "\(Flags.emoji(for: race.circuit.location.country)) \(race.circuit.location.locality.uppercased()) · ROUND \(race.roundNumber)") {
                forecastBadge
            }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ON THE DISPLAY")
                        .font(.f1(10, weight: .bold))
                        .tracking(2.5)
                        .foregroundStyle(Theme.dimText)
                    GlowSelector(options: Show.allCases.map(\.option), selected: show.rawValue) {
                        show = Show(rawValue: $0) ?? .countdown
                    }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EmilyBar(onTap: onEmily)
                        LockScreenLine(onSettings: onSettings)
                        WeekendScheduleView(race: race, weather: model.weather, weatherLoading: model.extrasLoading,
                                            showsCountdowns: false)
                            .id(race.id)
                        extras
                    }
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var forecastBadge: some View {
        let raceSession = race.sessions.last { $0.kind == .race }
        if let forecast = raceSession.flatMap({ WeatherAPI.point(for: $0.date, in: model.weather) }) {
            VStack(spacing: 0) {
                Text(forecast.symbol).font(.system(size: 20))
                Text("\(Int(forecast.temperature.rounded()))°").font(.f1Digits(14)).foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .background(Circle().fill(Color.white.opacity(0.05))
                .overlay(Circle().strokeBorder(Theme.cardStroke, lineWidth: 1)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Race forecast \(Int(forecast.temperature.rounded())) degrees, \(forecast.precipProbability)% chance of rain")
        }
    }
}

/// What happens by itself (the server starts the Lock Screen countdown
/// before every session); tapping it opens Settings. The phone's countdown
/// card has its own; this is the iPhone Duo deck's.
struct LockScreenLine: View {
    let onSettings: () -> Void

    @State private var countdownOn = PushSync.countdownOn
    @State private var countdownHours = PushSync.countdownHours

    var body: some View {
        let tint = countdownOn ? Theme.accent : Theme.dimText
        Button(action: onSettings) {
            HStack(spacing: 6) {
                Image(systemName: countdownOn ? "lock.iphone" : "lock.slash")
                    .font(.system(size: 12, weight: .bold))
                Text(countdownOn ? "ON YOUR LOCK SCREEN \(countdownHours) H BEFORE" : "LOCK SCREEN COUNTDOWN OFF")
                    .font(.f1(12, weight: .bold))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Settings")
        // Settings may have changed while it was open.
        .onAppear { readSettings() }
        .onReceive(NotificationCenter.default.publisher(for: AppSettings.didChange)) { _ in readSettings() }
    }

    private func readSettings() {
        countdownOn = PushSync.countdownOn
        countdownHours = PushSync.countdownHours
    }
}
