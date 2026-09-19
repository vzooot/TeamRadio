import CryptoKit
import Foundation
import Observation
import UIKit
import UserNotifications

/// The private-message inbox: one row per conversation.
@Observable
@MainActor
final class InboxViewModel {
    struct Thread: Identifiable {
        let id: String
        let otherId: String
        let otherName: String
        let last: DirectMessage
        let unread: Int
    }

    var threads: [Thread] = []
    var errorText: String?
    private(set) var me = ""
    private(set) var isLoading = false

    var totalUnread: Int { threads.reduce(0) { $0 + $1.unread } }

    func load() async {
        guard let id = await ChatService.currentUserId() else { return }
        me = id
        isLoading = threads.isEmpty
        defer { isLoading = false }
        do {
            let messages = try await DirectMessageService.inbox(me: me)
            let blocked = ChatModeration.blockedUsers
            var byThread: [String: [DirectMessage]] = [:]
            for m in messages where !blocked.contains(m.other(than: me).id) {
                byThread[m.thread, default: []].append(m)
            }
            threads = byThread.compactMap { thread, list in
                guard let last = list.max(by: { $0.date < $1.date }) else { return nil }
                let other = last.other(than: me)
                return Thread(id: thread, otherId: other.id, otherName: other.name, last: last,
                              unread: DMReadState.unread(in: list, me: me).count)
            }
            .sorted { $0.last.date > $1.last.date }
            errorText = nil
        } catch {
            errorText = "Couldn't load messages: \(error.localizedDescription)"
        }
    }

    /// Private messages arrive as CloudKit pushes; ask once, when the inbox
    /// is first opened, and make sure the device is registered for them.
    static func enableNotifications() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
}

/// One conversation, polled while open.
@Observable
@MainActor
final class ThreadViewModel {
    let me: String
    let myName: String
    let otherId: String
    let otherName: String
    var messages: [DirectMessage] = []
    var isSending = false
    var errorText: String?

    private var pollTask: Task<Void, Never>?
    var thread: String { DirectMessageService.threadId(me, otherId) }

    init(me: String, myName: String, otherId: String, otherName: String) {
        self.me = me
        self.myName = myName
        self.otherId = otherId
        self.otherName = otherName
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        do {
            let fetched = try await DirectMessageService.thread(me: me, other: otherId)
            let ids = Set(fetched.map(\.id))
            let known = Set(messages.map(\.id))
            let arrived = !messages.isEmpty && fetched.contains { !known.contains($0.id) && $0.fromId != me }
            messages = (fetched + messages.filter { !ids.contains($0.id) }).sorted { $0.date < $1.date }
            DMReadState.markRead(thread)
            NotificationCenter.default.post(name: .chatPushReceived, object: nil)   // recount badges now
            if arrived { MessageSounds.playReceived() }
            errorText = nil
        } catch is CancellationError {
        } catch {
            errorText = "Couldn't load the conversation: \(error.localizedDescription)"
        }
    }

    func send(_ text: String, media: (url: URL, type: String)? = nil,
              giphy: (url: URL, type: String)? = nil) async {
        let trimmed = ChatModeration.cleaned(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty || media != nil || giphy != nil else { return }
        isSending = true
        defer { isSending = false }
        do {
            let sent = try await DirectMessageService.send(text: String(trimmed.prefix(500)), from: me, myName: myName,
                                                           to: otherId, otherName: otherName, media: media, giphy: giphy)
            if let media {
                ChatMediaCache.shared.seed(id: sent.id, type: media.type, url: media.url)
            }
            messages.append(sent)
            MessageSounds.playSent()
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Turns a stored (encrypted) attachment into its real bytes.
    private var key: SymmetricKey?
    func decryptor() async -> (@Sendable (Data) -> Data?)? {
        if key == nil { key = await DirectMessageService.threadKey(me: me, other: otherId) }
        guard let key else { return nil }
        return { DMKeys.openData($0, with: key) }
    }

    func report(_ message: DirectMessage) {
        Task { await DirectMessageService.report(message, reason: "user report (private message)") }
        messages.removeAll { $0.id == message.id }
    }
}
