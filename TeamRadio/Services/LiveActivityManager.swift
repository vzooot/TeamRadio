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
    }
}
