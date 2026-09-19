import Foundation
import Observation
import UserNotifications

/// Counts paddock messages newer than the last read point, so the tab bar
/// can show an unread bubble while the user is elsewhere in the app.
@MainActor
@Observable
final class ChatBadge {
    private(set) var unread = 0
    /// Unread private messages (part of `unread`).
    private(set) var unreadDMs = 0
    /// Newest unread message, for the "new message" toast.
    private(set) var latestSender = ""
    private(set) var latestText = ""
    private(set) var latestIsPrivate = false
    @ObservationIgnored private var pushObserver: NSObjectProtocol?
    @ObservationIgnored private var round: String?
    @ObservationIgnored private var userId: String?

    private static let lastReadKey = "chatLastReadAt"
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    /// The moment the user last caught up with the room. The chat screen
    /// advances it while open; opening the Paddock tab jumps it to now.
    static var lastReadAt: Date {
        get { Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: lastReadKey)) }
        set { UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: lastReadKey) }
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.recountNow()
                try? await Task.sleep(for: .seconds(20))
            }
        }
        pushObserver = NotificationCenter.default.addObserver(forName: .chatPushReceived, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.recountNow() }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        if let pushObserver { NotificationCenter.default.removeObserver(pushObserver) }
        pushObserver = nil
    }

    private func recountNow() async {
        if round == nil, let race = try? await F1API.nextRace() {
            round = "\(race.season)-\(race.round)"
        }
        if userId == nil { userId = await ChatService.currentUserId() }
        guard let round else { return }
        await recount(round: round, userId: userId)
    }

    /// Opening the Paddock tab catches up on the room; private threads stay
    /// unread until each one is opened.
    func markRead() {
        Self.lastReadAt = .now
        unread = unreadDMs
        Self.setAppIconBadge(unread)
    }

    private func recount(round: String, userId: String?) async {
        guard let (messages, _) = try? await ChatService.messages(round: round, limit: 30) else { return }
        let lastRead = Self.lastReadAt
        let blocked = ChatModeration.blockedUsers
        let fresh = messages.filter {
            $0.date > lastRead && $0.senderId != userId && !blocked.contains($0.senderId)
        }
        if let newest = fresh.max(by: { $0.date < $1.date }) {
            latestSender = newest.sender
            latestText = newest.isGiphy ? "🎞️ GIF"
                : newest.text.isEmpty
                ? (newest.mediaType == "video" ? "🎬 Video" : "📷 Photo")
                : newest.text
        }
        var dms: [DirectMessage] = []
        if let userId, let inbox = try? await DirectMessageService.inbox(me: userId, limit: 40) {
            dms = DMReadState.unread(in: inbox, me: userId)
        }
        latestIsPrivate = false
        if let newestDM = dms.max(by: { $0.date < $1.date }),
           newestDM.date > (fresh.map(\.date).max() ?? .distantPast) {
            latestSender = newestDM.fromName
            latestText = newestDM.isGiphy ? "🎞️ GIF" : newestDM.mediaType == nil ? newestDM.text
                : newestDM.mediaType == "video" ? "🎬 Video" : "📷 Photo"
            latestIsPrivate = true
        }
        let before = unread
        unreadDMs = dms.count
        unread = fresh.count + dms.count
        if unread > before, before >= 0, !firstCount { MessageSounds.playReceived() }
        firstCount = false
        Self.setAppIconBadge(unread)
    }

    /// The red bubble on the app icon mirrors the tab badge; cleared the same
    /// moment the tab is. Needs the badge permission the inbox asks for.
    static func setAppIconBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }

    @ObservationIgnored private var firstCount = true
}
