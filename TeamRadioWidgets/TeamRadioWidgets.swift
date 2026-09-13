import WidgetKit
import SwiftUI

// MARK: - Minimal self-contained data layer
// The widget target is intentionally standalone: a tiny mirror of the app's
// API client, decoding only what the widget shows.

struct WidgetSession {
    let name: String
    let short: String
    let date: Date
    let duration: TimeInterval
}

struct WidgetRace {
    let raceName: String
    let locality: String
    let country: String
    let sessions: [WidgetSession]

    var flag: String { WidgetFlags.emoji(for: country) }

    /// Compact name for tight spaces: "Dutch GP".
    var shortName: String {
        raceName.replacingOccurrences(of: "Grand Prix", with: "GP")
    }
}

enum WidgetF1API {
    private struct Envelope: Decodable {
        let MRData: MR
        struct MR: Decodable { let RaceTable: Table? }
        struct Table: Decodable { let Races: [R] }
        struct R: Decodable {
            let raceName: String
            let date: String
            let time: String?
            let Circuit: C
            let FirstPractice: S?
            let SecondPractice: S?
            let ThirdPractice: S?
            let Qualifying: S?
            let Sprint: S?
            let SprintQualifying: S?
        }
        struct C: Decodable { let Location: L }
        struct L: Decodable { let locality: String; let country: String }
        struct S: Decodable { let date: String; let time: String? }
    }

    static func nextRace() async throws -> WidgetRace? {
        let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/next.json")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let race = try JSONDecoder().decode(Envelope.self, from: data)
            .MRData.RaceTable?.Races.first else { return nil }

        let formatter = ISO8601DateFormatter()
        func parse(_ s: Envelope.S?) -> Date? {
            guard let s else { return nil }
            return formatter.date(from: "\(s.date)T\(s.time ?? "00:00:00Z")")
        }

        var sessions: [WidgetSession] = []
        func add(_ name: String, _ short: String, _ s: Envelope.S?, duration: TimeInterval = 3600) {
            if let d = parse(s) { sessions.append(WidgetSession(name: name, short: short, date: d, duration: duration)) }
        }
        add("Practice 1", "FP1", race.FirstPractice)
        add("Practice 2", "FP2", race.SecondPractice)
        add("Practice 3", "FP3", race.ThirdPractice)
        add("Sprint Quali", "SQ", race.SprintQualifying)
        add("Sprint", "SPRINT", race.Sprint)
        add("Qualifying", "QUALI", race.Qualifying)
        add("Race", "RACE", Envelope.S(date: race.date, time: race.time), duration: 2 * 3600)

        return WidgetRace(
            raceName: race.raceName,
            locality: race.Circuit.Location.locality,
            country: race.Circuit.Location.country,
            sessions: sessions.sorted { $0.date < $1.date }
        )
    }
}

enum WidgetFlags {
    private static let map: [String: String] = [
        "Australia": "🇦🇺", "China": "🇨🇳", "Japan": "🇯🇵", "Bahrain": "🇧🇭",
        "Saudi Arabia": "🇸🇦", "USA": "🇺🇸", "United States": "🇺🇸", "Italy": "🇮🇹",
        "Monaco": "🇲🇨", "Canada": "🇨🇦", "Spain": "🇪🇸", "Austria": "🇦🇹",
        "UK": "🇬🇧", "United Kingdom": "🇬🇧", "Hungary": "🇭🇺", "Belgium": "🇧🇪",
        "Netherlands": "🇳🇱", "Azerbaijan": "🇦🇿", "Singapore": "🇸🇬", "Mexico": "🇲🇽",
        "Brazil": "🇧🇷", "Qatar": "🇶🇦", "UAE": "🇦🇪", "Malaysia": "🇲🇾",
    ]
    static func emoji(for country: String) -> String { map[country] ?? "🏁" }
}

// MARK: - Timeline

struct SessionEntry: TimelineEntry {
    enum State {
        case unavailable
        case upcoming(race: WidgetRace, session: WidgetSession)
        case live(race: WidgetRace, session: WidgetSession)
    }

    let date: Date
    let state: State

    static let placeholder = SessionEntry(
        date: .now,
        state: .upcoming(
            race: WidgetRace(raceName: "Dutch Grand Prix", locality: "Zandvoort", country: "Netherlands", sessions: []),
            session: WidgetSession(name: "Race", short: "RACE", date: .now.addingTimeInterval(3 * 86400), duration: 7200)
        )
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await entries().first ?? .placeholder) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        Task {
            let entries = await entries()
            // Refresh at the last computed transition, or in an hour if the
            // fetch failed, so a temporary outage heals itself.
            let refresh = entries.last.map { $0.date.addingTimeInterval(300) }
                ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: entries.isEmpty ? [SessionEntry(date: .now, state: .unavailable)] : entries,
                                policy: .after(refresh)))
        }
    }

    /// State at `now`, plus one entry per upcoming session start/end so the
    /// widget flips to LIVE and back without waking the network. Six-hourly
    /// filler entries keep day counts fresh in between.
    private func entries() async -> [SessionEntry] {
        guard let race = try? await WidgetF1API.nextRace() else { return [] }

        func state(at time: Date) -> SessionEntry.State {
            if let live = race.sessions.first(where: { $0.date <= time && time < $0.date.addingTimeInterval($0.duration) }) {
                return .live(race: race, session: live)
            }
            if let next = race.sessions.first(where: { $0.date > time }) {
                return .upcoming(race: race, session: next)
            }
            return .unavailable
        }

        let now = Date()
        var moments: [Date] = [now]
        for session in race.sessions {
            moments.append(session.date)
            moments.append(session.date.addingTimeInterval(session.duration))
        }
        var filler = now.addingTimeInterval(6 * 3600)
        let horizon = race.sessions.last?.date ?? now
        while filler < horizon {
            moments.append(filler)
            filler.addTimeInterval(6 * 3600)
        }

        return moments
            .filter { $0 >= now }
            .sorted()
            .prefix(24)
            .map { SessionEntry(date: $0, state: state(at: $0)) }
    }
}

// MARK: - Widget views

private let accent = Color(red: 0.18, green: 0.70, blue: 1.0)  // #2EB2FF — electric blue
private let liveAccent = Color(red: 0.994, green: 0.297, blue: 0.16)  // #FD4B28 — icon radio-arc red

struct TeamRadioWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SessionEntry

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: Lock screen families

    private var inline: some View {
        switch entry.state {
        case .unavailable:
            Text("🏁 Team Radio")
        case .upcoming(_, let session):
            Text("🏁 \(session.short) in ") + Text(session.date, style: .relative)
        case .live(_, let session):
            Text("🔴 \(session.short) LIVE")
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            switch entry.state {
            case .unavailable:
                Text("🏁")
            case .upcoming(let race, let session):
                VStack(spacing: 0) {
                    Text(race.flag)
                        .font(.system(size: 14))
                    Text(session.short)
                        .font(.system(size: 9, weight: .heavy))
                    Text(countdownShort(to: session.date))
                        .font(.system(size: 12, weight: .black).monospacedDigit())
                }
            case .live(let race, _):
                VStack(spacing: 1) {
                    Text(race.flag)
                        .font(.system(size: 14))
                    Text("LIVE")
                        .font(.system(size: 11, weight: .black))
                }
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            switch entry.state {
            case .unavailable:
                Text("🏁 Team Radio")
                    .font(.headline)
                Text("No upcoming race")
                    .font(.caption2)
            case .upcoming(let race, let session):
                Text("\(race.flag) \(race.shortName)")
                    .font(.system(size: 13, weight: .heavy))
                    .lineLimit(1)
                Text(session.name.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.8)
                Text(session.date, style: .relative)
                    .font(.system(size: 14, weight: .black).monospacedDigit())
            case .live(let race, let session):
                Text("\(race.flag) \(race.shortName)")
                    .font(.system(size: 13, weight: .heavy))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)
                    Text("\(session.name.uppercased()) LIVE")
                        .font(.system(size: 14, weight: .black))
                }
                Text("Ends in ") + Text(session.date.addingTimeInterval(session.duration), style: .timer)
            }
        }
    }

    // MARK: Home screen families

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch entry.state {
            case .unavailable:
                header(flag: "🏁", title: "TEAM RADIO", live: false)
                Spacer()
                Text("No upcoming race")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            case .upcoming(let race, let session):
                header(flag: race.flag, title: race.shortName.uppercased(), live: false)
                Spacer()
                Text(session.name.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Text(session.date, style: .relative)
                    .font(.system(size: 21, weight: .black, design: .default).width(.condensed).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(session.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            case .live(let race, let session):
                header(flag: race.flag, title: race.shortName.uppercased(), live: true)
                Spacer()
                Text("\(session.name.uppercased())")
                    .font(.system(size: 15, weight: .black).width(.condensed))
                    .foregroundStyle(.white)
                Text("LIVE NOW")
                    .font(.system(size: 22, weight: .black).width(.condensed))
                    .foregroundStyle(liveAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { widgetBackground }
    }

    private var medium: some View {
        HStack(alignment: .center, spacing: 14) {
            switch entry.state {
            case .unavailable:
                Text("🏁 No upcoming race")
                    .foregroundStyle(.white)
            case .upcoming(let race, let session):
                VStack(alignment: .leading, spacing: 3) {
                    header(flag: race.flag, title: race.shortName.uppercased(), live: false)
                    Text(race.locality)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.name.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                    Text(session.date, style: .relative)
                        .font(.system(size: 24, weight: .black).width(.condensed).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(session.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            case .live(let race, let session):
                VStack(alignment: .leading, spacing: 3) {
                    header(flag: race.flag, title: race.shortName.uppercased(), live: true)
                    Text(race.locality)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.name.uppercased())
                        .font(.system(size: 13, weight: .black).width(.condensed))
                        .foregroundStyle(.white)
                    Text("LIVE")
                        .font(.system(size: 26, weight: .black).width(.condensed))
                        .foregroundStyle(liveAccent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { widgetBackground }
    }

    private func header(flag: String, title: String, live: Bool) -> some View {
        HStack(spacing: 5) {
            Text(flag)
                .font(.system(size: 14))
            Text(title)
                .font(.system(size: 13, weight: .black).width(.condensed).italic())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if live {
                Circle()
                    .fill(liveAccent)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var widgetBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.035, green: 0.07, blue: 0.14), Color(red: 0.024, green: 0.043, blue: 0.09)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(accent.opacity(0.25))
                .frame(width: 110, height: 110)
                .blur(radius: 40)
                .offset(x: 30, y: -30)
        }
    }

    /// Static compact countdown for the circular face ("2d", "16h", "45m").
    private func countdownShort(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(entry.date)))
        if seconds >= 86400 { return "\(seconds / 86400)d" }
        if seconds >= 3600 { return "\(seconds / 3600)h" }
        return "\(max(seconds / 60, 1))m"
    }
}

// MARK: - Widget declaration

struct NextSessionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TeamRadioNextSession", provider: Provider()) { entry in
            TeamRadioWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Race Session")
        .description("Countdown to the next session of the upcoming race weekend.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular,
        ])
    }
}

@main
struct TeamRadioWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextSessionWidget()
        RaceLiveActivity()
    }
}
