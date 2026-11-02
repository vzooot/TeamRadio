import Foundation

/// One story from an F1 news RSS feed.
struct NewsItem: Identifiable, Equatable {
    let title: String
    let link: URL
    let source: String
    /// Shown to the user; nil when the feed carries no dates (F1.com).
    let published: Date?
    /// Used for merge ordering; synthesized from feed position when
    /// `published` is missing, so undated feeds still interleave sensibly.
    var sortDate: Date
    let imageURL: URL?
    /// The feed's own summary, as plain text (the iPhone Duo's story preview).
    var summary: String?

    var id: String { link.absoluteString }

    static func == (lhs: NewsItem, rhs: NewsItem) -> Bool { lhs.id == rhs.id }
}
