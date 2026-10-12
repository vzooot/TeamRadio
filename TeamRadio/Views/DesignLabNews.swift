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
