import Foundation
import Observation

/// Counts paddock messages newer than the last read point, so the tab bar
/// can show an unread bubble while the user is elsewhere in the app.
@MainActor
@Observable
final class ChatBadge {
    private(set) var unread = 0
    /// Newest unread message, for the "new message" toast.
    private(set) var latestSender = ""
    private(set) var latestText = ""

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
            var round: String?
            var userId: String?
            while !Task.isCancelled {
                if round == nil, let race = try? await F1API.nextRace() {
                    round = "\(race.season)-\(race.round)"
                    userId = await ChatService.currentUserId()
                }
                if let round {
                    await self?.recount(round: round, userId: userId)
                }
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func markRead() {
        Self.lastReadAt = .now
        unread = 0
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
            latestText = newest.text.isEmpty
                ? (newest.mediaType == "video" ? "🎬 Video" : "📷 Photo")
                : newest.text
        }
        unread = fresh.count
    }
}
