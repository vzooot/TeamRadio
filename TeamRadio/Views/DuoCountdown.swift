import SwiftUI

/// The iPhone Duo's Countdown tab as two screens. The left one is a display:
/// a framed screen with bright corners that shows the race and its countdown
/// big, or whatever the deck puts on it (the circuit, the start lights, the
/// standings). The right one is the deck: panels that pick what the display
/// shows, Ask Emily, the weekend's sessions round a ring clock, the
/// championship, then the rest of the weekend. One panel shape throughout:
/// a cut corner, a thin edge, a lit bar on the side.
struct DuoCountdown<Extras: View>: View {
    enum Show: String, CaseIterable {
        case countdown = "COUNTDOWN", circuit = "CIRCUIT", lights = "LIGHTS", standings = "STANDINGS"

        var symbol: String {
            switch self {
            case .countdown: "timer"
            case .circuit: "point.topleft.down.to.point.bottomright.curvepath"
            case .lights: "circle.grid.3x3"
            case .standings: "trophy"
            }
        }
    }

    let halves: Halves
    let race: Race
    let model: RaceViewModel
    let standings: StandingsViewModel
    let onSettings: () -> Void
    let onEmily: () -> Void
    /// Set while browsing another round: back to the next race.
    let onBack: (() -> Void)?
    @ViewBuilder let extras: Extras

    @State private var show: Show = .countdown
    /// The session the countdown runs to (picked in the deck; nil = the next one).
    @State private var selectedId: String?
    @AppStorage("spoilerMode") private var spoilerMode = false

    var body: some View {
        Group {
            if halves.axis == .horizontal {
                DuoSideBySide(fold: halves.fold) {
                    display
                } right: {
                    deck(wide: false)
                }
            } else {
                // standing like a laptop: the display on top, the deck below
                GeometryReader { geo in
                    let first = max(0, halves.fold - 14)
                    VStack(spacing: 28) {
                        display.frame(height: first)
                        deck(wide: true).frame(height: max(0, geo.size.height - 8 - 28 - first))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .onChange(of: race.id) { _, _ in selectedId = nil }
    }

    // MARK: Sessions

    private func target(now: Date) -> WeekendSession? {
        if let selectedId, let chosen = race.sessions.first(where: { $0.id == selectedId }) { return chosen }
        if let live = race.sessions.first(where: { $0.date <= now && now < $0.date.addingTimeInterval($0.kind.expectedDuration) }) {
            return live
        }
        return race.sessions.first { $0.date > now } ?? race.sessions.last
    }

    private static func tint(_ kind: WeekendSession.Kind) -> Color {
        switch kind {
        case .practice1, .practice2, .practice3: Theme.accent
        case .sprintQualifying, .qualifying: Theme.violet
        case .sprint, .race: Theme.live
        }
    }

    // MARK: The display

    private var display: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            Group {
                switch show {
                case .countdown: countdownFace(now: now)
                case .circuit: circuitFace
                case .lights: lightsFace(now: now)
                case .standings: standingsFace
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .duoDisplay(flag: Flags.emoji(for: race.circuit.location.country))
        .overlay(alignment: .bottom) {
            Text("TEAM RADIO  //  \(show.rawValue)")
                .font(.f1(10, weight: .bold))
                .tracking(3)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.background))
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1))
                .offset(y: 12)
        }
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.25), value: show)
    }

    /// The race and its countdown, big, the helmet rising out of the corner.
    private func countdownFace(now: Date) -> some View {
        let session = target(now: now)
        let remaining = max(0, session.map { $0.date.timeIntervalSince(now) } ?? 0)
        let live = session.map { $0.date <= now && now < $0.date.addingTimeInterval($0.kind.expectedDuration) } ?? false
        let weather = session.flatMap { WeatherAPI.point(for: $0.date, in: model.weather) }
        return ZStack(alignment: .topLeading) {
            Image("HeaderHelmet")
                .resizable()
                .scaledToFit()
                .frame(width: 300)
                .background(
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.35)).frame(width: 220).offset(x: -50, y: 10).blur(radius: 50)
                        Circle().fill(Theme.live.opacity(0.3)).frame(width: 180).offset(x: 70).blur(radius: 46)
                    }
                )
                .shadow(color: Theme.accent.opacity(0.4), radius: 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 56, y: 24)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                Text(now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                    .font(.f1(13, weight: .semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.dimText)
                HStack(spacing: 8) {
                    Text("ROUND \(race.roundNumber)")
                        .font(.f1(12).italic())
                        .tracking(1)
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 6))
                    if let onBack {
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward").font(.system(size: 9, weight: .bold))
                                Text("NEXT RACE").font(.f1(10, weight: .bold)).tracking(1)
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to next race")
                    }
                }
                Text(race.raceName.uppercased())
                    .font(.f1(26).italic())
                    .foregroundStyle(Theme.chromeText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if live, let session {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Circle().fill(Theme.live).frame(width: 12, height: 12).shadow(color: Theme.live, radius: 6)
                            Text("LIVE").font(.f1Digits(64)).foregroundStyle(Theme.live).shadow(color: Theme.live.opacity(0.6), radius: 12)
                        }
                        SessionClock(start: session.date)
                            .font(.f1Digits(28))
                            .foregroundStyle(Theme.chromeText)
                    }
                    .padding(.top, 6)
                } else {
                    bigClock(remaining)
                        .padding(.top, 6)
                }
                if let session {
                    Text("\(live ? "ON TRACK" : "NEXT")  ·  \(session.kind.rawValue.uppercased())  ·  \(session.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()).uppercased())")
                        .font(.f1(13, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(session.kind == .race ? Theme.live : Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                // the start lights, drawn (not an image), so any size stays sharp
                startLights(now: now, session: session, remaining: remaining)
                    .padding(.top, 10)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Image(systemName: "location.fill").font(.system(size: 11))
                    Text(race.circuit.location.locality.uppercased()).font(.f1(12, weight: .bold)).tracking(3)
                }
                .foregroundStyle(Theme.dimText)
                if let weather {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(weather.symbol).font(.system(size: 30))
                        Text("\(Int(weather.temperature.rounded()))°").font(.f1Digits(44)).foregroundStyle(Theme.chromeText)
                    }
                    Text("\(weather.precipProbability)% CHANCE OF RAIN")
                        .font(.f1(12, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(weather.precipProbability >= 40 ? Theme.accent : Theme.dimText)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
    }

    /// The countdown card's LED board at the display's width: a light a day
    /// through race week, then the session's time, date and days in turn.
    private func startLights(now: Date, session: WeekendSession?, remaining: TimeInterval) -> some View {
        let raceStart = race.sessions.last { $0.kind == .race }?.date
        let cal = Calendar.current
        let days = raceStart.map { cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: $0)).day ?? 99 } ?? 99
        let lit = raceStart.map { now < $0 && days <= 4 ? 5 - days : 0 } ?? 0
        var pages: [String] = []
        if let session, remaining > 0 {
            let left = Int(remaining)
            pages = [
                session.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)),
                session.date.formatted(.dateTime.day().month(.abbreviated)).uppercased(),
                left / 86400 > 1 ? "\(left / 86400) DAYS" : left / 86400 == 1 ? "1 DAY" : "\(left % 86400 / 3600) HRS",
                "RND \(race.round)",
            ]
        }
        return DotMatrixBoard(litLights: lit, pages: pages, standby: lit == 0).alignedToContent()
    }

    /// "4 DAYS" over the hours, minutes and seconds in rolling chrome digits.
    private func bigClock(_ remaining: TimeInterval) -> some View {
        let total = Int(remaining)
        let days = total / 86400
        let time = String(format: "%02d:%02d:%02d", total % 86400 / 3600, total % 3600 / 60, total % 60)
        return VStack(alignment: .leading, spacing: 0) {
            Text(days > 0 ? "\(days) DAY\(days == 1 ? "" : "S")  +" : "T–")
                .font(.f1(14, weight: .bold))
                .tracking(3)
                .foregroundStyle(Theme.accent)
            HStack(spacing: 0) {
                ForEach(Array(time.enumerated()), id: \.offset) { _, character in
                    if character == ":" {
                        Text(":").font(.f1Digits(68)).foregroundStyle(Theme.chromeText)
                    } else {
                        RollingDigit(digit: character, hot: false, rolls: true, size: 68)
                    }
                }
            }
            .animation(.snappy(duration: 0.3), value: total)
            .shadow(color: Theme.accent.opacity(0.45), radius: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days) days and \(time) to go")
    }

    /// The 3D circuit with its numbers.
    @ViewBuilder
    private var circuitFace: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THE CIRCUIT").font(.f1(12, weight: .bold)).tracking(3).foregroundStyle(Theme.accent)
            Text(race.circuit.circuitName.uppercased())
                .font(.f1(20).italic())
                .foregroundStyle(Theme.chromeText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if let map = model.trackMap {
                HStack(spacing: 0) {
                    stat(String(format: "%.2f", map.lengthKm), "KM")
                    stat("\(map.corners.count)", "TURNS")
                    stat(map.isClockwise ? "CW" : "ACW", "DIRECTION")
                    if let pit = map.pitLossSeconds { stat(String(format: "%.0fs", pit), "PIT LOSS") }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 30)
        .background(alignment: .top) {
            if let map = model.trackMap {
                Track3DView(map: map)
                    .frame(height: TrackSceneBuilder.framed + TrackSceneBuilder.bleed)
                    .padding(.top, 70)
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.6),
                                                 .init(color: .clear, location: 0.95)],
                                         startPoint: .top, endPoint: .bottom))
            } else if model.extrasLoading {
                ProgressView().tint(Theme.accent).padding(.top, 200)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.f1Digits(20)).foregroundStyle(.white)
            Text(label).font(.f1(9, weight: .bold)).tracking(2).foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
    }

    /// The countdown card's own instruments, big: the start lights and the tiles.
    private func lightsFace(now: Date) -> some View {
        let session = target(now: now)
        let remaining = max(0, session.map { $0.date.timeIntervalSince(now) } ?? 0)
        let raceStart = race.sessions.last { $0.kind == .race }?.date
        let days = raceStart.map { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now),
                                                                   to: Calendar.current.startOfDay(for: $0)).day ?? 99 } ?? 99
        let lit = raceStart.map { now < $0 && days <= 4 ? 5 - days : 0 } ?? 0
        let total = Int(remaining)
        return VStack(spacing: 18) {
            Text("START LIGHTS").font(.f1(12, weight: .bold)).tracking(3).foregroundStyle(Theme.live)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            DotMatrixBoard(litLights: lit, standby: lit == 0).alignedToContent()
            Text(lit == 5 ? "RACE DAY" : lit > 0 ? "RACE WEEK" : "\(days) DAYS TO THE RACE")
                .font(.f1(13, weight: .bold)).tracking(4).foregroundStyle(Theme.live)
                .shadow(color: Theme.live.opacity(0.7), radius: 6)
            HStack(spacing: 10) {
                NeonTile(value: total / 86400, label: "DAYS")
                NeonTile(value: total % 86400 / 3600, label: "HRS")
                NeonTile(value: total % 3600 / 60, label: "MIN")
                NeonTile(value: total % 60, label: "SEC", hot: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 30)
    }

    /// The championship, in the Standings tab's rows.
    private var standingsFace: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHAMPIONSHIP").font(.f1(12, weight: .bold)).tracking(3).foregroundStyle(Theme.accent)
            ScrollView {
                VStack(spacing: 0) {
                    let leader = Double(standings.drivers.first?.points ?? "") ?? 0
                    ForEach(standings.drivers) { entry in
                        FullDriverRow(entry: entry, leaderPoints: leader)
                            .opensProfile(.driver(entry.id))
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
                .blur(radius: spoilerMode ? 16 : 0)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 12)
        .padding(.top, 22)
        .padding(.bottom, 30)
    }

    // MARK: The deck

    private func deck(wide: Bool) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image("HeaderWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 26)
                    .blendMode(.screen)
                    .accessibilityLabel("Team Radio")
                Spacer()
                Button(action: onSettings) { CockpitButton() }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
            }
            showPanel
            ScrollView {
                Group {
                    if wide {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(spacing: 10) { emilyPanel; championshipPanel }
                            weekendPanel
                        }
                    } else {
                        VStack(spacing: 10) {
                            emilyPanel
                            weekendPanel
                            championshipPanel
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 18) {
                    extras
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// What the display shows.
    private var showPanel: some View {
        HStack(spacing: 6) {
            ForEach(Show.allCases, id: \.self) { candidate in
                let on = show == candidate
                Button { show = candidate } label: {
                    VStack(spacing: 6) {
                        Image(systemName: candidate.symbol).font(.system(size: 17, weight: .semibold))
                        Text(candidate.rawValue).font(.f1(8.5, weight: .bold)).tracking(1).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(on ? Color.white : Theme.dimText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DeckShape(cut: 8).fill(on ? Theme.accent.opacity(0.16) : Color.white.opacity(0.03)))
                    .overlay(DeckShape(cut: 8).stroke(on ? Theme.accent : Color.white.opacity(0.1), lineWidth: on ? 1.5 : 1))
                    .shadow(color: on ? Theme.accent.opacity(0.5) : .clear, radius: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(candidate.rawValue.lowercased()) on the left")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .deckPanel("SHOW ON LEFT")
    }

    private var emilyPanel: some View {
        Button(action: onEmily) {
            HStack(spacing: 12) {
                Color.clear
                    .overlay(Image("EmilyAvatar").resizable().scaledToFill())
                    .frame(width: 56, height: 56)
                    .clipShape(DeckShape(cut: 10))
                    .overlay(DeckShape(cut: 10).stroke(Theme.violet, lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ASK EMILY").font(.f1(17).italic()).foregroundStyle(Theme.chromeText)
                    Text("AI race engineer").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.dimText)
                    RadioWave().frame(height: 16)
                }
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.accentGradient))
                    .shadow(color: Theme.accent.opacity(0.6), radius: 8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask Emily, AI race engineer")
        .deckPanel("TEAM RADIO", bar: Theme.violet)
    }

    /// The weekend round a ring clock: tap a session to count down to it.
    private var weekendPanel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let session = target(now: now)
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    RingClock(remaining: max(0, session.map { $0.date.timeIntervalSince(now) } ?? 0),
                              caption: session?.kind.short ?? "", hot: session?.kind == .race, size: 132)
                    VStack(spacing: 5) {
                        ForEach(race.sessions) { item in
                            let on = item.id == session?.id
                            Button { selectedId = item.id } label: {
                                HStack(spacing: 8) {
                                    Text(item.kind.short)
                                        .font(.f1(13).italic())
                                        .foregroundStyle(on ? Color.white : Self.tint(item.kind))
                                        .frame(width: 40, alignment: .leading)
                                    Spacer(minLength: 2)
                                    Text(item.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()).uppercased())
                                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(on ? Color.white : Theme.dimText)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DeckShape(cut: 6).fill(on ? Self.tint(item.kind).opacity(0.18) : Color.white.opacity(0.03)))
                                .overlay(DeckShape(cut: 6).stroke(on ? Self.tint(item.kind) : Color.white.opacity(0.08), lineWidth: on ? 1.4 : 1))
                                .opacity(item.date.addingTimeInterval(item.kind.expectedDuration) <= now && !on ? 0.45 : 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.kind.rawValue), \(item.date.formatted(.dateTime.weekday(.wide).hour().minute()))")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                LockScreenLine(onSettings: onSettings)
            }
        }
        .deckPanel("THIS WEEKEND", bar: Theme.accent)
    }

    /// The top three, tap one for the driver's profile.
    private var championshipPanel: some View {
        let top = Array(standings.drivers.prefix(3))
        let leader = Double(top.first?.points ?? "") ?? 0
        return VStack(spacing: 6) {
            ForEach(top) { entry in
                let points = Double(entry.points) ?? 0
                HStack(spacing: 8) {
                    Text(entry.position).font(.f1Digits(15)).foregroundStyle(entry.position == "1" ? Theme.accent : .white)
                        .frame(width: 16)
                    RoundedRectangle(cornerRadius: 1.5).fill(Theme.teamColor(entry.teamId)).frame(width: 3, height: 20)
                    Text(entry.driver.shortCode).font(.f1(15).italic()).foregroundStyle(.white)
                    Text(entry.driver.familyName).font(.system(size: 12)).foregroundStyle(Theme.dimText).lineLimit(1)
                    Spacer(minLength: 4)
                    if entry.position != "1" {
                        Text("-\(Int(leader - points))").font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.faintText)
                    }
                    Text(entry.points).font(.f1Digits(14)).foregroundStyle(entry.position == "1" ? Theme.accent : .white)
                }
                .contentShape(Rectangle())
                .opensProfile(.driver(entry.id))
            }
        }
        .blur(radius: spoilerMode ? 10 : 0)
        .deckPanel("CHAMPIONSHIP", bar: Theme.live)
    }
}

/// The deck's panel shape: a rectangle with its top-trailing corner cut.
struct DeckShape: Shape {
    var cut: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

extension View {
    /// A deck panel: dark glass in the cut-corner shape, a thin accent edge,
    /// an optional lit bar down the leading side, a label on top.
    func deckPanel(_ label: String, bar: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.f1(10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(Theme.dimText)
            self
        }
        .padding(14)
        .padding(.leading, bar == nil ? 0 : 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DeckShape().fill(LinearGradient(colors: [Color(white: 0.075), Color(white: 0.03)], startPoint: .top, endPoint: .bottom)))
        .overlay(DeckShape().stroke(Theme.accent.opacity(0.22), lineWidth: 1))
        .overlay(alignment: .leading) {
            if let bar {
                Rectangle()
                    .fill(bar)
                    .frame(width: 3)
                    .padding(.vertical, 14)
                    .shadow(color: bar.opacity(0.9), radius: 5)
            }
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
