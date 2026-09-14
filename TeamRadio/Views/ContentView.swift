import SwiftUI

struct ContentView: View {
    @State private var model = RaceViewModel()
    @State private var showAbout = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.accent.opacity(0.18), .clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.live.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 460
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.violet.opacity(0.08), .clear],
                center: .leading, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            switch model.phase {
            case .loading:
                LoadingView()
            case .failed(let message):
                ErrorView(message: message) {
                    Task { await model.load() }
                }
            case .loaded:
                loadedContent
            }
        }
        .task {
            await model.load()
            // Keep scheduled alerts in sync with any calendar changes.
            await NotificationManager.reschedule(season: model.season)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }

    private var loadedContent: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderView(onInfo: { showAbout = true })
                    .padding(.bottom, -6)

                if let race = model.nextRace {
                    LiveSessionBanner(race: race)

                    RaceHeroView(race: race)

                    CountdownView(race: race)

                    WeekendScheduleView(race: race, weather: model.weather)

                    SessionAlertsCard(season: model.season)

                    if let map = model.trackMap {
                        TrackSectionView(map: map, circuit: race.circuit)
                            .id("trackSection")
                    }
                } else {
                    SeasonOverBanner()
                }

                if !model.standings.isEmpty {
                    StandingsView(standings: model.standings)
                }

                if !model.season.isEmpty {
                    SeasonView(season: model.season, nextRaceId: model.nextRace?.id)
                }

                FooterView()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable { await model.load() }
        .task {
            if UserDefaults.standard.bool(forKey: "ScrollTrack") {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { proxy.scrollTo("trackSection", anchor: .top) }
            }
        }
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    var onInfo: (() -> Void)? = nil

    var body: some View {
        ZStack {
            HStack {
                // Screen blend melts the wordmark's black ground into the
                // page gradient, leaving only the glowing letters.
                Image("HeaderWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .blendMode(.screen)
                    .accessibilityLabel("Team Radio")

                Spacer()

                if let onInfo {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.dimText)
                    }
                    .buttonStyle(.plain)
                }
            }

            // The helmet (transparent PNG) sits centre stage and hangs over
            // the top edge of the race card below.
            Image("HeaderHelmet")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .shadow(color: Theme.accent.opacity(0.35), radius: 24, y: 8)
                .padding(.top, -6)
                .padding(.bottom, -72)
                .accessibilityHidden(true)
        }
        .padding(.top, 4)
        .zIndex(1)
    }
}

// MARK: - Loading / error / empty states

struct LoadingView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            Text("🏁")
                .font(.system(size: 44))
                .scaleEffect(pulse ? 1.15 : 0.9)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
            Text("WARMING UP TYRES…")
                .font(.f1(15).italic())
                .tracking(3)
                .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.violet, Theme.live],
                                                startPoint: .leading, endPoint: .trailing))
        }
        .onAppear { pulse = true }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("🔴 RED FLAG")
                .font(.f1(24).italic())
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Text("RESTART RACE")
                    .font(.f1(15).italic())
                    .tracking(2)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(32)
    }
}

struct SeasonOverBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🏆 SEASON COMPLETE")
                .font(.f1(24).italic())
                .foregroundStyle(.white)
            Text("No more races on the current calendar. See you next season!")
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Toggle for on-device session alerts: one notification 15 minutes before
/// every upcoming session of the season.
struct SessionAlertsCard: View {
    let season: [Race]

    @State private var enabled = NotificationManager.isEnabled

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: enabled ? "bell.badge.fill" : "bell.slash")
                .font(.system(size: 20))
                .foregroundStyle(enabled ? Theme.accent : Theme.dimText)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("SESSION ALERTS")
                    .font(.f1(15).italic())
                    .foregroundStyle(.white)
                Text("Get notified 15 minutes before every session")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dimText)
            }

            Spacer()

            Toggle("", isOn: $enabled)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Theme.glassStroke, lineWidth: 1)
                )
        )
        .onChange(of: enabled) { old, wantsOn in
            guard old != wantsOn else { return }
            Task {
                let result = await NotificationManager.setEnabled(wantsOn, season: season)
                // Flips back if the user denied the permission prompt.
                if result != wantsOn { enabled = result }
            }
        }
    }
}

/// Impossible-to-miss banner shown at the very top while a session is on track.
struct LiveSessionBanner: View {
    let race: Race

    @State private var pulse = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let live = race.sessions.first {
                $0.date <= now && now < $0.date.addingTimeInterval($0.kind.expectedDuration)
            }

            if let live {
                HStack(spacing: 12) {
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .white, radius: pulse ? 10 : 2)
                        .scaleEffect(pulse ? 1.25 : 0.85)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(live.kind.rawValue.uppercased()) · LIVE NOW")
                            .font(.f1(20).italic())
                            .foregroundStyle(.white)
                        Text("\(Flags.emoji(for: race.circuit.location.country)) \(race.raceName)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        SessionClock(start: live.date)
                            .font(.f1Digits(19))
                            .foregroundStyle(.white)
                        Text("SESSION TIME")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Theme.live, Color(red: 0.55, green: 0.12, blue: 0.07)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .shadow(color: Theme.live.opacity(0.55), radius: 18, y: 4)
                )
                .onAppear { pulse = true }
            }
        }
    }
}

struct FooterView: View {
    var body: some View {
        Text("Data: Jolpica F1 API · Unofficial app, not associated with Formula 1")
            .font(.caption2)
            .foregroundStyle(Theme.faintText)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}

#Preview {
    ContentView()
}
