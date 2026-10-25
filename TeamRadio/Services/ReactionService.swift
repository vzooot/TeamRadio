import CloudKit
import CryptoKit
import Foundation
import Observation

/// One person's emoji on one message, in the room or a private thread.
struct Reaction: Equatable {
    let messageId: String
    let userId: String
    let emoji: String
}

/// Emoji reactions on CloudKit's public database: one record per person per
/// message ("react-<message>-<user>"), so changing your emoji overwrites it
/// and removing it deletes it. Private-thread reactions are sealed with the
/// thread key like the messages themselves.
enum ReactionService {
    /// The long-press picker's quick row; "+" offers any emoji.
    static let quick = ["❤️", "😂", "🔥", "👍", "😮", "🏁"]

    private static var database: CKDatabase { ChatService.container.publicCloudDatabase }

    static func recordName(message: String, user: String) -> String { "react-\(message)-\(user)" }

    /// The room's reactions on these messages, by message id.
    static func room(for messageIds: [String]) async throws -> [String: [Reaction]] {
        var all: [String: [Reaction]] = [:]
        for start in stride(from: 0, to: messageIds.count, by: 100) {
            let chunk = Array(messageIds[start..<min(start + 100, messageIds.count)])
            for record in try await fetch(NSPredicate(format: "messageId IN %@", chunk)) {
                guard let reaction = parse(record, emoji: record["emoji"] as? String) else { continue }
                all[reaction.messageId, default: []].append(reaction)
            }
        }
        return all
    }

    /// A private conversation's reactions, decrypted with its key.
    static func thread(_ thread: String, key: SymmetricKey) async throws -> [String: [Reaction]] {
        var all: [String: [Reaction]] = [:]
        for record in try await fetch(NSPredicate(format: "thread == %@", thread)) {
            let emoji = (record["payload"] as? Data).flatMap { DMKeys.open($0, with: key) }
            guard let reaction = parse(record, emoji: emoji) else { continue }
            all[reaction.messageId, default: []].append(reaction)
        }
        return all
    }

    /// Sets my reaction on a message, or removes it with nil. Private
    /// threads pass their id and key.
    static func set(_ emoji: String?, on messageId: String, me: String,
                    thread: String? = nil, key: SymmetricKey? = nil) async throws {
        let id = CKRecord.ID(recordName: recordName(message: messageId, user: me))
        guard let emoji else {
            do { _ = try await database.deleteRecord(withID: id) } catch let error as CKError where error.code == .unknownItem {}
            return
        }
        let record = CKRecord(recordType: "Reaction", recordID: id)
        record["messageId"] = messageId
        record["userId"] = me
        if let thread, let key {
            record["thread"] = thread
            record["payload"] = try DMKeys.seal(emoji, with: key)
        } else {
            record["emoji"] = emoji
        }
        // Overwrites my earlier emoji without fetching it first.
        let (saved, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        if case .failure(let error) = saved[id] { throw error }
    }

    private static func fetch(_ predicate: NSPredicate) async throws -> [CKRecord] {
        let query = CKQuery(recordType: "Reaction", predicate: predicate)
        let keys = ["messageId", "userId", "emoji", "thread", "payload"]
        do {
            var (results, cursor) = try await database.records(matching: query, desiredKeys: keys, resultsLimit: 400)
            var records = results.compactMap { try? $0.1.get() }
            while let next = cursor {
                (results, cursor) = try await database.records(continuingMatchFrom: next, desiredKeys: keys, resultsLimit: 400)
                records += results.compactMap { try? $0.1.get() }
            }
            return records
        } catch let error as CKError where error.code == .unknownItem {
            return []   // record type not created yet: nobody has reacted
        }
    }

    /// Only a record named after its own message and user counts, so nobody
    /// can add a second reaction under someone else's name.
    private static func parse(_ record: CKRecord, emoji: String?) -> Reaction? {
        guard let messageId = record["messageId"] as? String,
              let userId = record["userId"] as? String,
              let emoji, !emoji.isEmpty,
              record.recordID.recordName == recordName(message: messageId, user: userId) else { return nil }
        return Reaction(messageId: messageId, userId: userId, emoji: emoji)
    }
}

/// One chip under a message: an emoji, how many chose it, and whether I did.
struct ReactionChip: Identifiable, Equatable {
    let emoji: String
    let count: Int
    let mine: Bool
    var id: String { emoji }
}

/// The reactions a screen shows, with my own taps applied straight away
/// (the server's query index can lag a few seconds behind a save).
@Observable
@MainActor
final class ReactionStore {
    private(set) var byMessage: [String: [Reaction]] = [:]
    private var pending: [String: (emoji: String?, at: Date)] = [:]
    var me: String?

    func replace(with fetched: [String: [Reaction]]) {
        byMessage = fetched
        pending = pending.filter { Date.now.timeIntervalSince($0.value.at) < 20 }
    }

    func mine(on messageId: String) -> String? {
        if let tap = pending[messageId] { return tap.emoji }
        return byMessage[messageId]?.first { $0.userId == me }?.emoji
    }

    /// Most chosen first; blocked people's reactions are left out.
    func chips(for messageId: String) -> [ReactionChip] {
        let blocked = ChatModeration.blockedUsers
        let myEmoji = mine(on: messageId)
        var list = (byMessage[messageId] ?? []).filter { $0.userId != me && !blocked.contains($0.userId) }
        if let myEmoji, let me {
            list.append(Reaction(messageId: messageId, userId: me, emoji: myEmoji))
        }
        var order: [String] = []
        var counts: [String: Int] = [:]
        for r in list {
            if counts[r.emoji] == nil { order.append(r.emoji) }
            counts[r.emoji, default: 0] += 1
        }
        return order.enumerated()
            .sorted { counts[$0.element]! != counts[$1.element]! ? counts[$0.element]! > counts[$1.element]! : $0.offset < $1.offset }
            .map { ReactionChip(emoji: $0.element, count: counts[$0.element]!, mine: $0.element == myEmoji) }
    }

    /// Picking my current emoji again removes it; anything else replaces it.
    /// Returns the new value to save.
    func toggle(_ emoji: String, on messageId: String) -> String? {
        let new = mine(on: messageId) == emoji ? nil : emoji
        pending[messageId] = (new, .now)
        return new
    }

    /// The save failed: show the server's state again.
    func revert(_ messageId: String) {
        pending[messageId] = nil
    }
}
