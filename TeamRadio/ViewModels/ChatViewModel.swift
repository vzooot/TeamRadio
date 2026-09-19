import CloudKit
import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    enum State: Equatable {
        case checking
        case needsICloud
        case ready
    }

    var state: State = .checking
    var messages: [ChatMessage] = []
    var nickname: String = UserDefaults.standard.string(forKey: "chatNickname") ?? ""
    var agreedToRules: Bool = UserDefaults.standard.bool(forKey: "chatRulesAgreed")
    var isSending = false
    var round: String = ""
    var roundTitle: String = ""
    /// Surfaced in the UI instead of failing silently.
    var errorText: String?
    /// Cursor into older history; nil once the room's beginning is reached.
    var canLoadOlder: Bool { olderCursor != nil }
    var isLoadingOlder = false

    private var olderCursor: CKQueryOperation.Cursor?
    private var hasPaginated = false

    private var currentUserId: String?
    private var pollTask: Task<Void, Never>?

    func start() async {
        guard await ChatService.accountAvailable() else {
            state = .needsICloud
            return
        }
        currentUserId = await ChatService.currentUserId()
        state = .ready

        // Reinstall / new device: restore the name this iCloud identity
        // already registered.
        if nickname.isEmpty, let profile = await ChatService.registeredProfile() {
            nickname = profile.name
            UserDefaults.standard.set(profile.name, forKey: "chatNickname")
            // They agreed to the rules when they first claimed the name.
            agreeToRules()
        }

        // Badge + banners for messages; the icon bubble needs .badge granted.
        InboxViewModel.enableNotifications()

        // Private messages: make us reachable (public key) and let CloudKit
        // push new ones to this device.
        if let me = currentUserId {
            Task.detached(priority: .utility) {
                await DirectMessageService.publishKey(me: me)
                await DirectMessageService.subscribeToInbox(me: me)
            }
        }

        // Chat room is scoped to the upcoming race weekend.
        if let race = try? await F1API.nextRace() {
            round = "\(race.season)-\(race.round)"
            roundTitle = race.raceName
        } else {
            round = "paddock"
            roundTitle = "The Paddock"
        }

        await refresh()
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                await self?.refresh()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        guard state == .ready, !round.isEmpty else { return }
        do {
            let (fetched, cursor) = try await ChatService.messages(round: round)
            // The refresh cursor only seeds pagination before the user has
            // paged back; afterwards the deeper cursor stays authoritative.
            if !hasPaginated {
                olderCursor = cursor
            }
            let blocked = ChatModeration.blockedUsers
            // Merge instead of replace, so paged-in history and local echoes
            // survive every poll.
            let fetchedIds = Set(fetched.map(\.id))
            let knownIds = Set(messages.map(\.id))
            let kept = messages.filter { !fetchedIds.contains($0.id) }
            let arrived = !messages.isEmpty && fetched.contains {
                !knownIds.contains($0.id) && $0.senderId != currentUserId && !blocked.contains($0.senderId)
            }
            messages = (fetched + kept)
                .filter { !blocked.contains($0.senderId) }
                .sorted { $0.date < $1.date }
            if arrived { MessageSounds.playReceived() }
            // Having the room open counts as catching up — keeps the tab badge quiet.
            if let newest = messages.last?.date, newest > ChatBadge.lastReadAt {
                ChatBadge.lastReadAt = newest
            }
            errorText = nil
        } catch is CancellationError {
            // A poll interrupted by navigation — not worth reporting.
        } catch let error as CKError where error.code == .operationCancelled {
            // Same: routine cancellation, next poll succeeds.
        } catch {
            errorText = "Couldn't load messages: \(error.localizedDescription)"
        }
    }

    /// Pages one batch further back into the room's history.
    func loadOlder() async {
        guard let cursor = olderCursor, !isLoadingOlder else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let (older, next) = try await ChatService.olderMessages(from: cursor)
            hasPaginated = true
            olderCursor = next
            let blocked = ChatModeration.blockedUsers
            let existingIds = Set(messages.map(\.id))
            let fresh = older.filter { !existingIds.contains($0.id) && !blocked.contains($0.senderId) }
            messages = (fresh + messages).sorted { $0.date < $1.date }
        } catch {
            errorText = "Couldn't load earlier messages: \(error.localizedDescription)"
        }
    }

    func send(_ text: String, media: (url: URL, type: String)? = nil,
              giphy: (url: URL, type: String)? = nil) async {
        let trimmed = ChatModeration.cleaned(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty || media != nil || giphy != nil, !nickname.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            let sent = try await ChatService.send(text: String(trimmed.prefix(280)), sender: nickname, round: round, media: media, giphy: giphy)
            if let media {
                ChatMediaCache.shared.seed(id: sent.id, type: media.type, url: media.url)
            }
            // Echo instantly; the next poll reconciles with the server.
            messages.append(sent)
            MessageSounds.playSent()
            errorText = nil
        } catch {
            errorText = "Message not sent: \(error.localizedDescription)"
        }
    }

    var nicknameError: String?
    var isClaimingName = false

    /// Registers the name globally (unique across all users) before adopting it.
    /// Returns true when the name is secured.
    func claimNickname(_ name: String) async -> Bool {
        let cleaned = String(ChatModeration.cleaned(name.trimmingCharacters(in: .whitespacesAndNewlines)).prefix(20))
        guard cleaned.count >= 3 else {
            nicknameError = "Name needs at least 3 characters."
            return false
        }
        isClaimingName = true
        defer { isClaimingName = false }

        // Renames are limited to one per 30 days, measured against the
        // server-side claim date so reinstalls don't reset the clock.
        if !nickname.isEmpty, cleaned.lowercased() != nickname.lowercased(),
           let profile = await ChatService.registeredProfile() {
            let cooldown: TimeInterval = 30 * 86400
            let elapsed = Date().timeIntervalSince(profile.claimedAt)
            if elapsed < cooldown {
                let daysLeft = Int(((cooldown - elapsed) / 86400).rounded(.up))
                nicknameError = "You can change your name again in \(daysLeft) day\(daysLeft == 1 ? "" : "s")."
                return false
            }
        }

        switch await ChatService.claimNickname(cleaned) {
        case .claimed:
            let previous = nickname
            if !previous.isEmpty, previous.lowercased() != cleaned.lowercased() {
                await ChatService.releaseNickname(previous)
            }
            nickname = cleaned
            UserDefaults.standard.set(cleaned, forKey: "chatNickname")
            nicknameError = nil
            return true
        case .taken:
            nicknameError = "\"\(cleaned)\" is already taken — try another."
            return false
        case .failed(let message):
            nicknameError = "Couldn't register the name: \(message)"
            return false
        }
    }

    func agreeToRules() {
        agreedToRules = true
        UserDefaults.standard.set(true, forKey: "chatRulesAgreed")
    }

    func isMine(_ message: ChatMessage) -> Bool {
        message.senderId == currentUserId
    }

    func report(_ message: ChatMessage) {
        Task { await ChatService.report(message, reason: "user report") }
        messages.removeAll { $0.id == message.id }
    }

    func block(_ message: ChatMessage) {
        ChatModeration.block(message.senderId)
        messages.removeAll { $0.senderId == message.senderId }
    }
}
