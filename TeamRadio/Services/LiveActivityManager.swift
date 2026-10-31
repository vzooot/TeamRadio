import ActivityKit
import Foundation

/// Keeps the Lock Screen / Dynamic Island countdown up to date. The
/// countdown itself is started by the server, automatically, the chosen
/// hours before every session (Settings); there's no manual pin any more.
@MainActor
enum LiveActivityManager {
    /// Before 1.3.3 a session could be pinned by hand; that pin was stored
    /// as an intent and restarted the countdown in the foreground.
    private static let legacyPinKeys = ["pinnedSessionKind", "pinnedSessionDate"]

    static var isActive: Bool {
        !Activity<RaceActivityAttributes>.activities.isEmpty
    }

    /// iOS lets Live Activities be switched off per app (also by answering
    /// "Don't Allow" the first time one appears).
    static var allowedByIOS: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// The server starts each session's countdown once, when its window
    /// opens. A phone that missed that moment (a new install or update, a
    /// changed setting, a push that never arrived) gets the same countdown
    /// from the app itself, whenever it opens during the window.
    static func ensureCountdown() async {
        guard PushSync.countdownOn, allowedByIOS, !isActive,
              let race = try? await F1API.nextRace(),
              let session = countingDown(in: race, leadMinutes: PushSync.countdownHours * 60, now: .now),
              !isActive else { return }
        let end = session.date.addingTimeInterval(session.kind.expectedDuration)
        let attributes = RaceActivityAttributes(
            raceName: race.raceName,
            flag: Flags.emoji(for: race.circuit.location.country),
            sessionName: session.kind.rawValue,
            sessionShort: session.kind.short
        )
        let state = RaceActivityAttributes.ContentState(sessionDate: session.date, sessionEndDate: end, isLive: false)
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: end))
        } catch {
            NSLog("TeamRadio LiveActivity request failed: %@", String(describing: error))
        }
    }

    /// The session whose countdown runs now, the same rule as the server's:
    /// it starts `leadMinutes` before the session, or when the previous
    /// session ends if that's later.
    static func countingDown(in race: Race, leadMinutes: Int, now: Date) -> WeekendSession? {
        var previousEnd = Date.distantPast
        for session in race.sessions.sorted(by: { $0.date < $1.date }) {
            let startsAt = max(session.date.addingTimeInterval(-Double(leadMinutes) * 60), previousEnd)
            previousEnd = session.date.addingTimeInterval(session.kind.expectedDuration)
            if now >= startsAt && now < session.date { return session }
        }
        return nil
    }

    static func endAll() {
        for activity in Activity<RaceActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Called when the app comes to the foreground: flips a countdown to
    /// LIVE once its session has started and clears finished ones.
    static func refresh() {
        // an old manual pin must not start a second countdown
        legacyPinKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        let now = Date()
        for activity in Activity<RaceActivityAttributes>.activities {
            let state = activity.content.state
            if now >= state.sessionEndDate {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            } else if now >= state.sessionDate, !state.isLive {
                var updated = state
                updated.isLive = true
                Task { await activity.update(.init(state: updated, staleDate: state.sessionEndDate)) }
            } else {
                // Touch the activity so its view re-renders — this is what
                // flips the countdown from relative style to the ticking
                // timer once the session is under 24 hours away.
                Task { await activity.update(.init(state: state, staleDate: state.sessionEndDate)) }
            }
        }
        Task { await ensureCountdown() }
    }
}
