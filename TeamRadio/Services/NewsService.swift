import Foundation

/// Aggregates F1 news from the major outlets' RSS feeds — no API keys needed.
enum NewsService {
    static let feeds: [(url: String, source: String)] = [
        ("https://www.formula1.com/en/latest/all.xml", "Formula1.com"),
        ("https://feeds.bbci.co.uk/sport/formula1/rss.xml", "BBC Sport"),
        ("https://www.motorsport.com/rss/f1/news/", "Motorsport.com"),
    ]

    /// Fetches every feed concurrently, merges, and sorts newest-first.
    /// A feed that fails just contributes nothing.
    static func latest(limit: Int = 40) async -> [NewsItem] {
        var items: [NewsItem] = []
        await withTaskGroup(of: [NewsItem].self) { group in
            for feed in feeds {
                group.addTask {
                    guard let url = URL(string: feed.url) else { return [] }
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 15
                    guard let (data, _) = try? await URLSession.shared.data(for: request) else {
                        return []
                    }
                    var parsed = RSSParser.parse(data: data, source: feed.source)
                    // Feeds without item dates are newest-first; synthesize
                    // descending sort keys from position so they interleave.
                    let now = Date()
                    for index in parsed.indices where parsed[index].published == nil {
                        parsed[index].sortDate = now.addingTimeInterval(Double(-900 - index * 1200))
                    }
                    return parsed
                }
            }
            for await parsed in group {
                items.append(contentsOf: parsed)
            }
        }

        var seenTitles = Set<String>()
        return items
            .sorted { $0.sortDate > $1.sortDate }
            .filter { seenTitles.insert($0.title.lowercased()).inserted }
            .prefix(limit)
            .map { $0 }
    }
}

/// Minimal RSS 2.0 parser covering the fields the app shows. Handles item
/// title/link/pubDate plus thumbnails from enclosure, media:thumbnail, or
/// media:content tags.
final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private let source: String

    private var inItem = false
    private var currentElement = ""
    private var title = ""
    private var link = ""
    private var pubDate = ""
    private var summary = ""
    private var imageURL: String?

    private init(source: String) {
        self.source = source
    }

    static func parse(data: Data, source: String) -> [NewsItem] {
        let delegate = RSSParser(source: source)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName: String?, attributes: [String: String]
    ) {
        currentElement = elementName
        switch elementName {
        case "item":
            inItem = true
            title = ""; link = ""; pubDate = ""; summary = ""; imageURL = nil
        case "enclosure", "media:thumbnail", "media:content":
            if inItem, imageURL == nil,
               let url = attributes["url"],
               attributes["type"]?.hasPrefix("audio") != true {
                imageURL = url
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": title += string
        case "link": link += string
        case "pubDate": pubDate += string
        case "description": summary += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, let string = String(data: CDATABlock, encoding: .utf8) else { return }
        switch currentElement {
        case "title": title += string
        case "link": link += string
        case "description": summary += string
        default: break
        }
    }

    /// Feed summaries can carry HTML: tags out, entities decoded, spaces tidied.
    static func plainText(_ html: String) -> String? {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (entity, character) in ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " ",
                                    "&#8217;": "’", "&#8216;": "‘", "&#8220;": "“", "&#8221;": "”", "&#8211;": "–", "&#8212;": "—"] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName: String?
    ) {
        guard elementName == "item" else {
            currentElement = ""
            return
        }
        inItem = false
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty, let url = URL(string: trimmedLink) {
            let published = Self.parseDate(pubDate.trimmingCharacters(in: .whitespacesAndNewlines))
            items.append(NewsItem(
                title: trimmedTitle,
                link: url,
                source: source,
                published: published,
                sortDate: published ?? .distantPast,
                imageURL: imageURL.flatMap(URL.init(string:)),
                summary: Self.plainText(summary)
            ))
        }
    }

    private static let dateFormats = ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz"]

    private static func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
