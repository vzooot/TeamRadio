#if DEBUG
import SwiftUI

/// Debug-only design drafts, rendered for review before anything is built.
/// Launch with `-DesignLab <id>`; nothing here ships.
struct DesignLab: View {
    let id: String

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch id {
            case "gameA": GameDraftA()
            case "gameB": GameDraftB()
            case "gameC": GameDraftC()
            case "cards1": CardsDraft1()
            case "cards2": CardsDraft2()
            default: Text("unknown draft \(id)").foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Shared bits

private struct DraftHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("REACTION TEST").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.live)
                Text("LIGHTS OUT").font(.f1(28).italic()).foregroundStyle(Theme.chromeText)
            }
            Spacer()
            Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.dimText)
                .frame(width: 34, height: 34).background(Circle().fill(Color.white.opacity(0.06)))
        }
    }
}

/// Neon frame like the countdown tiles.
private struct NeonFrame: ViewModifier {
    var tint: Color
    func body(content: Content) -> some View {
        content.background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Color(white: 0.03), Color(white: 0.09)], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
                RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.9), lineWidth: 3).blur(radius: 5)
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.95), tint, tint.opacity(0.8)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.2)
            }
        )
        .shadow(color: tint.opacity(0.45), radius: 12)
    }
}

// MARK: - Game A: countdown card look, LED board + neon timer

private struct GameDraftA: View {
    var body: some View {
        VStack(spacing: 26) {
            DraftHeader()
            Spacer()
            VStack(spacing: 18) {
                DotMatrixBoard(litLights: 3).alignedToContent().allowsHitTesting(false)
                VStack(spacing: 4) {
                    Text("0.214").font(.f1Digits(70)).foregroundStyle(Theme.chromeText)
                        .shadow(color: Theme.accent.opacity(0.6), radius: 10)
                    Text("SECONDS").font(.f1(10, weight: .bold)).tracking(2).foregroundStyle(Theme.accent)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .modifier(NeonFrame(tint: Theme.accent))
            }
            .padding(18)
            .background(CarbonFiber().clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.glassStroke, lineWidth: 1))
                .trioGlow(cornerRadius: 22))
            VStack(spacing: 6) {
                Text("F1-READY REFLEXES").font(.f1(22).italic()).foregroundStyle(.white)
                Text("PERSONAL BEST 0.198 · #4 THIS WEEK").font(.f1(11, weight: .bold)).tracking(1.5).foregroundStyle(Theme.dimText)
            }
            Spacer()
            Text("SHARE YOUR TIME").font(.f1(15).italic()).tracking(2).foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentGradient))
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }
}

// MARK: - Game B: broadcast style (F1 TV graphics)

private struct GameDraftB: View {
    var body: some View {
        VStack(spacing: 0) {
            DraftHeader().padding(.horizontal, 20).padding(.top, 16)
            Spacer()
            // full-width board, no card: the lights fill the screen
            DotMatrixBoard(litLights: 5).aspectRatio(26 / 6.2, contentMode: .fit)
                .allowsHitTesting(false)
                .padding(.horizontal, 4)
            Text("WAIT FOR LIGHTS OUT").font(.f1(13, weight: .bold)).tracking(4).foregroundStyle(Theme.live)
                .padding(.top, 18)
            Spacer()
            // timing-tower style result box
            HStack(spacing: 0) {
                Rectangle().fill(Theme.live).frame(width: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("REACTION").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Color.black.opacity(0.6))
                    Text("0.000").font(.f1Digits(48)).foregroundStyle(.black)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("BEST").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Color.black.opacity(0.6))
                    Text("0.198").font(.f1Digits(24)).foregroundStyle(Color(red: 0.5, green: 0.2, blue: 0.9))
                }
                .padding(.horizontal, 16)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Game C: minimal, five big lights and a huge clock

private struct GameDraftC: View {
    var body: some View {
        VStack(spacing: 0) {
            DraftHeader().padding(.horizontal, 20).padding(.top, 16)
            Spacer()
            HStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { i in
                    let on = i < 4
                    Circle()
                        .fill(on ? AnyShapeStyle(RadialGradient(colors: [Color(red: 1, green: 0.55, blue: 0.4), Theme.live, Color(red: 0.55, green: 0.08, blue: 0.02)],
                                                               center: .init(x: 0.4, y: 0.35), startRadius: 2, endRadius: 34))
                              : AnyShapeStyle(Color(white: 0.08)))
                        .overlay(Circle().strokeBorder(on ? Color.white.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1))
                        .frame(width: 56, height: 56)
                        .shadow(color: on ? Theme.live.opacity(0.9) : .clear, radius: 18)
                }
            }
            Spacer().frame(height: 60)
            Text("0.000").font(.system(size: 104, weight: .thin, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
            Text("TAP WHEN THE LIGHTS GO OUT").font(.f1(12, weight: .bold)).tracking(3).foregroundStyle(Theme.dimText)
            Spacer()
            Text("BEST 0.198").font(.f1(14, weight: .bold)).tracking(2).foregroundStyle(Theme.accent).padding(.bottom, 40)
        }
    }
}

// MARK: - Countdown tab cards

/// Set 1: bold, filled cards in the "Call in your crew" family.
private struct CardsDraft1: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // driver of the day: gold filled
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "star.fill").font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.4))
                            .frame(width: 50, height: 50).background(Circle().fill(Color.black.opacity(0.85)))
                        Spacer()
                        Text("R17 SINGAPORE").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Color.black.opacity(0.6))
                    }
                    Text("DRIVER OF\nTHE DAY").font(.f1(34)).foregroundStyle(Theme.onAccent)
                    Text("Who impressed you most? Vote and see what the fans picked.")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.onAccent.opacity(0.8))
                    Text("VOTE NOW").font(.f1(14).italic()).tracking(2).foregroundStyle(Color(red: 1, green: 0.85, blue: 0.4))
                        .padding(.horizontal, 18).padding(.vertical, 10).background(Capsule().fill(Color.black.opacity(0.85)))
                }
                .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.35), Color(red: 1, green: 0.6, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)))

                // lights out: red glow on carbon with the LED board
                VStack(alignment: .leading, spacing: 12) {
                    DotMatrixBoard(litLights: 5).alignedToContent().allowsHitTesting(false)
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LIGHTS OUT").font(.f1(30).italic()).foregroundStyle(Theme.chromeText)
                            Text("Best 0.198 · #4 this week").font(.system(size: 13)).foregroundStyle(Theme.dimText)
                        }
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                            .frame(width: 52, height: 52).background(Circle().fill(Theme.liveGradient))
                            .shadow(color: Theme.live.opacity(0.7), radius: 10)
                    }
                }
                .padding(18)
                .background(ZStack {
                    CarbonFiber()
                    RadialGradient(colors: [Theme.live.opacity(0.35), .clear], center: .top, startRadius: 0, endRadius: 300)
                }.clipShape(RoundedRectangle(cornerRadius: 20)))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.live.opacity(0.5), lineWidth: 1))

                emilyCard
            }
            .padding(16).padding(.top, 50)
        }
    }

    var emilyCard: some View {
        ZStack(alignment: .leading) {
            Image("EmilyAvatar").resizable().scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .leading, endPoint: .trailing))
            LinearGradient(colors: [Color(red: 0.12, green: 0.08, blue: 0.3), Color(red: 0.12, green: 0.08, blue: 0.3).opacity(0.85), .clear],
                           startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 11, weight: .bold))
                    Text("TEAM RADIO · AI").font(.f1(11, weight: .bold)).tracking(2)
                }.foregroundStyle(Theme.accent)
                Text("ASK THE\nRACE ENGINEER").font(.f1(26).italic()).foregroundStyle(.white)
                Text("ASK EMILY →").font(.f1(13).italic()).tracking(1.5).foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(Theme.accentGradient))
            }
            .padding(20)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.violet.opacity(0.6), lineWidth: 1))
    }
}

/// Set 2: darker, editorial: photo, big type, thin neon rims.
private struct CardsDraft2: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // driver of the day: dark with gold rim and big podium-style top 3
                VStack(alignment: .leading, spacing: 14) {
                    Text("FAN VOTE · DRIVER OF THE DAY").font(.f1(11, weight: .bold)).tracking(2)
                        .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.3))
                    HStack(alignment: .bottom, spacing: 10) {
                        bar("LEC", 24, 70, .red)
                        bar("ANT", 52, 110, Color(red: 0, green: 0.82, blue: 0.75))
                        bar("VER", 18, 55, Color(red: 0.25, green: 0.25, blue: 0.85))
                    }
                    Text("Your vote: ANT · 412 votes").font(.system(size: 12)).foregroundStyle(Theme.dimText)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient(colors: [Color(red: 1, green: 0.8, blue: 0.3), Color(red: 1, green: 0.5, blue: 0.1).opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))

                // lights out: huge red numerals as the visual
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REACTION TEST").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.live)
                        Text("LIGHTS\nOUT").font(.f1(34).italic()).foregroundStyle(.white)
                        Text("Can you beat 0.200?").font(.system(size: 13)).foregroundStyle(Theme.dimText)
                    }
                    Spacer()
                    Text("0.198").font(.f1Digits(44)).foregroundStyle(Theme.liveGradient)
                        .shadow(color: Theme.live.opacity(0.7), radius: 14)
                }
                .padding(20)
                .background(ZStack {
                    Color.black
                    LinearGradient(colors: [Theme.live.opacity(0.28), .clear], startPoint: .trailing, endPoint: .leading)
                }.clipShape(RoundedRectangle(cornerRadius: 20)))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.live.opacity(0.45), lineWidth: 1))

                // emily: chat-bubble style preview
                HStack(alignment: .top, spacing: 12) {
                    Image("EmilyAvatar").resizable().scaledToFill().frame(width: 58, height: 58).clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 2)).shadow(color: Theme.accent.opacity(0.5), radius: 8)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EMILY · RACE ENGINEER").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.accent)
                        Text("\"Box, box. Ask me anything about strategy, tyres or the standings. Copy?\"")
                            .font(.system(size: 15, weight: .medium).italic()).foregroundStyle(.white)
                            .padding(12).background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(0.1)))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accent.opacity(0.35)))
                        Text("Tap to talk on the radio →").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent)
                    }
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
            }
            .padding(16).padding(.top, 50)
        }
    }

    func bar(_ code: String, _ pct: Int, _ h: CGFloat, _ c: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(pct)%").font(.f1Digits(16)).foregroundStyle(.white)
            RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [c, c.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                .frame(height: h)
            Text(code).font(.f1(14)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
