import SwiftUI

/// Full race-weekend timetable in the viewer's local timezone, with a live
/// mini-countdown on every upcoming session.
struct WeekendScheduleView: View {
    let race: Race
    var weather: [Date: WeatherPoint] = [:]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let sessions = race.sessions
            let nextId = sessions.first(where: { $0.date > now })?.id

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("RACE WEEKEND")

                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        SessionRow(
                            session: session,
                            now: now,
                            isNext: session.id == nextId,
                            weather: WeatherAPI.point(for: session.date, in: weather)
                        )
                        if session.id != sessions.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Theme.glassStroke, lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))

                Text("All times local · \(TimeZone.current.identifier)")
                    .font(.caption2)
                    .foregroundStyle(Theme.faintText)
                    .padding(.leading, 4)
            }
        }
    }
}

struct SessionRow: View {
    let session: WeekendSession
    let now: Date
    let isNext: Bool
    var weather: WeatherPoint?

    private var isLive: Bool {
        session.date <= now && now < session.date.addingTimeInterval(session.kind.expectedDuration)
    }

    private var isPast: Bool {
        !isLive && session.date <= now
    }

    /// e.g. "IN 2D 04H", "IN 3H 12M", "IN 42M"
    private var miniCountdown: String? {
        let seconds = Int(session.date.timeIntervalSince(now))
        guard seconds > 0 else { return nil }
        let d = seconds / 86400
        let h = (seconds % 86400) / 3600
        let m = (seconds % 3600) / 60
        if d > 0 { return "IN \(d)D \(String(format: "%02d", h))H" }
        if h > 0 { return "IN \(h)H \(String(format: "%02d", m))M" }
        return "IN \(max(m, 1))M"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(session.kind.short)
                .font(.f1(13).italic())
                .foregroundStyle(session.kind == .race ? .white : Theme.dimText)
                .frame(width: 46, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(session.kind == .race ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(session.kind.rawValue.uppercased())
                    .font(.f1(15, weight: .bold))
                    .foregroundStyle(isPast ? Theme.faintText : .white)
                    .strikethrough(isPast, color: Theme.faintText)
                if let weather, !isPast {
                    Text("\(weather.symbol) \(Int(weather.temperature.rounded()))° · \(weather.precipProbability)% rain")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(weather.precipProbability >= 40 ? Color(red: 0.4, green: 0.7, blue: 1.0) : Theme.dimText)
                }
            }

            if isLive {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Theme.live)
                        .frame(width: 7, height: 7)
                        .shadow(color: Theme.live, radius: 4)
                    Text("LIVE")
                        .font(.f1(10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Theme.live)
                }
            } else if let countdown = miniCountdown, isNext {
                Text(countdown)
                    .font(.f1(10, weight: .heavy).monospacedDigit())
                    .tracking(1)
                    .foregroundStyle(Theme.violet)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Theme.violet.opacity(0.65), lineWidth: 1)
                    )
            } else if let countdown = miniCountdown {
                Text(countdown)
                    .font(.f1(10, weight: .heavy).monospacedDigit())
                    .tracking(1)
                    .foregroundStyle(Theme.dimText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(session.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isPast ? Theme.faintText : Theme.dimText)
                Text(session.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(isPast ? Theme.faintText : .white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(isNext ? Theme.accent.opacity(0.08) : .clear)
        .overlay(alignment: .leading) {
            if isNext {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 3)
            }
        }
    }
}

/// Shared section heading with a red slash accent, echoing the logo.
struct SectionTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(LinearGradient(colors: [Theme.accent, Theme.violet, Theme.live],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 4, height: 18)
                .rotationEffect(.degrees(12))
            Text(text)
                .font(.f1(19).italic())
                .foregroundStyle(Theme.chromeText)
        }
    }
}
