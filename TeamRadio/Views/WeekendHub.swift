import SwiftUI

/// The iPhone Duo's weekend half (approved, build/mockups/duo6/sheet-hub.png):
/// its own screen beside the race and its countdown, not their page carrying
/// on. A header of its own, like the Results tab's, and a switch between the
/// circuit, the timetable and the standings, one at a time.
struct WeekendHub: View {
    enum Page: String, CaseIterable {
        case circuit = "CIRCUIT", schedule = "SCHEDULE", standings = "STANDINGS"
    }

    let race: Race
    let model: RaceViewModel
    let standings: StandingsViewModel

    @State private var page: Page = .circuit
    /// Spoiler mode (shared with Results): the standings stay blurred until tapped.
    @AppStorage("spoilerMode") private var spoilerMode = false
    @State private var revealed = false
    @Environment(\.champion) private var champion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(spacing: 8) {
                ForEach(Page.allCases, id: \.self) { candidate in
                    Button { page = candidate } label: {
                        NeonChip(title: candidate.rawValue, tint: tint(candidate), selected: page == candidate)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(page == candidate ? .isSelected : [])
                }
            }
            ScrollView {
                switch page {
                case .circuit:
                    if let map = model.trackMap {
                        // fades only: the 3D scene is too heavy to slide
                        TrackSectionView(map: map, circuit: race.circuit, showsTitle: false)
                            .id(race.circuit.circuitId)
                    } else if model.extrasLoading {
                        TrackPlaceholder()
                    }
                case .schedule:
                    WeekendScheduleView(race: race, weather: model.weather, weatherLoading: model.extrasLoading, showsTitle: false)
                        .id(race.id)
                case .standings:
                    table
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .onChange(of: spoilerMode) { _, _ in revealed = false }
    }

    private func tint(_ page: Page) -> Color {
        switch page {
        case .circuit: Theme.accent
        case .schedule: Theme.violet
        case .standings: Theme.live
        }
    }

    /// The title, the place and the round, the race's forecast on the right.
    private var header: some View {
        let raceSession = race.sessions.last { $0.kind == .race }
        let forecast = raceSession.flatMap { WeatherAPI.point(for: $0.date, in: model.weather) }
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 9) {
                    TrioSlashes(height: 24).padding(.top, 6)
                    Text("WEEKEND")
                }
                .font(.f1(30).italic())
                .foregroundStyle(Theme.chromeText)
                Text("\(Flags.emoji(for: race.circuit.location.country)) \(race.circuit.location.locality.uppercased()) · ROUND \(race.roundNumber)")
                    .font(.f1(12, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            if let forecast {
                VStack(spacing: 0) {
                    Text(forecast.symbol).font(.system(size: 20))
                    Text("\(Int(forecast.temperature.rounded()))°").font(.f1Digits(14)).foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.white.opacity(0.05))
                    .overlay(Circle().strokeBorder(Theme.cardStroke, lineWidth: 1)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Race forecast \(Int(forecast.temperature.rounded())) degrees, \(forecast.precipProbability)% chance of rain")
            }
        }
        .padding(.top, 8)
    }

    /// The drivers' standings in the Standings tab's rows; hidden in spoiler mode.
    private var table: some View {
        VStack(spacing: 16) {
            if let champion { ChampionCrown(champion: champion) }
            VStack(spacing: 0) {
                let leader = Double(standings.drivers.first?.points ?? "") ?? 0
                ForEach(standings.drivers) { entry in
                    FullDriverRow(entry: entry, leaderPoints: leader)
                        .opensProfile(.driver(entry.id))
                    if entry.id != standings.drivers.last?.id {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke, lineWidth: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .blur(radius: spoilerMode && !revealed ? 18 : 0)
        .allowsHitTesting(!(spoilerMode && !revealed))
        .overlay(alignment: .top) {
            if spoilerMode && !revealed {
                SpoilerShield(text: "Tap to reveal the standings").frame(height: 300)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if spoilerMode && !revealed { revealed = true } }
        .animation(.easeInOut(duration: 0.25), value: spoilerMode && !revealed)
        .padding(.bottom, 24)
    }
}
