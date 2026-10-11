import Foundation
import UserNotifications

/// Local reminders for the prediction game, only while picks are missing:
/// two days before qualifying ("picks are open"), three hours before
/// qualifying, and one hour before the race for the podium picks.
/// Rescheduled on every load and after every save; they never need a server.
@MainActor
enum GameReminders {
    private static let prefix = "game-"

    static func reschedule(race: Race?, saved: Set<PickGroup>, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard let race, await center.notificationSettings().authorizationStatus == .authorized else { return }
        let flag = Flags.emoji(for: race.circuit.location.country)
        let name = race.raceName

        var items: [(id: String, date: Date, title: String, body: String)] = []
        if !saved.contains(.quali), let quali = GameRules.lockDate(for: race, group: .quali) {
            items.append(("open", quali.addingTimeInterval(-2 * 86400),
                          "\(flag) Picks are open", "Call pole, the podium and fastest lap for the \(name). Can you beat the AI Strategist?"))
            items.append(("quali-3h", quali.addingTimeInterval(-3 * 3600),
                          "\(flag) 3 hours to lock your pole pick", "Pole locks when qualifying starts. Make your picks for the \(name)."))
        }
        if !saved.contains(.race), let start = GameRules.lockDate(for: race, group: .race) {
            items.append(("race-1h", start.addingTimeInterval(-3600),
                          "\(flag) Podium picks lock in 1 hour", "Lights out soon. Lock in your podium, fastest lap and wildcard."))
        }

        for item in items where item.date > now {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let request = UNNotificationRequest(identifier: "\(prefix)\(race.id)-\(item.id)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }
}
