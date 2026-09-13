import SwiftUI

/// Paddock news: latest F1 stories aggregated from the major outlets' feeds.
struct NewsView: View {
    @State private var model = NewsViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.accent.opacity(0.14), .clear],
                center: .top, startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.live.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 460
            )
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
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PADDOCK NEWS")
                                .font(.f1(30).italic())
                                .foregroundStyle(.white)
                            Text("F1.COM · BBC SPORT · MOTORSPORT.COM")
                                .font(.f1(11, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(Theme.dimText)
                        }
                        .padding(.top, 8)

                        ForEach(model.items) { item in
                            Button {
                                openURL(item.link)
                            } label: {
                                NewsCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .refreshable { await model.load() }
            }
        }
        .task { await model.load() }
    }
}

struct NewsCard: View {
    let item: NewsItem

    private var sourceColor: Color {
        switch item.source {
        case "Formula1.com": Theme.accent
        case "BBC Sport": Color(red: 1.0, green: 0.82, blue: 0.0)
        default: Color(red: 1.0, green: 0.35, blue: 0.0)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(item.source.uppercased())
                        .font(.f1(10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(sourceColor)
                    if let published = item.published {
                        Text(published.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(Theme.faintText)
                    }
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)

            if let imageURL = item.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.white.opacity(0.05))
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.glassStroke, lineWidth: 1)
                )
        )
    }
}
