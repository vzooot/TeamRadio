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
