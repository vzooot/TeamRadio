import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Animated GIF playback for SwiftUI: frames decoded with ImageIO into a
/// UIImageView animation. Downloads are cached on disk and in memory.
struct AnimatedGIFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        view.image = nil
        Task { @MainActor in
            let image = await GIFCache.shared.image(for: url)
            guard context.coordinator.url == url else { return }
            view.image = image
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var url: URL? }
}

@MainActor
final class GIFCache {
    static let shared = GIFCache()
    private let memory = NSCache<NSURL, UIImage>()
    private var inflight: [URL: Task<UIImage?, Never>] = [:]
    private let dir: URL = {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Giphy", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    func image(for url: URL) async -> UIImage? {
        if let hit = memory.object(forKey: url as NSURL) { return hit }
        if let running = inflight[url] { return await running.value }
        let task = Task<UIImage?, Never> { [dir] in
            let file = dir.appendingPathComponent(url.lastPathComponent.isEmpty ? UUID().uuidString : url.absoluteString.hashValue.description + ".gif")
            var data = try? Data(contentsOf: file)
            if data == nil, let (fetched, _) = try? await URLSession.shared.data(from: url) {
                try? fetched.write(to: file)
                data = fetched
            }
            guard let data else { return nil }
            return Self.decode(data)
        }
        inflight[url] = task
        let result = await task.value
        inflight[url] = nil
        if let result { memory.setObject(result, forKey: url as NSURL) }
        return result
    }

    nonisolated private static func decode(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return UIImage(data: data) }
        var frames: [UIImage] = []
        var total: Double = 0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            var delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            if delay < 0.02 { delay = 0.1 }
            total += delay
            frames.append(UIImage(cgImage: cg))
        }
        return UIImage.animatedImage(with: frames, duration: total)
    }
}

/// GIPHY search sheet: GIFs or stickers, trending by default.
struct GiphyPicker: View {
    let onPick: (GiphyItem, GiphyService.Kind) -> Void

    @State private var kind: GiphyService.Kind = .gifs
    @State private var query = ""
    @State private var items: [GiphyItem] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(GiphyService.Kind.allCases, id: \.self) { candidate in
                    Button {
                        kind = candidate
                        reload()
                    } label: {
                        Text(candidate.title)
                            .font(.f1(13).italic())
                            .tracking(1)
                            .foregroundStyle(kind == candidate ? Theme.onAccent : Theme.dimText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(kind == candidate ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.dimText)
                TextField("Search GIPHY", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .foregroundStyle(.white)
                    .onSubmit { reload() }
                    .onChange(of: query) { _, _ in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            guard !Task.isCancelled else { return }
                            reload()
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.glassStroke, lineWidth: 1))
            )

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(items) { item in
                        Button {
                            onPick(item, kind)
                        } label: {
                            AnimatedGIFView(url: item.previewURL)
                                .frame(height: 110)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(kind == .stickers ? 0.06 : 0.02))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if isLoading {
                    ProgressView().tint(Theme.accent).padding(.top, 20)
                } else if items.isEmpty {
                    Text("Nothing found — try another word.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.dimText)
                        .padding(.top, 30)
                }
            }

            // Required attribution for API use.
            Text("Powered by GIPHY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.faintText)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .task { reload() }
    }

    private func reload() {
        let currentKind = kind
        let term = query.trimmingCharacters(in: .whitespaces)
        isLoading = true
        Task {
            let results = (try? await (term.isEmpty
                                       ? GiphyService.trending(currentKind)
                                       : GiphyService.search(currentKind, term))) ?? []
            guard currentKind == kind else { return }
            items = results
            isLoading = false
        }
    }
}
