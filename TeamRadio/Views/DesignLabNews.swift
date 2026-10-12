#if DEBUG
import SwiftUI

// Debug-only drafts: three directions for a livelier News tab, on the real
// feeds. Launch with -DesignLab news1|news2|news3. Nothing here ships.

private func sourceColor(_ source: String) -> Color {
    switch source {
    case "Formula1.com": Theme.accent
    case "BBC Sport": Color(red: 1.0, green: 0.82, blue: 0.0)
    default: Color(red: 1.0, green: 0.35, blue: 0.0)
    }
}

private func ago(_ item: NewsItem) -> String? {
    item.published.map { $0.formatted(.relative(presentation: .named)).uppercased() }
}

/// Remote image that fills its frame, with a dark placeholder.
private struct Photo: View {
    let url: URL?
    var body: some View {
        Color.white.opacity(0.05)
            .overlay {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
            .clipped()
    }
}

private struct NewsDraftShell<Content: View>: View {
    @State private var model = NewsViewModel()
    @ViewBuilder let content: ([NewsItem]) -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 9) {
                    TrioSlashes(height: 24).padding(.top, 6)
                    Text("PADDOCK NEWS")
                }
                .font(.f1(30).italic())
                .foregroundStyle(Theme.chromeText)
                if !model.items.isEmpty { content(model.items) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .task { await model.load() }
    }
}

// MARK: - Headline-led drafts

/// Teams a headline mentions (by team or driver name), with display names.
private let teamWords: [(id: String, name: String, words: [String])] = [
    ("red_bull", "RED BULL", ["red bull", "verstappen"]),
    ("ferrari", "FERRARI", ["ferrari", "leclerc", "hamilton"]),
    ("mercedes", "MERCEDES", ["mercedes", "russell", "antonelli", "wolff"]),
    ("mclaren", "McLAREN", ["mclaren", "norris", "piastri", "stella"]),
    ("aston_martin", "ASTON", ["aston martin", "alonso", "stroll"]),
    ("alpine", "ALPINE", ["alpine", "gasly", "colapinto"]),
    ("williams", "WILLIAMS", ["williams", "albon", "sainz"]),
    ("racing_bulls", "RACING BULLS", ["racing bulls", "lawson", "hadjar"]),
    ("haas", "HAAS", ["haas", "ocon", "bearman"]),
    ("audi", "AUDI", ["audi", "sauber", "hulkenberg", "bortoleto"]),
    ("cadillac", "CADILLAC", ["cadillac", "perez", "bottas"]),
]

private func teams(in items: [NewsItem]) -> [(id: String, name: String, count: Int)] {
    teamWords.map { team in
        (team.id, team.name, items.filter { item in team.words.contains { item.title.lowercased().contains($0) } }.count)
    }
    .filter { $0.count > 0 }
    .sorted { $0.count > $1.count }
}

/// A headline that carries a quote, for a pull-quote card.
private func quoteItem(_ items: [NewsItem]) -> NewsItem? {
    items.first { $0.title.contains("'") || $0.title.contains("\"") || $0.title.contains("‘") || $0.title.contains("“") }
}

/// A broadcast-style ticker of headlines scrolling right to left.
private struct Ticker: View {
    let headlines: [String]
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let text = headlines.joined(separator: "   ◆   ")
                Text(text + "   ◆   " + text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .offset(x: -CGFloat((t * 40).truncatingRemainder(dividingBy: Double(max(text.count, 1)) * 6.6)))
                    .frame(width: geo.size.width, alignment: .leading)
            }
        }
        .frame(height: 18)
        .clipped()
    }
}

// MARK: - 4 · Broadcast: ticker, giant headline, trending, teams, a quote

struct NewsDraftBroadcast: View {
    var body: some View {
        NewsDraftShell { items in
            // live ticker
            HStack(spacing: 10) {
                Text("LIVE").font(.f1(11, weight: .heavy)).tracking(1.5).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.live))
                Ticker(headlines: items.prefix(6).map(\.title))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))

            // lead story: giant headline over the photo's lower edge
            VStack(alignment: .leading, spacing: 0) {
                Photo(url: items[0].imageURL).frame(height: 210)
                    .overlay(LinearGradient(colors: [.clear, Theme.background], startPoint: .center, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(items[0].source.uppercased()).font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(items[0].source))
                        if let ago = ago(items[0]) { Text(ago).font(.f1(9, weight: .bold)).foregroundStyle(Theme.faintText) }
                    }
                    Text(items[0].title.uppercased()).font(.f1(26).italic()).foregroundStyle(Theme.chromeText).lineLimit(4)
                }
                .padding(.horizontal, 4)
                .offset(y: -36)
                .padding(.bottom, -36)
            }

            // teams in the news
            let inNews = teams(in: items)
            if !inNews.isEmpty {
                Text("TEAMS IN THE NEWS").font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.dimText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(inNews, id: \.id) { team in
                            HStack(spacing: 6) {
                                Capsule().fill(Theme.teamColor(team.id)).frame(width: 4, height: 18)
                                Text(team.name).font(.f1(12).italic()).foregroundStyle(.white)
                                Text("\(team.count)").font(.f1Digits(12)).foregroundStyle(Theme.teamColor(team.id))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(Theme.teamColor(team.id).opacity(0.18)))
                        }
                    }
                }
            }

            // trending: big numerals
            Text("TRENDING").font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.dimText).padding(.top, 4)
            ForEach(Array(items.dropFirst().prefix(5).enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.f1Digits(44))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.violet], startPoint: .top, endPoint: .bottom))
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.source.uppercased()).font(.f1(9, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(item.source))
                        Text(item.title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white).lineLimit(3)
                    }
                }
                .padding(.vertical, 4)
            }

            // pull quote
            if let quote = quoteItem(items) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("“").font(.system(size: 64, weight: .black)).foregroundStyle(Theme.violet).frame(height: 36, alignment: .top)
                    Text(quote.title).font(.system(size: 20, weight: .bold).italic()).foregroundStyle(.white)
                    Text(quote.source.uppercased()).font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(quote.source))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [Theme.violet.opacity(0.25), Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
        }
    }
}

// MARK: - 5 · Front page: a typographic newspaper

struct NewsDraftFrontPageType: View {
    var body: some View {
        NewsDraftShell { items in
            VStack(alignment: .leading, spacing: 4) {
                Rectangle().fill(.white).frame(height: 2)
                HStack {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    Spacer()
                    Text("RACE WEEK · R18")
                }
                .font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                Rectangle().fill(.white.opacity(0.3)).frame(height: 1)
            }

            // lead
            Text(items[0].title).font(.system(size: 30, weight: .black, design: .serif)).foregroundStyle(.white).lineLimit(4)
            HStack(alignment: .top, spacing: 12) {
                Text(items[0].source.uppercased()).font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(items[0].source))
                Spacer()
                Photo(url: items[0].imageURL).frame(width: 150, height: 96).clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Rectangle().fill(.white.opacity(0.2)).frame(height: 1)

            // two columns of headlines
            HStack(alignment: .top, spacing: 14) {
                column(Array(items.dropFirst().prefix(3)))
                Rectangle().fill(.white.opacity(0.2)).frame(width: 1)
                column(Array(items.dropFirst(4).prefix(3)))
            }
            Rectangle().fill(.white.opacity(0.2)).frame(height: 1)

            // briefs
            Text("IN BRIEF").font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.accent)
            ForEach(items.dropFirst(7).prefix(5)) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(sourceColor(item.source)).frame(width: 6, height: 6)
                    Text(item.title).font(.system(size: 14, weight: .semibold, design: .serif)).foregroundStyle(.white.opacity(0.9)).lineLimit(2)
                }
            }
        }
    }

    private func column(_ items: [NewsItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.source.uppercased()).font(.f1(8, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(item.source))
                    Text(item.title).font(.system(size: index == 0 ? 18 : 14, weight: index == 0 ? .black : .bold, design: .serif))
                        .foregroundStyle(.white).lineLimit(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 1 · Front page: hero story, a carousel, then a compact list

struct NewsDraftFrontPage: View {
    var body: some View {
        NewsDraftShell { items in
            filterChips
            hero(items[0])
            Text("LATEST").font(.f1(12, weight: .heavy)).tracking(2).foregroundStyle(Theme.dimText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items.dropFirst().prefix(6)) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Photo(url: item.imageURL).frame(width: 220, height: 124).clipShape(RoundedRectangle(cornerRadius: 14))
                            Text(item.source.uppercased()).font(.f1(9, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(item.source))
                            Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).lineLimit(3)
                        }
                        .frame(width: 220, alignment: .leading)
                    }
                }
            }
            Text("MORE STORIES").font(.f1(12, weight: .heavy)).tracking(2).foregroundStyle(Theme.dimText).padding(.top, 4)
            ForEach(items.dropFirst(7).prefix(4)) { item in
                HStack(spacing: 12) {
                    Photo(url: item.imageURL).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.source.uppercased()).font(.f1(9, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(item.source))
                        Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                    }
                }
            }
        }
    }

    private var filterChips: some View {
        HStack(spacing: 6) {
            ForEach(["ALL", "F1.COM", "BBC", "MOTORSPORT"], id: \.self) { s in
                Text(s).font(.f1(11, weight: .heavy)).tracking(1)
                    .foregroundStyle(s == "ALL" ? Theme.onAccent : Theme.dimText)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(s == "ALL" ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06))))
            }
        }
    }

    private func hero(_ item: NewsItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            Photo(url: item.imageURL)
            LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("TOP STORY").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Theme.accentGradient))
                    Text(item.source.uppercased()).font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(item.source))
                }
                Text(item.title).font(.f1(22).italic()).foregroundStyle(.white).lineLimit(3)
            }
            .padding(18)
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.glassStroke, lineWidth: 1))
        .trioGlow(cornerRadius: 22, opacity: 0.4)
    }
}

// MARK: - 2 · Live timeline: the paddock wire, time-stamped on a glowing line

struct NewsDraftTimeline: View {
    var body: some View {
        NewsDraftShell { items in
            HStack(spacing: 6) {
                Circle().fill(Theme.live).frame(width: 8, height: 8).shadow(color: Theme.live, radius: 4)
                Text("PADDOCK WIRE · LIVE").font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.live)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.prefix(8).enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            Circle().fill(sourceColor(item.source)).frame(width: 12, height: 12)
                                .shadow(color: sourceColor(item.source), radius: 5)
                            Rectangle()
                                .fill(LinearGradient(colors: [Theme.accent, Theme.violet, Theme.live], startPoint: .top, endPoint: .bottom).opacity(0.5))
                                .frame(width: 2)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(item.source.uppercased()).font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(item.source))
                                if let ago = ago(item) {
                                    Text(ago).font(.f1(9, weight: .bold)).foregroundStyle(Theme.faintText)
                                }
                                if index == 0 {
                                    Text("NEW").font(.f1(9, weight: .heavy)).foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Theme.live))
                                }
                            }
                            Text(item.title).font(.system(size: index == 0 ? 18 : 15, weight: .bold)).foregroundStyle(.white).lineLimit(3)
                            if index % 3 == 0 {
                                Photo(url: item.imageURL).frame(height: index == 0 ? 170 : 120).clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.bottom, 22)
                    }
                }
            }
        }
    }
}

// MARK: - 3 · Magazine: one big story, then a bento grid of image tiles

struct NewsDraftMagazine: View {
    var body: some View {
        NewsDraftShell { items in
            tile(items[0], height: 260, big: true)
            HStack(spacing: 10) {
                tile(items[1], height: 200, big: false)
                VStack(spacing: 10) {
                    tile(items[2], height: 95, big: false, imageOnly: true)
                    tile(items[3], height: 95, big: false, imageOnly: true)
                }
            }
            HStack(spacing: 10) {
                tile(items[4], height: 150, big: false)
                tile(items[5], height: 150, big: false)
            }
            tile(items[6], height: 160, big: false)
        }
    }

    private func tile(_ item: NewsItem, height: CGFloat, big: Bool, imageOnly: Bool = false) -> some View {
        ZStack(alignment: .bottomLeading) {
            Photo(url: item.imageURL)
            LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Rectangle().fill(sourceColor(item.source)).frame(width: 24, height: 3)
                Text(item.source.uppercased()).font(.f1(9, weight: .heavy)).tracking(1).foregroundStyle(sourceColor(item.source))
                Text(item.title)
                    .font(big ? .f1(20).italic() : .system(size: imageOnly ? 11 : 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(big ? 3 : (imageOnly ? 2 : 3))
            }
            .padding(big ? 16 : 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: big ? 22 : 16))
    }
}
#endif
