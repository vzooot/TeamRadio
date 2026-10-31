#if DEBUG
import SwiftUI

// iPhone Duo unfolded (a wide screen, about 950 × 670 pt): drafts of the
// Countdown tab built from the app's real cards and live race data
// (`-DesignLab duoA|duoB|duoC`), and Lights Out on the wide screen
// (`-DesignLab duoLights`).

struct DuoDraft: View {
    let style: String
    @State private var model = RaceViewModel()

    var body: some View {
        Group {
            if let race = model.displayRace {
                switch style {
                case "B": dashboard(race)
                case "C": companion(race)
                default: twoColumns(race)
                }
            } else {
                ProgressView().tint(Theme.accent)
            }
        }
        .task { await model.load() }
    }

    private func hero(_ race: Race) -> some View {
        RaceHeroCarousel(season: model.season, race: race, dockActive: .constant(false), edge: .constant(.leading),
                         nextId: model.nextRace?.id, onBack: {}) { _ in }
    }

    @ViewBuilder
    private func track(_ race: Race) -> some View {
        if let map = model.trackMap { TrackSectionView(map: map, circuit: race.circuit) } else { TrackPlaceholder() }
    }

    // A: two columns. Left: the race and its countdown, always in view.
    // Right: everything else, scrolling.
    private func twoColumns(_ race: Race) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HeaderView(onInfo: {}).padding(.bottom, -6).zIndex(1)
                hero(race)
                CountdownView(race: race)
                Spacer(minLength: 0)
            }
            .frame(width: 430)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    EmilyBar(onTap: {})
                    WeekendScheduleView(race: race, weather: model.weather, weatherLoading: model.extrasLoading)
                    track(race)
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    // B: a dashboard. The race and the countdown side by side across the
    // top, then the weekend, the circuit and Emily in three columns.
    private func dashboard(_ race: Race) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeaderView(onInfo: {}).padding(.bottom, -6).zIndex(1)
                HStack(alignment: .top, spacing: 16) {
                    hero(race).frame(maxWidth: .infinity)
                    CountdownView(race: race).frame(maxWidth: .infinity)
                }
                EmilyBar(onTap: {})
                HStack(alignment: .top, spacing: 16) {
                    WeekendScheduleView(race: race, weather: model.weather, weatherLoading: model.extrasLoading)
                        .frame(maxWidth: .infinity)
                    track(race).frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
    }

    // C: the phone column as it is, plus a second pane beside it that keeps
    // the live race company: the circuit and the weekend, always open.
    private func companion(_ race: Race) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HeaderView(onInfo: {}).padding(.bottom, -6).zIndex(1)
                    hero(race)
                    CountdownView(race: race)
                    EmilyBar(onTap: {})
                }
                .padding(.horizontal, 16)
            }
            .frame(width: 420)
            Rectangle().fill(Theme.glassStroke).frame(width: 1).opacity(0.6)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        TrioSlashes(height: 18)
                        Text("RACE COMPANION").font(.f1(20).italic()).foregroundStyle(Theme.chromeText)
                    }
                    .padding(.top, 14)
                    track(race)
                    WeekendScheduleView(race: race, weather: model.weather, weatherLoading: model.extrasLoading)
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// Lights Out on the wide screen: the lights and the clock on the left, the
/// week's board and the start button on the right; nothing cut off.
struct DuoLightsDraft: View {
    var body: some View {
        HStack(spacing: 28) {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REACTION TEST").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.live)
                        Text("LIGHTS OUT").font(.f1(28).italic()).foregroundStyle(Theme.chromeText)
                    }
                    Spacer()
                }
                VStack(spacing: 16) {
                    DotMatrixBoard(litLights: 3).alignedToContent()
                    Text("0.000")
                        .font(.f1Digits(60)).foregroundStyle(Theme.chromeText)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.accent, lineWidth: 2.2))
                        .shadow(color: Theme.accent.opacity(0.5), radius: 12)
                }
                .padding(18)
                .background(CarbonFiber().clipShape(RoundedRectangle(cornerRadius: 22)).trioGlow(cornerRadius: 22))
                VStack(spacing: 6) {
                    Text("HOLD TO START").font(.f1(24).italic()).foregroundStyle(.white)
                    Text("Let go the moment the lights go out.").font(.system(size: 14)).foregroundStyle(Theme.dimText)
                }
            }
            .frame(maxWidth: 470)
            VStack(spacing: 26) {
                ArcadeBoardCard(game: .lightsOut, standing: nil, loaded: false, hasName: true) {}
                ZStack {
                    Circle().fill(RadialGradient(colors: [Color(white: 0.16), Color(white: 0.04)], center: .top, startRadius: 0, endRadius: 160))
                    Circle().strokeBorder(Theme.accent, lineWidth: 5).shadow(color: Theme.accent.opacity(0.9), radius: 6).shadow(color: Theme.accent.opacity(0.6), radius: 16)
                    VStack(spacing: 2) {
                        Text("HOLD").font(.f1(26).italic())
                        Text("TO START").font(.f1(9, weight: .heavy)).tracking(1.5)
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: 158, height: 158)
            }
            .frame(maxWidth: 380)
        }
        .padding(24)
    }
}
#endif
