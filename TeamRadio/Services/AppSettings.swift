import CloudKit
import Foundation
import UserNotifications

/// What the Settings screen controls. Set once; from then on every race
/// weekend just happens (approved draft C, build/mockups/settings-drafts.png).
///
/// Notifications has one main switch over everything Team Radio sends:
/// session alerts, picks reminders, the server's news, and Paddock and
/// private-message pushes. Each of those also has its own switch.
@MainActor
enum AppSettings {
    /// Posted after any change, so open screens (the countdown card's
    /// status line) show the new state.
    static let didChange = Notification.Name("appSettingsDidChange")

    private static let notificationsKey = "notificationsOn"
    private static let picksKey = "picksRemindersOn"
    private static let newsKey = "newsOn"

    /// The main switch. On unless the player turned it off.
    static var notificationsOn: Bool {
        get { UserDefaults.standard.object(forKey: notificationsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: notificationsKey) }
    }

    static var picksReminders: Bool {
        get { UserDefaults.standard.object(forKey: picksKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: picksKey) }
    }

    /// The server's announcements ("Picks are open", "Results are in").
    static var news: Bool {
        get { UserDefaults.standard.object(forKey: newsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: newsKey) }
    }

    /// Turns the main switch on (asking iOS for permission when needed) or
    /// off, and applies it everywhere. Returns the resulting state: false
    /// when iOS permission was refused.
    static func setNotifications(_ on: Bool) async -> Bool {
        if on {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            if status == .notDetermined {
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                if !granted { return false }
            } else if status == .denied {
                return false
            }
        }
        notificationsOn = on
        await applyNotifications()
        return on
    }

    /// Brings every kind of notification in line with the switches: local
    /// alerts and reminders, the server's announcement list, and the
    /// CloudKit chat subscriptions.
    static func applyNotifications() async {
        if notificationsOn {
            // the Countdown tab reschedules session alerts for the season
            NotificationCenter.default.post(name: NotificationManager.didEnable, object: nil)
        } else {
            await NotificationManager.removeAll()
        }
        if !notificationsOn || !picksReminders { await GameReminders.removeAll() }
        await PushSync.syncAnnouncements()
        await syncChatPushes()
    }

    /// Room and private-message pushes follow the main switch (the room
    /// also has its own).
    static func syncChatPushes() async {
        guard let me = await ChatService.currentUserId() else { return }
        await ChatService.subscribeToRoom(me: me)
        await DirectMessageService.subscribeToInbox(me: me)
    }
}
