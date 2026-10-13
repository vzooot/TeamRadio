import SwiftUI

/// The Results tab: race results and the championship standings behind a
/// RESULTS | STANDINGS switch. Both stay alive, so switching is instant and
/// keeps each page's place.
struct ResultsHubView: View {
    enum Page { case results, standings }

    #if DEBUG
    // -ResultsPage standings: open on the standings, for screenshots
    @State private var page: Page = UserDefaults.standard.string(forKey: "ResultsPage") == "standings" ? .standings : .results
    #else
    @State private var page: Page = .results
    #endif

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                chip("RESULTS", .results, tint: Theme.accent)
                chip("STANDINGS", .standings, tint: Theme.violet)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

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
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func chip(_ title: String, _ value: Page, tint: Color) -> some View {
        Button { page = value } label: {
            NeonChip(title: title, tint: tint, selected: page == value)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(page == value ? .isSelected : [])
    }
}
