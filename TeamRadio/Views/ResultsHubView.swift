import SwiftUI

/// The Results tab: race results and the championship standings. Each page
/// shows a RESULTS | STANDINGS switch under its own title (`ResultsPageSwitch`,
/// handed down through the environment). Both pages stay alive, so switching
/// is instant and keeps each page's place.
struct ResultsHubView: View {
    enum Page { case results, standings }

    #if DEBUG
    // -ResultsPage standings: open on the standings, for screenshots
    @State private var page: Page = UserDefaults.standard.string(forKey: "ResultsPage") == "standings" ? .standings : .results
    #else
    @State private var page: Page = .results
    #endif

    var body: some View {
        ZStack {
            ResultsView()
                .opacity(page == .results ? 1 : 0)
                .allowsHitTesting(page == .results)
                .accessibilityHidden(page != .results)
            StandingsTabView()
                .opacity(page == .standings ? 1 : 0)
                .allowsHitTesting(page == .standings)
                .accessibilityHidden(page != .standings)
        }
        .environment(\.resultsPage, $page)
        .background(Theme.background.ignoresSafeArea())
    }
}

/// Both pages' header, built the same way so the switch never moves when
/// flipping between them: title, one-line subtitle, the spoiler toggle,
/// then RESULTS | STANDINGS at a fixed gap.
struct ResultsHubHeader: View {
    let title: String
    let subtitle: String
    /// Called when spoiler mode is toggled (the page hides its content again).
    var onToggle: () -> Void = {}
    @AppStorage("spoilerMode") private var spoilerMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top, spacing: 9) {
                        TrioSlashes(height: 24)
                            .padding(.top, 6)
                        Text(title)
                    }
                    .font(.f1(30).italic())
                    .foregroundStyle(Theme.chromeText)
                    Text(subtitle)
                        .font(.f1(12, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.dimText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 8)
                // Spoiler mode: results and standings stay hidden until tapped.
                Button {
                    spoilerMode.toggle()
                    onToggle()
                } label: {
                    Image(systemName: spoilerMode ? "eye.slash.fill" : "eye")
                        .font(.system(size: 17))
                        .foregroundStyle(spoilerMode ? Theme.accent : Theme.dimText)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.05))
                                .overlay(Circle().strokeBorder(spoilerMode ? Theme.accent.opacity(0.5) : Theme.cardStroke, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spoilerMode ? "Show spoilers" : "Hide spoilers")
            }
            ResultsPageSwitch()
        }
        .padding(.top, 8)
    }
}

/// Tap-to-reveal cover for people watching sessions delayed.
struct SpoilerShield: View {
    var text = "Tap to reveal the results"

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 28))
                .foregroundStyle(Theme.accent)
            Text("SPOILERS HIDDEN")
                .font(.f1(17).italic())
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
    }
}

/// RESULTS | STANDINGS, placed under each page's title. Shows nothing
/// outside the Results tab.
struct ResultsPageSwitch: View {
    @Environment(\.resultsPage) private var page

    var body: some View {
        if let page {
            HStack(spacing: 8) {
                chip("RESULTS", .results, tint: Theme.accent, page: page)
                chip("STANDINGS", .standings, tint: Theme.violet, page: page)
            }
        }
    }

    private func chip(_ title: String, _ value: ResultsHubView.Page, tint: Color, page: Binding<ResultsHubView.Page>) -> some View {
        Button { page.wrappedValue = value } label: {
            NeonChip(title: title, tint: tint, selected: page.wrappedValue == value)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(page.wrappedValue == value ? .isSelected : [])
    }
}

extension EnvironmentValues {
    @Entry var resultsPage: Binding<ResultsHubView.Page>? = nil
}
