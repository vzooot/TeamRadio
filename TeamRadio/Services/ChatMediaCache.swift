import CloudKit
import Foundation

/// Lazily downloads and caches chat media (photos/videos stored as CKAssets)
/// so message lists stay light — an asset is only fetched when its bubble
/// actually appears, then kept in the caches directory.
@MainActor
final class ChatMediaCache {
    static let shared = ChatMediaCache()

    private var urls: [String: URL] = [:]
    private var inflight: [String: Task<URL?, Never>] = [:]

    private let dir: URL = {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChatMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private func fileName(_ id: CKRecord.ID, _ type: String) -> String {
        id.recordName + (type == "video" ? ".mov" : ".jpg")
    }

    /// Registers a just-sent file so the sender's own bubble renders instantly.
    func seed(id: CKRecord.ID, type: String, url: URL) {
        let dest = dir.appendingPathComponent(fileName(id, type))
        try? FileManager.default.copyItem(at: url, to: dest)
        urls[id.recordName] = FileManager.default.fileExists(atPath: dest.path) ? dest : url
    }

    /// Local file for a message's media, downloading it on first request.
    /// `decrypt` turns the stored bytes into the real file (private threads
    /// keep their attachments encrypted at rest).
    func url(for id: CKRecord.ID, type: String, decrypt: (@Sendable (Data) -> Data?)? = nil) async -> URL? {
        let key = id.recordName
        if let u = urls[key], FileManager.default.fileExists(atPath: u.path) { return u }
        let cached = dir.appendingPathComponent(fileName(id, type))
        if FileManager.default.fileExists(atPath: cached.path) {
            urls[key] = cached
            return cached
        }
        if let running = inflight[key] { return await running.value }

        let task = Task<URL?, Never> { [dir] in
            let database = ChatService.container.publicCloudDatabase
            guard let result = try? await database.records(for: [id], desiredKeys: ["media"]),
                  let record = try? result[id]?.get(),
                  let asset = record["media"] as? CKAsset,
                  let file = asset.fileURL else { return nil }
            let dest = dir.appendingPathComponent(self.fileName(id, type))
            try? FileManager.default.removeItem(at: dest)
            if let decrypt {
                guard let sealed = try? Data(contentsOf: file), let plain = decrypt(sealed) else { return nil }
                try? plain.write(to: dest)
            } else {
                try? FileManager.default.copyItem(at: file, to: dest)
            }
            return FileManager.default.fileExists(atPath: dest.path) ? dest : nil
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        if let result { urls[key] = result }
        return result
    }
}
