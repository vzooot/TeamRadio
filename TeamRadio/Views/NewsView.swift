import SwiftUI
import UIKit
import WebKit

/// Paddock news, broadcast style: a live ticker of headlines, the lead story
/// as a giant headline, teams in the news (tap one to filter), trending
/// stories with big numerals, a pull quote, then the rest of the wire.
struct NewsView: View {
    @State private var model = NewsViewModel()
    @State private var team: NewsTeam?
    @Environment(\.openURL) private var openURL
    @State private var wide = false
    /// The story open in the reader (iPhone Duo); the lead until one's tapped.
    @State private var open: NewsItem?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(colors: [Theme.accent.opacity(0.14), .clear], center: .top, startRadius: 0, endRadius: 380)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.live.opacity(0.10), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 460)
                .ignoresSafeArea()

            if model.isLoading {
                LoadingView()
            } else if model.items.isEmpty {
                VStack(spacing: 10) {
                    Text("📰 NO SIGNAL FROM THE PADDOCK")
                        .font(.f1(18).italic())
                        .foregroundStyle(.white)
                    Text("Couldn't reach the news feeds. Pull to retry.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                }
            } else if wide {
                reader
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        NewsTicker(headlines: model.items.prefix(8).map(\.title))
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .refreshable { await model.load() }
            }
        }
        .onWideScreen($wide)
        .task { await model.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 9) {
                TrioSlashes(height: 24).padding(.top, 6)
                Text("PADDOCK NEWS")
            }
            .font(.f1(30).italic())
            .foregroundStyle(Theme.chromeText)
            Text("F1.COM · BBC SPORT · MOTORSPORT.COM")
                .font(.f1(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Theme.dimText)
        }
        .padding(.top, 8)
    }

    /// Stories for the chosen team, or all of them; the newest story with a
    /// photo leads.
    private var stories: [NewsItem] {
        let list = team.map { t in model.items.filter { t.mentioned(in: $0.title) } } ?? model.items
        guard let lead = list.first(where: { $0.imageURL != nil }) else { return list }
        return [lead] + list.filter { $0.id != lead.id }
    }

    /// The teams in the news; tap one to filter the stories.
    @ViewBuilder
    private var teams: some View {
        let inNews = NewsTeam.all
            .map { t in (team: t, count: model.items.filter { t.mentioned(in: $0.title) }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
        if !inNews.isEmpty {
            NewsSection(title: team == nil ? "TEAMS IN THE NEWS" : "FILTERED · \(team!.name)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(inNews, id: \.team.id) { entry in
                        let on = entry.team.id == team?.id
                        Button {
                            withAnimation(.snappy) { team = on ? nil : entry.team }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            HStack(spacing: 6) {
                                Capsule().fill(entry.team.color).frame(width: 4, height: 18)
                                Text(entry.team.name).font(.f1(12).italic()).foregroundStyle(.white)
                                Text("\(entry.count)").font(.f1Digits(12)).foregroundStyle(on ? .white : entry.team.color)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(entry.team.color.opacity(on ? 0.6 : 0.18)))
                            .overlay(Capsule().strokeBorder(on ? entry.team.color : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    /// The iPhone Duo unfolded (approved draft B,
    /// build/mockups/duo2/sheet-3-games-news.png): the stories in the left
    /// half; the one tapped opens in the right, without leaving the app.
    private var reader: some View {
        let list = stories
        let current = list.first { $0.id == open?.id } ?? list.first
        return HStack(alignment: .top, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    NewsTicker(headlines: model.items.prefix(8).map(\.title))
                    if let lead = list.first {
                        Button { open = lead } label: { LeadStory(item: lead) }
                            .buttonStyle(.plain)
                            .overlay(alignment: .topLeading) {
                                if current?.id == lead.id { openBadge.padding(10) }
                            }
                    }
                    teams
                    if list.count > 1 { NewsSection(title: "LATEST") }
                    ForEach(list.dropFirst()) { item in
                        let on = current?.id == item.id
                        Button { open = item } label: {
                            WireRow(item: item)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 14).fill(on ? Theme.accent.opacity(0.12) : .clear)
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(on ? Theme.accent.opacity(0.7) : .clear, lineWidth: 1.2)))
                        }
                        .buttonStyle(.plain)
                    }
                    if list.isEmpty {
                        Text("No stories about \(team?.name.capitalized ?? "this team") right now.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.dimText)
                    }
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable { await model.load() }
            .frame(width: WideScreen.column)

            if let current {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        NewsMeta(item: current)
                        Spacer()
                        Button { openURL(current.link) } label: {
                            Label("SAFARI", systemImage: "safari")
                                .font(.f1(10, weight: .heavy))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open in Safari")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.card)
                    NewsWebView(url: current.link)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke, lineWidth: 1))
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 18)
    }

    private var openBadge: some View {
        Text("OPEN →")
            .font(.f1(10, weight: .heavy))
            .tracking(1)
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.accentGradient))
    }

    @ViewBuilder
    private var content: some View {
        let list = stories
        if let lead = list.first {
            Button { openURL(lead.link) } label: { LeadStory(item: lead) }
                .buttonStyle(.plain)
        }

        teams

        let trending = Array(list.dropFirst().prefix(5))
        if !trending.isEmpty {
            NewsSection(title: "TRENDING")
            ForEach(Array(trending.enumerated()), id: \.element.id) { index, item in
                Button { openURL(item.link) } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.f1Digits(44))
                            .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.violet], startPoint: .top, endPoint: .bottom))
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            NewsMeta(item: item)
                            Text(item.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }

        if let quote = list.dropFirst(6).first(where: { $0.hasQuote }) ?? list.first(where: { $0.hasQuote && $0.id != list.first?.id }) {
            Button { openURL(quote.link) } label: { PullQuote(item: quote) }
                .buttonStyle(.plain)
        }

        let rest = list.dropFirst(6).filter { !$0.hasQuote || $0.id != list.dropFirst(6).first(where: { $0.hasQuote })?.id }
        if !rest.isEmpty {
            NewsSection(title: "THE WIRE")
            ForEach(rest) { item in
                Button { openURL(item.link) } label: { WireRow(item: item) }
                    .buttonStyle(.plain)
            }
        }

        if list.isEmpty {
            Text("No stories about \(team?.name.capitalized ?? "this team") right now.")
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
        }
    }
}

// MARK: - Pieces

private struct NewsSection: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.f1(11, weight: .heavy))
            .tracking(2)
            .foregroundStyle(Theme.dimText)
            .padding(.top, 4)
    }
}

/// Source in its colour and the age of the story.
private struct NewsMeta: View {
    let item: NewsItem
    var body: some View {
        HStack(spacing: 8) {
            Text(item.source.uppercased())
                .font(.f1(9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(item.sourceColor)
            if let published = item.published {
                Text(published.formatted(.relative(presentation: .named)).uppercased())
                    .font(.f1(9, weight: .bold))
                    .foregroundStyle(Theme.faintText)
            }
        }
    }
}

/// A broadcast ticker: the latest headlines sliding right to left.
private struct NewsTicker: View {
    let headlines: [String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 1

    var body: some View {
        HStack(spacing: 10) {
            Text("LIVE")
                .font(.f1(11, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.live))
            // An overlay on a fixed-height strip, so the long line of
            // headlines never widens the page.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 18)
                .overlay(alignment: .leading) {
                    TimelineView(.animation(paused: reduceMotion)) { context in
                        let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                        let line = headlines.joined(separator: "   ◆   ") + "   ◆   "
                        HStack(spacing: 0) {
                            Text(line).fixedSize()
                                .background(GeometryReader { geo in
                                    Color.clear.onAppear { textWidth = max(geo.size.width, 1) }
                                })
                            Text(line).fixedSize()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .offset(x: -CGFloat((t * 40).truncatingRemainder(dividingBy: Double(textWidth))))
                    }
                }
                .clipped()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Latest headlines: " + headlines.prefix(3).joined(separator: ". "))
    }
}

/// The lead: photo (or team art) with a giant headline rising out of it.
private struct LeadStory: View {
    let item: NewsItem
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NewsArt(item: item)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(LinearGradient(colors: [.clear, Theme.background], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 18)))
            VStack(alignment: .leading, spacing: 8) {
                NewsMeta(item: item)
                Text(item.title.uppercased())
                    .font(.f1(26).italic())
                    .foregroundStyle(Theme.chromeText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
            }
            .padding(.horizontal, 4)
            .offset(y: -36)
            .padding(.bottom, -36)
        }
    }
}

private struct PullQuote: View {
    let item: NewsItem
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("“")
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(Theme.violet)
                .frame(height: 36, alignment: .top)
            Text(item.title)
                .font(.system(size: 20, weight: .bold).italic())
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            NewsMeta(item: item)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Theme.violet.opacity(0.25), Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}

private struct WireRow: View {
    let item: NewsItem
    var body: some View {
        HStack(spacing: 12) {
            NewsArt(item: item)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                NewsMeta(item: item)
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// The story's photo, or for feeds without photos a stand-in: the
/// mentioned team's colours and car, else the source's colour on carbon.
private struct NewsArt: View {
    let item: NewsItem

    var body: some View {
        if let url = item.imageURL {
            Color.white.opacity(0.05)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { fallback }
                    }
                }
                .clipped()
        } else {
            fallback
        }
    }

    private var fallback: some View {
        let team = NewsTeam.all.first { $0.mentioned(in: item.title) }
        let tint = team?.color ?? item.sourceColor
        return ZStack {
            CarbonFiber()
            LinearGradient(colors: [tint.opacity(0.75), tint.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let team, UIImage(named: "Cars/\(team.id)") != nil {
                Image("Cars/\(team.id)")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            } else {
                TrioSlashes(height: 26)
            }
        }
        .clipped()
    }
}

/// The reader's page (iPhone Duo): the story's site, with a spinner until
/// it has loaded.
private struct NewsWebView: View {
    let url: URL
    @State private var loading = true

    var body: some View {
        Site(url: url, loading: $loading)
            .overlay { if loading { ProgressView().tint(Theme.accent) } }
            .background(Theme.card)
    }

    private struct Site: UIViewRepresentable {
        let url: URL
        @Binding var loading: Bool

        func makeUIView(context: Context) -> WKWebView {
            let web = WKWebView()
            web.isOpaque = false
            web.backgroundColor = .clear
            web.navigationDelegate = context.coordinator
            web.load(URLRequest(url: url))
            return web
        }

        func updateUIView(_ web: WKWebView, context: Context) {
            context.coordinator.page = self
            guard context.coordinator.requested != url else { return }
            context.coordinator.requested = url
            web.load(URLRequest(url: url))
        }

        func makeCoordinator() -> Coordinator { Coordinator(page: self) }

        final class Coordinator: NSObject, WKNavigationDelegate {
            var page: Site
            var requested: URL?

            init(page: Site) {
                self.page = page
                requested = page.url
            }

            func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { page.loading = true }
            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { page.loading = false }
            func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { page.loading = false }
            func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
                page.loading = false
            }
        }
    }
}

/// A team as the news mentions it: by its name or its drivers'.
struct NewsTeam: Identifiable, Equatable {
    let id: String
    let name: String
    let words: [String]

    var color: Color { Theme.teamColor(id) }

    func mentioned(in title: String) -> Bool {
        let lower = title.lowercased()
        return words.contains { lower.contains($0) }
    }

    static let all: [NewsTeam] = [
        NewsTeam(id: "red_bull", name: "RED BULL", words: ["red bull", "verstappen"]),
        NewsTeam(id: "ferrari", name: "FERRARI", words: ["ferrari", "leclerc", "hamilton"]),
        NewsTeam(id: "mercedes", name: "MERCEDES", words: ["mercedes", "russell", "antonelli", "wolff"]),
        NewsTeam(id: "mclaren", name: "McLAREN", words: ["mclaren", "norris", "piastri", "stella"]),
        NewsTeam(id: "aston_martin", name: "ASTON MARTIN", words: ["aston martin", "alonso", "stroll"]),
        NewsTeam(id: "alpine", name: "ALPINE", words: ["alpine", "gasly", "colapinto"]),
        NewsTeam(id: "williams", name: "WILLIAMS", words: ["williams", "albon", "sainz"]),
        NewsTeam(id: "rb", name: "RACING BULLS", words: ["racing bulls", "lawson", "hadjar"]),
        NewsTeam(id: "haas", name: "HAAS", words: ["haas", "ocon", "bearman"]),
        NewsTeam(id: "audi", name: "AUDI", words: ["audi", "sauber", "hulkenberg", "bortoleto"]),
        NewsTeam(id: "cadillac", name: "CADILLAC", words: ["cadillac", "perez", "bottas"]),
    ]
}

private extension NewsItem {
    var sourceColor: Color {
        switch source {
        case "Formula1.com": Theme.accent
        case "BBC Sport": Color(red: 1.0, green: 0.82, blue: 0.0)
        default: Color(red: 1.0, green: 0.35, blue: 0.0)
        }
    }

    /// The headline carries a quote, worth a pull-quote card.
    var hasQuote: Bool {
        title.contains("'") || title.contains("\"") || title.contains("‘") || title.contains("“")
    }
}
