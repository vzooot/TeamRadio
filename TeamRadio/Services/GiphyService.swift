import Foundation

/// A GIF or animated sticker from GIPHY. Messages carry only `url`; the
/// art streams from GIPHY's CDN, nothing is uploaded to CloudKit.
struct GiphyItem: Identifiable, Hashable {
    let id: String
    let url: URL          // fixed-width GIF for bubbles (~200px wide)
    let previewURL: URL   // small preview for the picker grid
    let width: Int
    let height: Int
}

/// Thin client for GIPHY's public API (GIFs + stickers), PG-13 filtered.
enum GiphyService {
    enum Kind: String, CaseIterable {
        case gifs, stickers
        var title: String { self == .gifs ? "GIFS" : "STICKERS" }
    }

    /// Read from the gitignored Secrets.plist; nil hides the feature.
    static let apiKey: String? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let key = dict["GiphyAPIKey"] as? String, !key.isEmpty else { return nil }
        return key
    }()

    static var isAvailable: Bool { apiKey != nil }

    static func trending(_ kind: Kind) async throws -> [GiphyItem] {
        try await fetch(path: "\(kind.rawValue)/trending", query: [:])
    }

    static func search(_ kind: Kind, _ term: String) async throws -> [GiphyItem] {
        try await fetch(path: "\(kind.rawValue)/search", query: ["q": term])
    }

    private static func fetch(path: String, query: [String: String]) async throws -> [GiphyItem] {
        guard let apiKey else { return [] }
        var components = URLComponents(string: "https://api.giphy.com/v1/\(path)")!
        var items = [URLQueryItem(name: "api_key", value: apiKey),
                     URLQueryItem(name: "limit", value: "30"),
                     URLQueryItem(name: "rating", value: "pg-13")]
        items += query.map { URLQueryItem(name: $0.key, value: $0.value) }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)

        struct Envelope: Decodable {
            struct Item: Decodable {
                struct Images: Decodable {
                    struct Rendition: Decodable { let url: String; let width: String; let height: String }
                    let fixed_width: Rendition
                    let fixed_width_small: Rendition
                }
                let id: String
                let images: Images
            }
            let data: [Item]
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: data)
        return decoded.data.compactMap { item in
            guard let url = URL(string: item.images.fixed_width.url),
                  let preview = URL(string: item.images.fixed_width_small.url) else { return nil }
            return GiphyItem(id: item.id, url: url, previewURL: preview,
                             width: Int(item.images.fixed_width.width) ?? 200,
                             height: Int(item.images.fixed_width.height) ?? 200)
        }
    }
}
