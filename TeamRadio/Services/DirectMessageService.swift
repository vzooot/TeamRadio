import CloudKit
import CryptoKit
import Foundation
import Security

/// One private message between two paddock members. The text travels as an
/// AES-GCM box that only the two participants can open (see `DMKeys`).
struct DirectMessage: Identifiable, Equatable {
    let id: CKRecord.ID
    let thread: String
    let fromId: String
    let toId: String
    let fromName: String
    let toName: String
    let date: Date
    /// Decrypted text (a GIPHY URL for GIFs), or a lock notice when this
    /// device lacks the key.
    let text: String
    let readable: Bool
    /// "image" / "video" (encrypted CloudKit asset) or "gif" / "gifsticker".
    var mediaType: String?

    var isGiphy: Bool { mediaType == "gif" || mediaType == "gifsticker" }

    static func == (lhs: DirectMessage, rhs: DirectMessage) -> Bool { lhs.id == rhs.id }

    func other(than me: String) -> (id: String, name: String) {
        fromId == me ? (toId, toName) : (fromId, fromName)
    }
}

/// This device's Curve25519 key pair. The private half lives in the keychain
/// (synchronised through iCloud Keychain when the user has it on, so a new
/// phone can still read old threads); the public half is published to
/// CloudKit so anyone can encrypt a message to us.
enum DMKeys {
    private static let service = "com.woqomoqo.OneF.dm"
    private static let account = "curve25519"
    private static var cached: Curve25519.KeyAgreement.PrivateKey?

    static var privateKey: Curve25519.KeyAgreement.PrivateKey {
        if let cached { return cached }
        if let raw = load(), let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) {
            cached = key
            return key
        }
        let key = Curve25519.KeyAgreement.PrivateKey()
        save(key.rawRepresentation)
        cached = key
        return key
    }

    static var publicKeyData: Data { privateKey.publicKey.rawRepresentation }

    /// Both ends derive the same symmetric key from X25519 + HKDF; the thread
    /// id salts it so every conversation has its own key.
    static func sharedKey(with otherPublicKey: Data, thread: String) throws -> SymmetricKey {
        let theirs = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: otherPublicKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: theirs)
        return secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(thread.utf8),
                                              sharedInfo: Data("teamradio-dm-v1".utf8), outputByteCount: 32)
    }

    static func seal(_ data: Data, with key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key).combined else { throw DMError.encryption }
        return combined
    }

    static func seal(_ text: String, with key: SymmetricKey) throws -> Data {
        try seal(Data(text.utf8), with: key)
    }

    static func openData(_ payload: Data, with key: SymmetricKey) -> Data? {
        guard let box = try? AES.GCM.SealedBox(combined: payload) else { return nil }
        return try? AES.GCM.open(box, using: key)
    }

    static func open(_ payload: Data, with key: SymmetricKey) -> String? {
        guard let plain = openData(payload, with: key) else { return nil }
        return String(data: plain, encoding: .utf8)
    }

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: kSecAttrSynchronizableAny]
    }

    private static func load() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func save(_ raw: Data) {
        SecItemDelete(baseQuery as CFDictionary)
        var attrs = baseQuery
        attrs[kSecAttrSynchronizable as String] = true
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        attrs[kSecValueData as String] = raw
        SecItemAdd(attrs as CFDictionary, nil)
    }
}

enum DMError: LocalizedError {
    case noKey
    case encryption

    var errorDescription: String? {
        switch self {
        case .noKey: "They haven't opened the paddock on a recent version yet, so there's no key to write to."
        case .encryption: "Couldn't encrypt the message."
        }
    }
}

/// Private messages on CloudKit's public database. Records are readable by
/// anyone (that's what the public database is), so the text is encrypted
/// end-to-end; only the sender and recipient names and ids are in the clear.
enum DirectMessageService {
    private static var database: CKDatabase { ChatService.container.publicCloudDatabase }
    private static var keyCache: [String: Data] = [:]

    static func threadId(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "|")
    }

    /// Publishes (or refreshes) this device's public key. Idempotent.
    static func publishKey(me: String) async {
        let id = CKRecord.ID(recordName: "key-\(me)")
        let record = (try? await database.record(for: id)) ?? CKRecord(recordType: "DMKey", recordID: id)
        if record["publicKey"] as? Data == DMKeys.publicKeyData { return }
        record["ownerId"] = me
        record["publicKey"] = DMKeys.publicKeyData
        _ = try? await database.save(record)
    }

    static func publicKey(of userId: String) async -> Data? {
        if let cached = keyCache[userId] { return cached }
        guard let record = try? await database.record(for: CKRecord.ID(recordName: "key-\(userId)")),
              let data = record["publicKey"] as? Data else { return nil }
        keyCache[userId] = data
        return data
    }

    /// The symmetric key for a conversation, if the other side has published a key.
    static func threadKey(me: String, other: String) async -> SymmetricKey? {
        guard let theirKey = await publicKey(of: other) else { return nil }
        return try? DMKeys.sharedKey(with: theirKey, thread: threadId(me, other))
    }

    /// Text, a photo/video (encrypted with the thread key before upload), or a GIF link.
    static func send(text: String, from me: String, myName: String, to other: String, otherName: String,
                     media: (url: URL, type: String)? = nil,
                     giphy: (url: URL, type: String)? = nil) async throws -> DirectMessage {
        guard let key = await threadKey(me: me, other: other) else { throw DMError.noKey }
        let thread = threadId(me, other)
        let record = CKRecord(recordType: "DirectMessage")
        let created = Date()
        let body = giphy?.url.absoluteString ?? text
        record["thread"] = thread
        record["fromId"] = me
        record["toId"] = other
        record["fromName"] = myName
        record["toName"] = otherName
        record["created"] = created
        record["payload"] = try DMKeys.seal(body, with: key)
        if let media {
            let sealed = try DMKeys.seal(try Data(contentsOf: media.url), with: key)
            let sealedURL = FileManager.default.temporaryDirectory.appendingPathComponent("dm-\(UUID().uuidString).bin")
            try sealed.write(to: sealedURL)
            record["media"] = CKAsset(fileURL: sealedURL)
            record["mediaType"] = media.type
        }
        if let giphy {
            record["mediaType"] = giphy.type
        }
        let saved = try await database.save(record)
        return DirectMessage(id: saved.recordID, thread: thread, fromId: me, toId: other,
                             fromName: myName, toName: otherName, date: created, text: body, readable: true,
                             mediaType: giphy?.type ?? media?.type)
    }

    /// Everything sent to or by me, newest first. Two queries: CloudKit's OR
    /// support is not something to build an inbox on.
    static func inbox(me: String, limit: Int = 100) async throws -> [DirectMessage] {
        async let incoming = fetch(NSPredicate(format: "toId == %@", me), limit: limit)
        async let outgoing = fetch(NSPredicate(format: "fromId == %@", me), limit: limit)
        return await decrypt(try await incoming + outgoing, me: me)
    }

    static func thread(me: String, other: String, limit: Int = 150) async throws -> [DirectMessage] {
        await decrypt(try await fetch(NSPredicate(format: "thread == %@", threadId(me, other)), limit: limit), me: me)
    }

    private static func fetch(_ predicate: NSPredicate, limit: Int) async throws -> [CKRecord] {
        let query = CKQuery(recordType: "DirectMessage", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]
        do {
            // attachments are fetched lazily by the bubble, never with the list
            let (results, _) = try await database.records(
                matching: query, desiredKeys: ["thread", "fromId", "toId", "fromName", "toName", "created", "payload", "mediaType"],
                resultsLimit: limit)
            return results.compactMap { try? $0.1.get() }
        } catch let error as CKError where error.code == .unknownItem || error.code == .invalidArguments {
            return []   // record type not created yet — nobody has written a DM
        }
    }

    private static func decrypt(_ records: [CKRecord], me: String) async -> [DirectMessage] {
        var keys: [String: SymmetricKey?] = [:]
        var messages: [DirectMessage] = []
        for record in records {
            guard let thread = record["thread"] as? String,
                  let fromId = record["fromId"] as? String,
                  let toId = record["toId"] as? String,
                  let payload = record["payload"] as? Data else { continue }
            let other = fromId == me ? toId : fromId
            if keys[thread] == nil {
                let theirKey = await publicKey(of: other)
                keys[thread] = .some(theirKey.flatMap { try? DMKeys.sharedKey(with: $0, thread: thread) })
            }
            let text = (keys[thread] ?? nil).flatMap { DMKeys.open(payload, with: $0) }
            messages.append(DirectMessage(
                id: record.recordID, thread: thread, fromId: fromId, toId: toId,
                fromName: record["fromName"] as? String ?? "?", toName: record["toName"] as? String ?? "?",
                date: (record["created"] as? Date) ?? record.creationDate ?? .now,
                text: text ?? "🔒 Sent from another device — can't be read here",
                readable: text != nil,
                mediaType: record["mediaType"] as? String))
        }
        return messages.sorted { $0.date > $1.date }
    }

    /// CloudKit itself pushes "X sent you a private message" for every new
    /// record addressed to me — no server in the loop. Idempotent.
    static func subscribeToInbox(me: String) async {
        let subscription = CKQuerySubscription(
            recordType: "DirectMessage",
            predicate: NSPredicate(format: "toId == %@", me),
            subscriptionID: "dm-inbox-\(me)",
            options: [.firesOnRecordCreation])
        let info = CKSubscription.NotificationInfo()
        info.alertLocalizationKey = "%1$@ sent you a private message"
        info.alertLocalizationArgs = ["fromName"]
        info.soundName = "default"
        subscription.notificationInfo = info
        _ = try? await database.save(subscription)
    }

    /// Same report record the room uses; the decrypted text goes with it so
    /// the report can actually be reviewed.
    static func report(_ message: DirectMessage, reason: String) async {
        let record = CKRecord(recordType: "Report")
        record["messageRecordName"] = message.id.recordName
        record["messageText"] = message.text
        record["messageSenderId"] = message.fromId
        record["reason"] = reason
        _ = try? await database.save(record)
    }
}

/// Per-thread "last read" marks, kept on the device.
enum DMReadState {
    private static let key = "dmLastRead"

    static func lastRead(_ thread: String) -> Date {
        let all = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        return Date(timeIntervalSince1970: all[thread] ?? 0)
    }

    static func markRead(_ thread: String) {
        var all = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        all[thread] = Date().timeIntervalSince1970
        UserDefaults.standard.set(all, forKey: key)
    }

    /// Incoming messages the user hasn't seen, ignoring blocked senders.
    static func unread(in messages: [DirectMessage], me: String) -> [DirectMessage] {
        let blocked = ChatModeration.blockedUsers
        return messages.filter {
            $0.toId == me && !blocked.contains($0.fromId) && $0.date > lastRead($0.thread)
        }
    }
}
