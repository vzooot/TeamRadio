import CloudKit
import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: CKRecord.ID
    let text: String
    let sender: String
    let senderId: String
    let date: Date
    /// "image" or "video" when the message carries media.
    var mediaType: String?

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool { lhs.id == rhs.id }
}

/// Race-weekend chat on CloudKit's public database: no accounts, no servers —
/// users are identified by their iCloud account.
enum ChatService {
    static let container = CKContainer(identifier: "iCloud.com.woqomoqo.OneF")
    private static var database: CKDatabase { container.publicCloudDatabase }

    static func accountAvailable() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    /// A stable, opaque id for the current user (used for blocking).
    static func currentUserId() async -> String? {
        (try? await container.userRecordID())?.recordName
    }

    /// Latest messages for one race weekend (oldest first), plus a cursor
    /// that pages further back through the room's full server-side history.
    /// Sorts on the custom `created` field — custom fields get sortable
    /// indexes automatically in the development schema; the system
    /// creationDate does not.
    static func messages(round: String, limit: Int = 80) async throws -> (messages: [ChatMessage], older: CKQueryOperation.Cursor?) {
        let query = CKQuery(
            recordType: "Message",
            predicate: NSPredicate(format: "round == %@", round)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]

        // The media asset itself is deliberately NOT fetched here — bubbles
        // download it lazily via ChatMediaCache, keeping list loads light.
        do {
            let (results, cursor) = try await database.records(
                matching: query, desiredKeys: Self.listKeys, resultsLimit: limit)
            return (parse(results), cursor)
        } catch let error as CKError where error.code == .unknownItem || error.code == .invalidArguments {
            // Record type doesn't exist yet (first ever run) — empty room.
            return ([], nil)
        }
    }

    private static let listKeys = ["text", "sender", "senderId", "round", "created", "mediaType"]

    /// Continues a previous query further back in time.
    static func olderMessages(from cursor: CKQueryOperation.Cursor, limit: Int = 80) async throws -> (messages: [ChatMessage], older: CKQueryOperation.Cursor?) {
        let (results, next) = try await database.records(
            continuingMatchFrom: cursor, desiredKeys: Self.listKeys, resultsLimit: limit)
        return (parse(results), next)
    }

    private static func parse(_ results: [(CKRecord.ID, Result<CKRecord, Error>)]) -> [ChatMessage] {
        results
            .compactMap { _, result in try? result.get() }
            .compactMap { record in
                guard let text = record["text"] as? String,
                      let sender = record["sender"] as? String,
                      let senderId = record["senderId"] as? String else { return nil }
                let date = (record["created"] as? Date) ?? record.creationDate ?? .now
                return ChatMessage(id: record.recordID, text: text, sender: sender,
                                   senderId: senderId, date: date,
                                   mediaType: record["mediaType"] as? String)
            }
            .sorted { $0.date < $1.date }
    }

    /// Returns the sent message so the UI can echo it immediately.
    /// `media` attaches a photo or video file (already compressed by the UI).
    static func send(text: String, sender: String, round: String,
                     media: (url: URL, type: String)? = nil) async throws -> ChatMessage {
        let record = CKRecord(recordType: "Message")
        let senderId = await currentUserId() ?? "unknown"
        let created = Date()
        record["text"] = text
        record["sender"] = sender
        record["round"] = round
        record["senderId"] = senderId
        record["created"] = created
        if let media {
            record["media"] = CKAsset(fileURL: media.url)
            record["mediaType"] = media.type
        }
        let saved = try await database.save(record)
        return ChatMessage(id: saved.recordID, text: text, sender: sender, senderId: senderId,
                           date: created, mediaType: media?.type)
    }

    // MARK: - Nickname registration

    enum NameClaim {
        case claimed
        case taken
        case failed(String)
    }

    /// Atomically reserves a paddock name: the record ID *is* the normalized
    /// name, and CloudKit record IDs are unique — so a second claim of the
    /// same name fails at the server, no matter who races whom.
    static func claimNickname(_ name: String) async -> NameClaim {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        let recordID = CKRecord.ID(recordName: "name-\(normalized)")
        let userId = await currentUserId() ?? "unknown"

        let record = CKRecord(recordType: "Profile", recordID: recordID)
        record["displayName"] = name
        record["ownerId"] = userId

        do {
            _ = try await database.save(record)
            return .claimed
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Name exists — fine if it's already ours.
            if let existing = try? await database.record(for: recordID),
               existing["ownerId"] as? String == userId {
                return .claimed
            }
            return .taken
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Frees a previously claimed name (best-effort, when renaming).
    static func releaseNickname(_ name: String) async {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        _ = try? await database.deleteRecord(withID: CKRecord.ID(recordName: "name-\(normalized)"))
    }

    /// The name this iCloud identity already registered and when it was
    /// claimed — restores the account after a reinstall and anchors the
    /// rename cooldown to a server-side date.
    static func registeredProfile() async -> (name: String, claimedAt: Date)? {
        guard let userId = await currentUserId() else { return nil }
        let query = CKQuery(
            recordType: "Profile",
            predicate: NSPredicate(format: "ownerId == %@", userId)
        )
        guard let (results, _) = try? await database.records(matching: query, resultsLimit: 1),
              let record = results.first.flatMap({ try? $0.1.get() }),
              let name = record["displayName"] as? String else { return nil }
        return (name, record.creationDate ?? .distantPast)
    }

    /// Files a report record the developer reviews in the CloudKit dashboard.
    static func report(_ message: ChatMessage, reason: String) async {
        let record = CKRecord(recordType: "Report")
        record["messageRecordName"] = message.id.recordName
        record["messageText"] = message.text
        record["messageSenderId"] = message.senderId
        record["reason"] = reason
        _ = try? await database.save(record)
    }
}

/// Client-side content rules: required by App Review for user-generated
/// content, and just good manners.
enum ChatModeration {
    private static let blockedWordsKey = "chatBlockedUsers"

    private static let profanity: [String] = [
        "fuck", "shit", "bitch", "cunt", "asshole", "faggot", "nigger", "nigga",
        "retard", "whore", "slut", "wanker", "dickhead",
    ]

    /// Masks profane fragments rather than refusing the message.
    static func cleaned(_ text: String) -> String {
        var result = text
        for word in profanity {
            while let range = result.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) {
                result.replaceSubrange(range, with: String(repeating: "•", count: word.count))
            }
        }
        return result
    }

    static var blockedUsers: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: blockedWordsKey) ?? [])
    }

    static func block(_ senderId: String) {
        var users = blockedUsers
        users.insert(senderId)
        UserDefaults.standard.set(Array(users), forKey: blockedWordsKey)
    }
}
