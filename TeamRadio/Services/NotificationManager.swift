import Foundation
import UserNotifications

/// Schedules local notifications ahead of every upcoming session, and
/// owns the first-launch notification prompt.
@MainActor
enum NotificationManager {
    static let enabledKey = "sessionAlertsEnabled"
    /// Minutes of warning before each session.
    static let leadTime: TimeInterval = 15 * 60
    /// iOS caps pending local notifications at 64 per app; a few stay free
    /// for the prediction game's reminders.
    private static let maxScheduled = 58

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Posted when alerts get switched on outside the settings card (the
    /// first-launch prompt), so the Countdown tab schedules them.
    static let didEnable = Notification.Name("sessionAlertsDidEnable")
    private static let promptedKey = "notificationPromptShown"

    /// Show the first-launch prompt: never shown before and the player
    /// hasn't answered the system's notification question yet.
    static func shouldPrompt() async -> Bool {
        guard !UserDefaults.standard.bool(forKey: promptedKey) else { return false }
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
    }

    /// The prompt's "Turn on alerts": asks iOS, and on yes switches session
    /// alerts on. Either way the prompt never comes back.
    static func acceptPrompt() async -> Bool {
        UserDefaults.standard.set(true, forKey: promptedKey)
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { enableByDefault() }
        return granted
    }

    static func declinePrompt() {
        UserDefaults.standard.set(true, forKey: promptedKey)
    }

    /// Session alerts are on by default once notifications are allowed;
    /// only an explicit "off" in the settings card keeps them off.
    static func adoptDefault() async {
        guard UserDefaults.standard.object(forKey: enabledKey) == nil,
              await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
        else { return }
        enableByDefault()
    }

    private static func enableByDefault() {
        UserDefaults.standard.set(true, forKey: enabledKey)
        NotificationCenter.default.post(name: didEnable, object: nil)
    }

    /// Turns alerts on (requesting permission first) or off.
    /// Returns the resulting enabled state — false when permission is denied.
    static func setEnabled(_ on: Bool, season: [Race]) async -> Bool {
        guard on else {
            UserDefaults.standard.set(false, forKey: enabledKey)
            await removeSessionAlerts()
            return false
        }

        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        UserDefaults.standard.set(granted, forKey: enabledKey)
        if granted {
            await reschedule(season: season)
        }
        return granted
    }

    /// Every session that still deserves an alert, oldest first, capped at
    /// the system's pending-notification limit.
    static func plannedAlerts(season: [Race], from now: Date = .now) -> [(race: Race, session: WeekendSession)] {
        season
            .flatMap { race in race.sessions.map { (race: race, session: $0) } }
            .filter { $0.session.date.addingTimeInterval(-leadTime) > now }
            .sorted { $0.session.date < $1.session.date }
            .prefix(maxScheduled)
            .map { $0 }
    }

    /// Replaces all pending alerts with fresh ones for every upcoming session.
    /// Called on app load so schedule changes propagate.
    static func reschedule(season: [Race]) async {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        await removeSessionAlerts()

        for item in plannedAlerts(season: season) {
            let content = UNMutableNotificationContent()
            content.title = "\(Flags.emoji(for: item.race.circuit.location.country)) \(item.race.raceName)"
            content.body = "\(item.session.kind.rawValue) starts in 15 minutes — lights on at \(item.session.date.formatted(date: .omitted, time: .shortened))."
            content.sound = .default

            let fireDate = item.session.date.addingTimeInterval(-leadTime)
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: fireDate
            )
            let request = UNNotificationRequest(
                identifier: "session-\(item.race.id)-\(item.session.id)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// Only this feature's alerts; other features keep theirs.
    private static func removeSessionAlerts() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("session-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
