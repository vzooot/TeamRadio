import UserNotifications

/// Adds the media an announcement names ("media": an https link to a short
/// video or an image) before iOS shows it, e.g. the trophy clip in the
/// champion message. Pushes without media, or whose download doesn't make
/// it in time, show exactly as sent.
final class NotificationService: UNNotificationServiceExtension {
    private let lock = NSLock()
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?
    private var download: URLSessionDownloadTask?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        lock.withLock {
            self.contentHandler = contentHandler
            self.content = content
        }
        guard let link = request.content.userInfo["media"] as? String,
              let url = URL(string: link), url.scheme == "https" else {
            finish()
            return
        }
        // "mediaThumb": the second of a video to show before it plays.
        let thumb = request.content.userInfo["mediaThumb"] as? Double
        let task = URLSession.shared.downloadTask(with: url) { [weak self] file, response, _ in
            guard let self else { return }
            if let file, (response as? HTTPURLResponse)?.statusCode == 200,
               let attachment = Self.attachment(file, named: url.lastPathComponent, thumb: thumb) {
                self.lock.withLock { self.content?.attachments = [attachment] }
            }
            self.finish()
        }
        lock.withLock { download = task }
        task.resume()
    }

    /// Out of time: show it without the media.
    override func serviceExtensionTimeWillExpire() {
        lock.withLock { download }?.cancel()
        finish()
    }

    /// Hands the notification to iOS, once.
    private func finish() {
        let (handler, content) = lock.withLock {
            defer { contentHandler = nil }
            return (contentHandler, self.content)
        }
        if let handler, let content { handler(content) }
    }

    /// iOS tells the kind of media from the file's extension, so the
    /// download keeps the link's name.
    private static func attachment(_ file: URL, named name: String, thumb: Double?) -> UNNotificationAttachment? {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let target = dir.appending(path: name.isEmpty ? "media.mp4" : name)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: file, to: target)
            let options = thumb.map { [UNNotificationAttachmentOptionsThumbnailTimeKey: $0] }
            return try UNNotificationAttachment(identifier: "media", url: target, options: options)
        } catch {
            return nil
        }
    }
}
