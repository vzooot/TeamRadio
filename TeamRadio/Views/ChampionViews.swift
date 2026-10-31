import AVFoundation
import SwiftUI

/// The title moment: the trophy and the new world champion, full screen,
/// once per season the first time the app opens after the title is settled
/// (approved draft B). Side by side on wide screens.
struct ChampionMoment: View {
    let champion: Champion
    /// "See the final standings".
    let onStandings: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                if geo.size.width > geo.size.height {
                    HStack(spacing: 28) {
                        LoopingClip(name: "champion-square")
                            .frame(width: geo.size.height, height: geo.size.height)
                            .mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                                 startPoint: .leading, endPoint: .trailing))
                        VStack(spacing: 0) {
                            heading
                            Spacer(minLength: 16)
                            details
                        }
                        .padding(.vertical, 24)
                        .padding(.trailing, 28)
                    }
                    .ignoresSafeArea(edges: .leading)
                } else {
                    LoopingClip(name: "champion-tall")
                        .frame(width: geo.size.width, height: geo.size.height * 0.84)
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0.62), .init(color: .clear, location: 0.97)],
                                             startPoint: .top, endPoint: .bottom))
                        .ignoresSafeArea(edges: .top)
                    VStack(spacing: 0) {
                        heading
                            .padding(.top, 34)
                        Spacer()
                        details
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            .accessibilityLabel("Close")
            .padding(16)
        }
        .preferredColorScheme(.dark)
    }

    private var heading: some View {
        VStack(spacing: 2) {
            Text(champion.season)
                .font(.f1Digits(15)).tracking(8).foregroundStyle(Medal.goldLight)
            Text("WORLD CHAMPION")
                .font(.f1(30).italic()).foregroundStyle(Theme.chromeText)
                .shadow(color: .black.opacity(0.6), radius: 8)
        }
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        let s = champion.standing
        return VStack(spacing: 8) {
            Text("\(s.driver.givenName) \(s.driver.familyName)".uppercased())
                .font(.f1(28).italic()).foregroundStyle(Medal.goldGradient)
                .shadow(color: Medal.gold.opacity(0.6), radius: 12)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            ChampionTeamLine(standing: s)
            HStack(spacing: 0) {
                stat(s.wins, "WINS")
                stat(s.points, "POINTS")
                stat("+\(champion.ahead)", "AHEAD")
            }
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
            .padding(.top, 6)
            Button {
                dismiss()
                onStandings()
            } label: { Text("SEE THE FINAL STANDINGS") }
                .buttonStyle(GamePrimaryButtonStyle())
                .padding(.top, 12)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.f1Digits(22)).foregroundStyle(.white)
            Text(label).font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The champion over the Standings page for the rest of the season
/// (approved draft C); opens the driver's profile.
struct ChampionCrown: View {
    let champion: Champion

    var body: some View {
        let s = champion.standing
        HStack(spacing: 14) {
            LoopingClip(name: "champion-square")
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Medal.goldGradient, lineWidth: 1.5))
                .shadow(color: Medal.gold.opacity(0.5), radius: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(champion.season) WORLD CHAMPION")
                    .font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Medal.goldLight)
                Text(s.driver.familyName.uppercased())
                    .font(.f1(26).italic()).foregroundStyle(Medal.goldGradient)
                    .lineLimit(1).minimumScaleFactor(0.6)
                ChampionTeamLine(standing: s)
                Text("\(s.points) PTS · \(s.wins) WINS")
                    .font(.f1(13, weight: .heavy)).foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Medal.goldGradient.opacity(0.6), lineWidth: 1))
        .shadow(color: Medal.gold.opacity(0.25), radius: 14)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .opensProfile(.driver(s.id))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(champion.season) World Champion, \(s.driver.givenName) \(s.driver.familyName), \(s.teamName), \(s.points) points, \(s.wins) wins")
        .accessibilityAddTraits(.isButton)
    }
}

private struct ChampionTeamLine: View {
    let standing: DriverStanding

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5).fill(Theme.teamColor(standing.teamId)).frame(width: 3, height: 13)
            Text(standing.teamName).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dimText)
        }
    }
}

/// A bundled clip (no sound) playing on a loop and filling its frame. With
/// Reduce Motion on, it holds still on the lit podium near the end.
struct LoopingClip: UIViewRepresentable {
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.isUserInteractionEnabled = false
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return view }
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        if reduceMotion {
            player.insert(AVPlayerItem(url: url), after: nil)
            player.seek(to: CMTime(seconds: 9.6, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            view.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            player.play()
        }
        view.playerLayer?.player = player
        view.playerLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {}

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.playerLayer?.player?.pause()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
        var looper: AVPlayerLooper?
    }
}
