#if DEBUG
import SwiftUI
import UIKit

// The world champion in the app, once the title is decided: drafts built
// from the real standings and the trophy clip (a still frame here; the real
// card plays it, muted and looping). `-DesignLab championA|B|C`, with
// `-ChampionFrames <folder>` holding square.png and tall.png.
//   A: a banner on the Countdown tab, above the race
//   B: a one-time full-screen moment the first time the app opens after it
//   C: a crown over the Standings page

struct ChampionDraft: View {
    let style: String
    @State private var standings = StandingsViewModel()
    @State private var race = RaceViewModel()

    var body: some View {
        Group {
            if let champion = standings.drivers.first {
                switch style {
                case "B": moment(champion)
                case "C": crown(champion)
                default: banner(champion)
                }
            } else {
                ProgressView().tint(Theme.accent)
            }
        }
        .task {
            async let a: Void = standings.load()
            async let b: Void = race.load()
            _ = await (a, b)
        }
    }

    private static func frame(_ name: String) -> Image {
        let dir = UserDefaults.standard.string(forKey: "ChampionFrames") ?? ""
        return UIImage(contentsOfFile: "\(dir)/\(name).png").map { Image(uiImage: $0) } ?? Image(systemName: "trophy.fill")
    }

    private static func season() -> String {
        String(Calendar.current.component(.year, from: .now))
    }

    // MARK: A: banner on the Countdown tab

    private func banner(_ c: DriverStanding) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderView(onInfo: {}).padding(.bottom, -6).zIndex(1)
                // text low in the card: the helmet hangs over its top
                ZStack(alignment: .bottomLeading) {
                    // the clip on the right, melting into the card on the left
                    Self.frame("square")
                        .resizable().scaledToFill()
                        .frame(width: 210, height: 206)
                        .clipped()
                        .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .leading, endPoint: .trailing))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 5) {
                        Label("\(Self.season()) WORLD CHAMPION", systemImage: "trophy.fill")
                            .font(.f1(11, weight: .heavy)).tracking(1.5)
                            .foregroundStyle(Medal.goldLight)
                        Text(c.driver.givenName.uppercased())
                            .font(.f1(15).italic()).foregroundStyle(.white.opacity(0.85))
                        Text(c.driver.familyName.uppercased())
                            .font(.f1(32).italic()).foregroundStyle(Medal.goldGradient)
                            .shadow(color: Medal.gold.opacity(0.6), radius: 10)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        teamLine(c)
                        Text("FINAL STANDINGS  ›")
                            .font(.f1(11, weight: .heavy)).tracking(1.5)
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 6)
                    }
                    .padding(18)
                }
                .frame(height: 206)
                .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Medal.goldGradient.opacity(0.75), lineWidth: 1.2))
                .shadow(color: Medal.gold.opacity(0.35), radius: 14)

                if let next = race.displayRace {
                    RaceHeroCarousel(season: race.season, race: next, dockActive: .constant(false), edge: .constant(.leading),
                                     nextId: race.nextRace?.id, onBack: {}) { _ in }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: B: the title moment, full screen, once

    private func moment(_ c: DriverStanding) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                Self.frame("tall")
                    .resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height * 0.84)
                    .clipped()
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0.62), .init(color: .clear, location: 0.97)],
                                         startPoint: .top, endPoint: .bottom))
                    .ignoresSafeArea(edges: .top)
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.black.opacity(0.4)))
                    }
                    Text(Self.season())
                        .font(.f1Digits(15)).tracking(8).foregroundStyle(Medal.goldLight)
                    Text("WORLD CHAMPION")
                        .font(.f1(30).italic()).foregroundStyle(Theme.chromeText)
                        .shadow(color: .black.opacity(0.6), radius: 8)
                    Spacer()
                    VStack(spacing: 8) {
                        Text("\(c.driver.givenName) \(c.driver.familyName)".uppercased())
                            .font(.f1(28).italic()).foregroundStyle(Medal.goldGradient)
                            .shadow(color: Medal.gold.opacity(0.6), radius: 12)
                            .multilineTextAlignment(.center)
                        teamLine(c)
                        HStack(spacing: 0) {
                            stat(c.wins, "WINS")
                            stat(c.points, "POINTS")
                            stat("R19", "CLINCHED")
                        }
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                        .padding(.top, 6)
                    }
                    Button {} label: { Text("SEE THE FINAL STANDINGS") }
                        .buttonStyle(GamePrimaryButtonStyle())
                        .padding(.top, 18)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: C: a crown over the Standings page

    private func crown(_ c: DriverStanding) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ResultsHubHeader(title: "STANDINGS", subtitle: "WORLD CHAMPIONSHIP")
                HStack(spacing: 14) {
                    Self.frame("square")
                        .resizable().scaledToFill()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Medal.goldGradient, lineWidth: 1.5))
                        .shadow(color: Medal.gold.opacity(0.5), radius: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Self.season()) WORLD CHAMPION")
                            .font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Medal.goldLight)
                        Text(c.driver.familyName.uppercased())
                            .font(.f1(26).italic()).foregroundStyle(Medal.goldGradient)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        teamLine(c)
                        Text("\(c.points) PTS · \(c.wins) WINS")
                            .font(.f1(13, weight: .heavy)).foregroundStyle(.white)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Medal.goldGradient.opacity(0.6), lineWidth: 1))
                .shadow(color: Medal.gold.opacity(0.25), radius: 14)

                VStack(spacing: 0) {
                    let leader = Double(c.points) ?? 0
                    ForEach(standings.drivers.prefix(6)) { entry in
                        FullDriverRow(entry: entry, leaderPoints: leader)
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Pieces

    private func teamLine(_ c: DriverStanding) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5).fill(Theme.teamColor(c.teamId)).frame(width: 3, height: 13)
            Text(c.teamName).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dimText)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.f1Digits(22)).foregroundStyle(.white)
            Text(label).font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
