import AVKit
import PhotosUI
import SwiftUI

/// A photo or video from the library, compressed and staged as a temp file
/// ready to upload — shared by the room and private threads.
struct StagedMedia {
    let url: URL
    let type: String        // "image" | "video"
    let preview: UIImage?
}

enum MediaStagingError: LocalizedError {
    case unreadable, tooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable: "Couldn't load that from your library."
        case .tooLarge: "Videos up to 25 MB only — try a shorter clip."
        }
    }
}

enum MediaStaging {
    /// Photos become ≤1440 px JPEGs; videos are accepted up to 25 MB.
    static func stage(_ item: PhotosPickerItem) async throws -> StagedMedia {
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .audiovisualContent) }
        guard let data = try? await item.loadTransferable(type: Data.self) else { throw MediaStagingError.unreadable }
        let temp = FileManager.default.temporaryDirectory
        if isVideo {
            guard data.count <= 25 * 1024 * 1024 else { throw MediaStagingError.tooLarge }
            let url = temp.appendingPathComponent("upload-\(UUID().uuidString).mov")
            try data.write(to: url)
            return StagedMedia(url: url, type: "video", preview: await videoThumbnail(url: url))
        }
        guard let image = UIImage(data: data) else { throw MediaStagingError.unreadable }
        let scaled = image.scaledDown(maxDimension: 1440)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.75) else { throw MediaStagingError.unreadable }
        let url = temp.appendingPathComponent("upload-\(UUID().uuidString).jpg")
        try jpeg.write(to: url)
        return StagedMedia(url: url, type: "image", preview: scaled)
    }

    static func videoThumbnail(url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: .zero) { cg, _, _ in
                continuation.resume(returning: cg.map(UIImage.init))
            }
        }
    }
}

extension UIImage {
    func scaledDown(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

/// Attachment preview row above an input bar.
struct PendingMediaRow: View {
    let media: StagedMedia
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let preview = media.preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: media.type == "video" ? "video.fill" : "photo.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 52, height: 52)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            }
            Text(media.type == "video" ? "Video attached" : "Photo attached")
                .font(.system(size: 13))
                .foregroundStyle(Theme.dimText)
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
}
