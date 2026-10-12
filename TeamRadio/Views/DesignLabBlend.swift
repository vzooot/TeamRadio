#if DEBUG
import SceneKit
import SwiftUI

// Debug-only draft: the Countdown feature cards as a blend of liquid glass,
// telemetry data and the app's own LED board, in the current app palette.
// Nothing here ships.

private let led = Color(red: 1, green: 0.42, blue: 0.12)        // the board's amber-red LEDs
private let mercedes = Color(red: 0, green: 0.85, blue: 0.75)
private let papaya = Color(red: 1, green: 0.53, blue: 0)
private let hair = Color.white.opacity(0.12)
private let reactionHistory: [Double] = [0.312, 0.268, 0.290, 0.241, 0.255, 0.226, 0.233, 0.211, 0.204, 0.198]

// LED type: the shipping `LEDText` in Views/Game/GameZone.swift.

// MARK: - Pieces

private func mono(_ s: String, _ c: Color = Theme.dimText, _ size: CGFloat = 10) -> some View {
    Text(s).font(.system(size: size, weight: .medium, design: .monospaced)).tracking(1.2).foregroundStyle(c)
}

/// Section rule: number, name, meta, and a tick-marked hairline.
private struct SectionRule: View {
    let number: String
    let name: String
    let meta: String
    var metaColor: Color = Theme.dimText

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                mono("\(number) / \(name)")
                Spacer()
                mono(meta, metaColor)
            }
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(x: 0, y: size.height - 0.5, width: size.width, height: 0.5)), with: .color(hair))
                var x: CGFloat = 0, i = 0
                while x <= size.width {
                    let major = i % 10 == 0
                    ctx.fill(Path(CGRect(x: x, y: size.height - (major ? 5 : 2.5), width: 0.5, height: major ? 5 : 2.5)),
                             with: .color(major ? Theme.dimText : hair))
                    x += 6; i += 1
                }
            }
            .frame(height: 5)
        }
    }
}

private extension View {
    /// Liquid glass panel with a coloured light behind it for the glass to bend.
    func glassPanel(_ shape: some Shape, light: Color, lightOffset: CGSize = .zero, tint: Color? = nil) -> some View {
        self
            .modifier(GlassSurface(shape: AnyShape(shape), tint: tint))
            .background(
                Ellipse().fill(light).frame(width: 220, height: 140).blur(radius: 60).opacity(0.55)
                    .offset(lightOffset)
            )
    }
}

private struct GlassSurface: ViewModifier {
    let shape: AnyShape
    let tint: Color?
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Draft

struct BlendDraft: View {
    /// Just the sections, for use inside the full-screen draft.
    var embedded = false
    /// The lighter step: one "game zone" rule over all four cards.
    var gameZone = false

    /// Debug hook: show a game-zone draft in the real Countdown tab
    /// (`-GameZoneDraft blend|a|b|c`).
    static var gameZoneInApp: Bool { UserDefaults.standard.string(forKey: "GameZoneDraft") != nil }

    var body: some View {
        if embedded {
            sections
        } else {
            ScrollView {
                sections
                    .padding(.horizontal, 16)
                    .padding(.top, 64)
            }
            .background(Theme.background)
        }
    }

    @ViewBuilder
    private var sections: some View {
        if gameZone {
            VStack(alignment: .leading, spacing: 12) {
                SectionRule(number: "R18", name: "GAME ZONE", meta: "LOCKS SAT 23:00", metaColor: Theme.accent)
                    .padding(.bottom, 2)
                picks
                HStack(spacing: 12) { dotd; lights }
                emily
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                SectionRule(number: "01", name: "PREDICTION GAME", meta: "LOCKS SAT 23:00", metaColor: Theme.accent)
                picks
                SectionRule(number: "02", name: "FAN VOTE · REACTION", meta: "LIVE", metaColor: Theme.live)
                    .padding(.top, 10)
                HStack(spacing: 12) { dotd; lights }
                SectionRule(number: "03", name: "TEAM RADIO", meta: "AI ONLINE", metaColor: Theme.accent)
                    .padding(.top, 10)
                emily
            }
        }
    }

    // Picks: glass panel, telemetry rows, segmented progress, glass CTA.
    private var picks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MAKE YOUR PICKS").font(.f1(26).italic()).foregroundStyle(Theme.chromeText)
            VStack(spacing: 0) {
                row("POLE", "NOR", "NORRIS", papaya, ai: "NOR")
                row("WINNER", "PIA", "PIASTRI", papaya, ai: "NOR")
                row("FAST LAP", "—", "TAP TO PICK", .clear, ai: "VER")
            }
            HStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { i in
                    Capsule().fill(i < 3 ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(hair)).frame(height: 3)
                }
            }
            HStack {
                mono("3 OF 6 · BEAT THE AI", Theme.dimText)
                Spacer()
                Text("FINISH →").font(.f1(14).italic()).tracking(1.5).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .modifier(GlassSurface(shape: AnyShape(Capsule()), tint: Theme.accent.opacity(0.55)))
            }
        }
        .padding(20)
        .glassPanel(RoundedRectangle(cornerRadius: 28), light: Theme.accent, lightOffset: CGSize(width: -90, height: -30))
    }

    private func row(_ slot: String, _ code: String, _ name: String, _ team: Color, ai: String) -> some View {
        HStack(spacing: 10) {
            mono(slot, Theme.dimText, 10).frame(width: 64, alignment: .leading)
            Capsule().fill(team).frame(width: 3, height: 18)
            Text(code).font(.f1(19)).foregroundStyle(.white).frame(width: 50, alignment: .leading)
            mono(name, Theme.faintText)
            Spacer()
            mono("AI \(ai)", Theme.faintText)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(hair).frame(height: 0.5) }
    }

    // Driver of the day: LED code in team colour, data bars.
    private var dotd: some View {
        VStack(alignment: .leading, spacing: 12) {
            mono("DRIVER OF THE DAY", Theme.dimText)
            LEDText(text: "ANT", pitch: 6, color: mercedes)
            mono("52% · 412 VOTES", .white, 11)
            VStack(spacing: 5) {
                bar(0.52, mercedes)
                bar(0.24, .white.opacity(0.45))
                bar(0.18, .white.opacity(0.3))
            }
            Text("VOTE →").font(.f1(13).italic()).tracking(1.5).foregroundStyle(Theme.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(RoundedRectangle(cornerRadius: 24), light: mercedes, lightOffset: CGSize(width: -30, height: 20))
    }

    private func bar(_ pct: Double, _ color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(hair)
                Capsule().fill(color).frame(width: geo.size.width * pct)
            }
        }
        .frame(height: 3)
    }

    // Lights out: LED best time, reaction trace, the five lights.
    private var lights: some View {
        VStack(alignment: .leading, spacing: 12) {
            mono("LIGHTS OUT · BEST", Theme.dimText)
            LEDText(text: "0.198", pitch: 5.4)
            mono("P4 THIS WEEK", .white, 11)
            trace.frame(height: 30)
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle().fill(led).frame(width: 9, height: 9).shadow(color: led, radius: 4)
                }
                Spacer()
                Image(systemName: "play.fill").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.live)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(RoundedRectangle(cornerRadius: 24), light: Theme.live, lightOffset: CGSize(width: 30, height: 20))
    }

    private var trace: some View {
        Canvas { ctx, size in
            let lo = 0.18, hi = 0.33
            let pts = reactionHistory.enumerated().map { i, v in
                CGPoint(x: size.width * CGFloat(i) / CGFloat(reactionHistory.count - 1),
                        y: size.height * CGFloat((v - lo) / (hi - lo)))
            }
            var line = Path()
            line.addLines(pts)
            ctx.stroke(line, with: .color(Theme.accent), lineWidth: 1.4)
            if let last = pts.last {
                ctx.fill(Path(ellipseIn: CGRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6)), with: .color(Theme.accent))
            }
        }
        .shadow(color: Theme.accent.opacity(0.6), radius: 3)
    }

    // Emily: glass capsule with a live waveform and the app's cyan CTA.
    private var emily: some View {
        HStack(spacing: 12) {
            Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
                .frame(width: 48, height: 48).clipShape(Circle())
                .shadow(color: Theme.accent.opacity(0.8), radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text("ASK EMILY").font(.f1(17).italic()).foregroundStyle(Theme.chromeText)
                mono("AI RACE ENGINEER", Theme.dimText, 9)
            }
            Canvas { ctx, size in
                var p = Path()
                for x in stride(from: 0, through: size.width, by: 1) {
                    let env = sin(Double(x / size.width) * .pi)
                    let y = size.height / 2 + CGFloat((sin(Double(x) * 0.35) * 0.6 + sin(Double(x) * 0.11) * 0.4) * env) * size.height * 0.45
                    x == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                }
                ctx.stroke(p, with: .color(Theme.accent), lineWidth: 1.2)
            }
            .frame(height: 28)
            Image(systemName: "mic.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.onAccent)
                .frame(width: 46, height: 46).background(Circle().fill(Theme.accentGradient))
                .shadow(color: Theme.accent.opacity(0.6), radius: 10)
        }
        .padding(8).padding(.leading, 2)
        .glassPanel(Capsule(), light: Theme.violet, lightOffset: CGSize(width: 0, height: 10))
    }
}

// MARK: - Game zone variants in the app's colour code

/// The four new-feature cards as one "Game Zone", in three variants that
/// follow the app's own vocabulary: trio slashes before chrome titles, card
/// panels with the trio glow, FP1-style chips, the violet countdown chip and
/// the cyan "next" stripe.
struct GameZoneDraft: View {
    let variant: String

    var body: some View {
        switch variant {
        case "a": ZoneSheet()
        case "b": ZoneSectors()
        case "c": ZoneGlass()
        case "d": ZoneLiquidTiles()
        case "e": ZoneFloating()
        case "r1": ZoneCockpit()
        case "r2": ZoneHero()
        case "r3": ZoneTimingSheet()
        case "x": ZoneMixed(result: .hero, bold: .dotd)
        case "y": ZoneMixed(result: .sheet, bold: .lights)
        case "z": ZoneMixed(result: .cockpit, bold: .emily)
        case "w": ZoneMixed(result: .hero, bold: .dotd, photoLights: true, waveEmily: true)
        case "v": ZoneCompact(scored: true)
        case "u": ZoneCompact(scored: false)
        default: BlendDraft(embedded: true, gameZone: true)
        }
    }
}

/// The app's grey session chip ("FP1"), optionally filled with the accent.
private func sessionChip(_ s: String, filled: Bool = false, width: CGFloat = 56) -> some View {
    Text(s)
        .font(.f1(12).italic())
        .foregroundStyle(filled ? .white : Theme.dimText)
        .frame(width: width, height: 26)
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(filled ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06))))
}

/// The violet outlined countdown chip from the race-weekend list.
private func countdownChip(_ s: String) -> some View {
    Text(s)
        .font(.f1(10, weight: .heavy).monospacedDigit()).tracking(1)
        .foregroundStyle(Theme.violet)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.violet.opacity(0.65), lineWidth: 1))
}

/// Card panel exactly like the race-weekend list.
private extension View {
    func appCard(_ radius: CGFloat = 18) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.glassStroke, lineWidth: 1))
                .trioGlow(cornerRadius: radius, opacity: 0.4)
        )
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

private func smallCaps(_ s: String, _ c: Color = Theme.dimText) -> some View {
    Text(s).font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(c)
}

// A: one list, like the race-weekend timetable. Each feature is a row.
private struct ZoneSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("GAME ZONE")
            VStack(spacing: 0) {
                row(chip: "PICK", title: "PREDICTIONS", next: true) {
                    Text("Pole NOR · Winner PIA · 3 of 6").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
                } trailing: {
                    VStack(alignment: .trailing, spacing: 6) {
                        countdownChip("LOCKS 12D 12H")
                        segments
                    }
                }
                divider
                row(chip: "VOTE", title: "DRIVER OF THE DAY") {
                    Text("Singapore · 412 votes").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
                } trailing: {
                    VStack(alignment: .trailing, spacing: 4) {
                        LEDText(text: "ANT", pitch: 3.4, color: mercedes)
                        smallCaps("52%", mercedes)
                    }
                }
                divider
                row(chip: "START", title: "LIGHTS OUT") {
                    Text("Reaction test · P4 this week").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
                } trailing: {
                    VStack(alignment: .trailing, spacing: 4) {
                        LEDText(text: "0.198", pitch: 3.4)
                        smallCaps("BEST", Theme.dimText)
                    }
                }
                divider
                row(chip: "AI", title: "ASK EMILY", filled: true) {
                    Text("Your race engineer · strategy, tyres, rules").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
                } trailing: {
                    Image(systemName: "mic.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.onAccent)
                        .frame(width: 34, height: 34).background(Circle().fill(Theme.accentGradient))
                }
            }
            .appCard()
        }
    }

    private var divider: some View { Divider().overlay(Color.white.opacity(0.06)) }

    private var segments: some View {
        HStack(spacing: 2) {
            ForEach(0..<6, id: \.self) { i in
                Capsule().fill(i < 3 ? Theme.accent : Color.white.opacity(0.12)).frame(width: 10, height: 3)
            }
        }
    }

    private func row<Sub: View, Trailing: View>(chip: String, title: String, next: Bool = false, filled: Bool = false,
                                                @ViewBuilder sub: () -> Sub, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            sessionChip(chip, filled: filled)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.f1(15, weight: .bold)).foregroundStyle(.white)
                sub()
            }
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(next ? Theme.accent.opacity(0.08) : .clear)
        .overlay(alignment: .leading) { if next { Rectangle().fill(Theme.accent).frame(width: 3) } }
    }
}

// B: the trio colours as sectors. Picks lead; vote, rank and Lights Out
// sit in three sector tiles (cyan / violet / red); Emily closes.
private struct ZoneSectors: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("GAME ZONE")
            picks
            HStack(spacing: 8) {
                sector("S1 · SEASON", Theme.accent) {
                    Text("#12").font(.f1Digits(28)).foregroundStyle(Theme.chromeText)
                } foot: { smallCaps("84 PTS", Theme.accent) }
                sector("S2 · FAN VOTE", Theme.violet) {
                    LEDText(text: "ANT", pitch: 4.2, color: mercedes)
                } foot: { smallCaps("52% · VOTE →", Theme.violet) }
                sector("S3 · LIGHTS", Theme.live) {
                    LEDText(text: "0.198", pitch: 3.3)
                } foot: { smallCaps("P4 · PLAY ▸", Theme.live) }
            }
            emily
        }
    }

    private var picks: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("R18").font(.f1(12, weight: .bold)).tracking(1.5).foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(Theme.accentGradient))
                Spacer()
                countdownChip("LOCKS IN 12D 12H")
            }
            Text("MAKE YOUR PICKS").font(.f1(24).italic()).foregroundStyle(Theme.chromeText)
            HStack(spacing: 8) {
                slot("POLE", "NOR", Theme.accent, done: true)
                slot("WIN", "PIA", Theme.accent, done: true)
                slot("FL", "—", Theme.violet, done: false)
            }
            Button {} label: { Text("FINISH YOUR PICKS") }
                .buttonStyle(GamePrimaryButtonStyle())
        }
        .padding(18)
        .appCard(20)
    }

    /// Outlined like the session chips on the countdown card.
    private func slot(_ label: String, _ code: String, _ color: Color, done: Bool) -> some View {
        VStack(spacing: 2) {
            smallCaps(label, Theme.dimText)
            Text(code).font(.f1(20)).foregroundStyle(done ? .white : Theme.faintText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(done ? 0.1 : 0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(done ? 0.7 : 0.3), lineWidth: 1.2))
        .shadow(color: done ? color.opacity(0.35) : .clear, radius: 6)
    }

    private func sector<Value: View, Foot: View>(_ label: String, _ color: Color,
                                                 @ViewBuilder value: () -> Value, @ViewBuilder foot: () -> Foot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(color).frame(height: 3).shadow(color: color, radius: 4)
            smallCaps(label, Theme.dimText)
            value().frame(height: 32, alignment: .leading)
            foot()
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(14)
    }

    private var emily: some View {
        HStack(spacing: 12) {
            Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
                .frame(width: 44, height: 44).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("ASK EMILY").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                Text("Your AI race engineer").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
            }
            Spacer()
            Image(systemName: "mic.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.onAccent)
                .frame(width: 40, height: 40).background(Circle().fill(Theme.accentGradient))
        }
        .padding(10).padding(.trailing, 2)
        .appCard(31)
    }
}

// C: the glass + LED cards you liked, re-coded in the app's vocabulary.
private struct ZoneGlass: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("GAME ZONE")
                Spacer()
                countdownChip("LOCKS IN 12D 12H")
            }
            picks
            HStack(spacing: 12) { dotd; lights }
            emily
        }
    }

    private var picks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MAKE YOUR PICKS").font(.f1(22).italic()).foregroundStyle(Theme.chromeText)
                .padding(.horizontal, 16).padding(.top, 16)
            VStack(spacing: 0) {
                pick("POLE", "NOR", "NORRIS", ai: "NOR")
                pick("WIN", "PIA", "PIASTRI", ai: "NOR")
                pick("FL", "—", "TAP TO PICK", ai: "VER", next: true)
            }
            HStack {
                HStack(spacing: 2) {
                    ForEach(0..<6, id: \.self) { i in
                        Capsule().fill(i < 3 ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.12))).frame(width: 14, height: 3)
                    }
                }
                Spacer()
                Text("FINISH →").font(.f1(13).italic()).tracking(1.5).foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 16).padding(.vertical, 9).background(Capsule().fill(Theme.accentGradient))
            }
            .padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 4)
        }
        .glassPanel(RoundedRectangle(cornerRadius: 22), light: Theme.accent, lightOffset: CGSize(width: -90, height: -20))
        .background(Color.clear.trioGlow(cornerRadius: 22, opacity: 0.35))
    }

    private func pick(_ slot: String, _ code: String, _ name: String, ai: String, next: Bool = false) -> some View {
        HStack(spacing: 12) {
            sessionChip(slot, width: 46)
            Text(code).font(.f1(18)).foregroundStyle(next ? Theme.faintText : .white).frame(width: 48, alignment: .leading)
            Text(name).font(.system(size: 11, weight: .medium)).foregroundStyle(next ? Theme.accent : Theme.dimText)
            Spacer()
            Text("AI \(ai)").font(.f1(10, weight: .heavy)).tracking(1).foregroundStyle(Theme.faintText)
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(next ? Theme.accent.opacity(0.08) : .clear)
        .overlay(alignment: .leading) { if next { Rectangle().fill(Theme.accent).frame(width: 3) } }
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.06)) }
    }

    private var dotd: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                TrioSlashes(height: 11)
                smallCaps("DRIVER OF THE DAY")
            }
            LEDText(text: "ANT", pitch: 5.6, color: mercedes)
            Text("52% · 412 votes").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            HStack {
                Text("VOTE →").font(.f1(12).italic()).tracking(1.5).foregroundStyle(Theme.accent)
                Spacer()
                countdownChip("4D LEFT")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(RoundedRectangle(cornerRadius: 20), light: Theme.violet, lightOffset: CGSize(width: -20, height: 20))
    }

    private var lights: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                TrioSlashes(height: 11)
                smallCaps("LIGHTS OUT")
            }
            LEDText(text: "0.198", pitch: 5)
            Text("Best · P4 this week").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { _ in Circle().fill(Theme.live).frame(width: 8, height: 8).shadow(color: Theme.live, radius: 3) }
                Spacer()
                Text("PLAY ▸").font(.f1(12).italic()).tracking(1.5).foregroundStyle(Theme.live)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(RoundedRectangle(cornerRadius: 20), light: Theme.live, lightOffset: CGSize(width: 20, height: 20))
    }

    private var emily: some View {
        HStack(spacing: 12) {
            Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
                .frame(width: 44, height: 44).clipShape(Circle())
                .shadow(color: Theme.accent.opacity(0.7), radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("ASK EMILY").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                Text("AI race engineer").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
            }
            Canvas { ctx, size in
                var p = Path()
                for x in stride(from: 0, through: size.width, by: 1) {
                    let env = sin(Double(x / size.width) * .pi)
                    let y = size.height / 2 + CGFloat((sin(Double(x) * 0.35) * 0.6 + sin(Double(x) * 0.11) * 0.4) * env) * size.height * 0.45
                    x == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                }
                ctx.stroke(p, with: .linearGradient(Gradient(colors: [Theme.accent, Theme.violet, Theme.live]),
                                                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), lineWidth: 1.3)
            }
            .frame(height: 26)
            Image(systemName: "mic.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.onAccent)
                .frame(width: 42, height: 42).background(Circle().fill(Theme.accentGradient))
        }
        .padding(8).padding(.leading, 2)
        .glassPanel(Capsule(), light: Theme.violet, lightOffset: CGSize(width: 0, height: 10))
    }
}

// MARK: - Liquid glass variants (iOS 26 glass, app colour code)

@available(iOS 26, *)
private func liquid(tint: Color?, clear: Bool, interactive: Bool) -> Glass {
    let base: Glass = clear ? .clear : .regular
    let tinted = tint.map { base.tint($0) } ?? base
    return interactive ? tinted.interactive() : tinted
}

/// Real Liquid Glass on iOS 26, material before.
private struct LiquidGlass: ViewModifier {
    var shape: AnyShape
    var tint: Color? = nil
    var clear = false
    var interactive = false
    var union: String? = nil
    var namespace: Namespace.ID? = nil

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if let union, let namespace {
                content.glassEffect(liquid(tint: tint, clear: clear, interactive: interactive), in: shape)
                    .glassEffectUnion(id: union, namespace: namespace)
            } else {
                content.glassEffect(liquid(tint: tint, clear: clear, interactive: interactive), in: shape)
            }
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

private extension View {
    func liquid(_ shape: some Shape, tint: Color? = nil, clear: Bool = false, interactive: Bool = false,
                union: String? = nil, in namespace: Namespace.ID? = nil) -> some View {
        modifier(LiquidGlass(shape: AnyShape(shape), tint: tint, clear: clear, interactive: interactive,
                             union: union, namespace: namespace))
    }

    /// The glass prominent button in the accent colour.
    @ViewBuilder
    func prominentGlass() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent).tint(Theme.accent)
        } else {
            buttonStyle(.borderedProminent).tint(Theme.accent)
        }
    }
}

/// Groups sibling glass so it renders, blends and morphs together.
private struct LiquidContainer<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// Trio-colour light under the zone, for the glass to bend and reflect.
private struct TrioLight: View {
    var body: some View {
        ZStack {
            Circle().fill(Theme.accent).frame(width: 240).blur(radius: 70).opacity(0.55).offset(x: -110, y: -120)
            Circle().fill(Theme.violet).frame(width: 220).blur(radius: 80).opacity(0.5).offset(x: 120, y: 40)
            Circle().fill(Theme.live).frame(width: 200).blur(radius: 80).opacity(0.45).offset(x: -60, y: 210)
        }
        .allowsHitTesting(false)
    }
}

// D: C's layout as true liquid glass. One container; the vote and Lights Out
// tiles are a single unioned glass shape; buttons are prominent glass.
private struct ZoneLiquidTiles: View {
    @Namespace private var glass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("GAME ZONE")
                Spacer()
                countdownChip("LOCKS IN 12D 12H")
            }
            LiquidContainer(spacing: 14) {
                VStack(spacing: 12) {
                    picks
                    HStack(spacing: 6) { dotd; lights }
                    emily
                }
            }
        }
        .background(TrioLight())
    }

    private var picks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MAKE YOUR PICKS").font(.f1(22).italic()).foregroundStyle(Theme.chromeText)
            HStack(spacing: 8) {
                pill("POLE", "NOR", papaya)
                pill("WIN", "PIA", papaya)
                pill("FL", "+", nil)
            }
            HStack {
                HStack(spacing: 2) {
                    ForEach(0..<6, id: \.self) { i in
                        Capsule().fill(i < 3 ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.15))).frame(width: 14, height: 3)
                    }
                }
                Text("3 OF 6").font(.f1(10, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.dimText)
                Spacer()
                Button {} label: {
                    Text("FINISH →").font(.f1(13).italic()).tracking(1.5).foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                }
                .prominentGlass()
            }
        }
        .padding(18)
        .liquid(RoundedRectangle(cornerRadius: 28))
    }

    /// A pick as a tinted panel inside the glass: team colour when picked, cyan "next" when open.
    private func pill(_ label: String, _ code: String, _ team: Color?) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(team == nil ? Theme.accent : Theme.dimText)
            Text(code).font(.f1(22)).foregroundStyle(team == nil ? Theme.accent : .white)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill((team ?? Theme.accent).opacity(team == nil ? 0.12 : 0.18)))
        .overlay(alignment: .bottom) {
            Capsule().fill(team ?? Theme.accent).frame(width: 22, height: 3).padding(.bottom, 5)
                .shadow(color: team ?? Theme.accent, radius: 3)
        }
    }

    private var dotd: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) { TrioSlashes(height: 11); smallCaps("DRIVER OF THE DAY") }
            LEDText(text: "ANT", pitch: 5.6, color: mercedes)
            Text("52% · 412 votes").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            Text("VOTE →").font(.f1(12).italic()).tracking(1.5).foregroundStyle(Theme.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquid(RoundedRectangle(cornerRadius: 26), union: "duo", in: glass)
    }

    private var lights: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) { TrioSlashes(height: 11); smallCaps("LIGHTS OUT") }
            LEDText(text: "0.198", pitch: 5)
            Text("Best · P4 this week").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            Text("PLAY ▸").font(.f1(12).italic()).tracking(1.5).foregroundStyle(Theme.live)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquid(RoundedRectangle(cornerRadius: 26), tint: Theme.live.opacity(0.12), union: "duo", in: glass)
    }

    private var emily: some View {
        HStack(spacing: 12) {
            Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
                .frame(width: 44, height: 44).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("ASK EMILY").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                Text("AI race engineer").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
            }
            Spacer()
            Button {} label: {
                Image(systemName: "mic.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.onAccent)
                    .frame(width: 30, height: 30)
            }
            .prominentGlass()
        }
        .padding(8).padding(.leading, 2)
        .liquid(Capsule(), tint: Theme.violet.opacity(0.15))
    }
}

// E: no cards. Floating glass controls like Control Center: three round pick
// buttons, a prominent finish button, a two-part glass dock for the vote and
// Lights Out, and Emily as a glass orb joined to a glass prompt.
private struct ZoneFloating: View {
    @Namespace private var glass

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle("GAME ZONE")
                Spacer()
                countdownChip("LOCKS IN 12D 12H")
            }
            Text("MAKE YOUR PICKS").font(.f1(26).italic()).foregroundStyle(Theme.chromeText)
                .padding(.top, 4)
            LiquidContainer(spacing: 16) {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        orb("POLE", "NOR", papaya)
                        orb("WIN", "PIA", papaya)
                        orb("FL", "+", nil)
                    }
                    Button {} label: {
                        Text("FINISH YOUR PICKS").font(.f1(15).italic()).tracking(2).foregroundStyle(Theme.onAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .prominentGlass()
                    dock
                    emily
                }
            }
        }
        .background(TrioLight())
    }

    /// A round, interactive glass button per pick, tinted with the team colour.
    private func orb(_ label: String, _ code: String, _ team: Color?) -> some View {
        VStack(spacing: 2) {
            Text(code).font(.f1(24)).foregroundStyle(team == nil ? Theme.accent : .white)
            Text(label).font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(team == nil ? Theme.accent : Theme.dimText)
        }
        .frame(width: 96, height: 96)
        .liquid(Circle(), tint: team.map { $0.opacity(0.35) } ?? Theme.accent.opacity(0.12), interactive: true)
        .frame(maxWidth: .infinity)
    }

    /// Vote and Lights Out as two halves of one glass dock.
    private var dock: some View {
        HStack(spacing: 4) {
            HStack(spacing: 12) {
                LEDText(text: "ANT", pitch: 4.4, color: mercedes)
                VStack(alignment: .leading, spacing: 3) {
                    smallCaps("DOTD")
                    Text("52%").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .liquid(Capsule(), interactive: true, union: "dock", in: glass)
            HStack(spacing: 12) {
                LEDText(text: "0.198", pitch: 3.6)
                VStack(alignment: .leading, spacing: 3) {
                    smallCaps("BEST")
                    Text("P4").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .liquid(Capsule(), tint: Theme.live.opacity(0.18), interactive: true, union: "dock", in: glass)
        }
    }

    /// Emily: a glass orb with her face, joined to a glass prompt.
    private var emily: some View {
        HStack(spacing: 4) {
            Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
                .frame(width: 50, height: 50).clipShape(Circle())
                .padding(6)
                .shadow(color: Theme.violet.opacity(0.8), radius: 8)
                .liquid(Circle())
            HStack {
                Text("Ask Emily anything…").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Image(systemName: "mic.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 18).frame(height: 62)
            .liquid(Capsule(), interactive: true)
        }
    }
}

// MARK: - Result-state redesigns in the app's existing card families

private let exactGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
private let missRed = Color(red: 1, green: 0.4, blue: 0.35)
private let redbullBlue = Color(red: 0.25, green: 0.35, blue: 0.95)
private let ferrariRed = Color(red: 0.93, green: 0.1, blue: 0.14)

private enum Outcome { case exact, partial, miss
    var color: Color { switch self { case .exact: exactGreen; case .partial: Theme.accent; case .miss: missRed } }
}

private struct SamplePick: Identifiable {
    let slot: String, code: String, team: Color, outcome: Outcome, points: Int
    var id: String { slot }
    var mark: String { outcome == .miss ? "✗ 0" : (outcome == .exact ? "✓ \(points)" : "~ \(points)") }
}

private let samplePicks = [
    SamplePick(slot: "SPR", code: "—", team: .clear, outcome: .miss, points: 0),
    SamplePick(slot: "POLE", code: "ANT", team: mercedes, outcome: .miss, points: 0),
    SamplePick(slot: "P1", code: "ANT", team: mercedes, outcome: .partial, points: 2),
    SamplePick(slot: "P2", code: "VER", team: redbullBlue, outcome: .partial, points: 2),
    SamplePick(slot: "P3", code: "NOR", team: papaya, outcome: .miss, points: 0),
    SamplePick(slot: "FL", code: "ANT", team: mercedes, outcome: .miss, points: 0),
]
private let sampleComment = "You picked ANT for pole and fastest lap. VER took pole and LEC fastest lap, but ANT on the podium still scored. Nice 4-point haul."

private func gameZoneHeader(_ chip: String) -> some View {
    HStack {
        SectionTitle("GAME ZONE")
        Spacer()
        countdownChip(chip)
    }
}

/// The countdown card's neon tile, with any text.
private func neonBox(_ value: String, _ label: String, _ tint: Color) -> some View {
    VStack(spacing: 2) {
        Text(value).font(.f1Digits(30)).foregroundStyle(Theme.chromeText).shadow(color: .white.opacity(0.4), radius: 6)
        Text(label).font(.f1(10, weight: .bold)).tracking(1.5).foregroundStyle(.white.opacity(0.7))
    }
    .frame(maxWidth: .infinity).padding(.vertical, 12)
    .background(
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color(white: 0.03), Color(white: 0.09)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
            RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.9), lineWidth: 3).blur(radius: 5)
            RoundedRectangle(cornerRadius: 16).strokeBorder(LinearGradient(colors: [Color.white.opacity(0.95), tint, tint.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        }
    )
    .shadow(color: tint.opacity(0.45), radius: 10)
}

/// The session chip's neon rim (NeonChip), sized to any content.
private func neonRim(_ tint: Color, lit: Bool) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Color(white: 0.03), Color(white: 0.085)], startPoint: .top, endPoint: .bottom))
        RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Color.white.opacity(0.09), .clear], startPoint: .top, endPoint: .center))
        if lit { RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.9), lineWidth: 2.5).blur(radius: 4) }
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(LinearGradient(colors: [lit ? Color.white.opacity(0.95) : tint.opacity(0.55), tint.opacity(lit ? 1 : 0.5), tint.opacity(lit ? 0.8 : 0.35)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: lit ? 1.6 : 1)
    }
    .shadow(color: tint.opacity(lit ? 0.5 : 0), radius: 8)
}

/// The countdown card's carbon panel.
private extension View {
    func carbonPanel(_ radius: CGFloat = 20) -> some View {
        background(
            CarbonFiber()
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.glassStroke, lineWidth: 1))
                .trioGlow(cornerRadius: radius)
        )
    }
}

// 1 · Cockpit: the countdown card's parts. Carbon, neon tiles for the
// score, neon chips for the picks (rim colour = outcome), a carbon list.
private struct ZoneCockpit: View {
    var resultOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            gameZoneHeader("SCORED · R17")
            VStack(alignment: .leading, spacing: 14) {
                Text("YOUR RESULT · SINGAPORE").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.accent)
                HStack(spacing: 10) {
                    neonBox("+4", "POINTS", Theme.accent)
                    neonBox("1ST", "OF 1", Theme.violet)
                    neonBox("✓", "BEAT THE AI", exactGreen)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(samplePicks) { pick in
                        VStack(spacing: 2) {
                            Text(pick.slot).font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                            Text(pick.code).font(.f1(17)).foregroundStyle(.white)
                            Text(pick.mark).font(.f1(10, weight: .bold)).foregroundStyle(pick.outcome.color)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(neonRim(pick.outcome.color, lit: pick.outcome != .miss))
                    }
                }
                RadioComment(text: sampleComment)
                Button {} label: { Text("SEE BREAKDOWN") }.buttonStyle(GamePrimaryButtonStyle())
            }
            .padding(16)
            .carbonPanel()

            if !resultOnly {
            VStack(spacing: 0) {
                row(lead: AnyView(LEDText(text: "LEC", pitch: 3.6, color: ferrariRed)), title: "DRIVER OF THE DAY", sub: "LEC leads · 1 vote", chip: "CHANGE", tint: Theme.violet)
                Divider().overlay(Color.white.opacity(0.08))
                row(lead: AnyView(LEDText(text: "0.198", pitch: 3.0)), title: "LIGHTS OUT", sub: "Best · P1 this week", chip: "PLAY", tint: Theme.live)
                Divider().overlay(Color.white.opacity(0.08))
                row(lead: AnyView(Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill()).frame(width: 40, height: 40).clipShape(Circle())),
                    title: "ASK EMILY", sub: "Your AI race engineer", chip: "ASK", tint: Theme.accent)
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .carbonPanel()
            }
        }
    }

    private func row(lead: AnyView, title: String, sub: String, chip: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            lead.frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.f1(14, weight: .bold)).foregroundStyle(.white)
                Text(sub).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
            }
            Spacer()
            NeonChip(title: chip, tint: tint, selected: true).frame(width: 82)
        }
        .padding(.vertical, 12)
    }
}

// 2 · Hero: the result as a race-hero card (gradient, flag watermark,
// chrome title, big score), picks as one compact strip; the rest as rows
// in the race-weekend list panel.
private struct ZoneHero: View {
    var resultOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            gameZoneHeader("SCORED · R17")
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Theme.card, Theme.violet.opacity(0.16), Theme.accent.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
                    .trioGlow(cornerRadius: 20)
                Text("🇸🇬").font(.system(size: 110)).opacity(0.14).rotationEffect(.degrees(-12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 14, y: -10)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("ROUND 17").font(.f1(13).italic()).tracking(1).foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 7))
                        Spacer()
                        Text("YOUR RESULT").font(.f1(15).italic()).foregroundStyle(Theme.dimText)
                    }
                    Text("SINGAPORE").font(.f1(32).italic()).foregroundStyle(Theme.chromeText)
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("+4").font(.f1Digits(52))
                            Text("PTS").font(.f1(16))
                        }
                        .foregroundStyle(Theme.accent).shadow(color: Theme.accent.opacity(0.5), radius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("1st of 1").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            Text("You beat the AI Strategist ✓").font(.system(size: 12, weight: .medium)).foregroundStyle(exactGreen)
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach(samplePicks) { pick in
                            VStack(spacing: 3) {
                                Text(pick.slot).font(.f1(10, weight: .bold)).tracking(1).foregroundStyle(Theme.faintText)
                                Text(pick.code).font(.f1(15)).foregroundStyle(.white)
                                Capsule().fill(pick.team).frame(width: 18, height: 3)
                                Text(pick.mark).font(.f1(10, weight: .bold)).foregroundStyle(pick.outcome.color)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.25)))
                        }
                    }
                    RadioComment(text: sampleComment)
                    Button {} label: { Text("SEE BREAKDOWN") }.buttonStyle(GameOutlineButtonStyle())
                }
                .padding(18)
            }

            if !resultOnly {
            VStack(spacing: 0) {
                listRow(chip: "VOTE", title: "DRIVER OF THE DAY", sub: "LEC leads · 1 vote", trailing: AnyView(countdownChip("3D LEFT")))
                Divider().overlay(Color.white.opacity(0.06))
                listRow(chip: "START", title: "LIGHTS OUT", sub: "Best · P1 this week", trailing: AnyView(LEDText(text: "0.198", pitch: 2.8)))
                Divider().overlay(Color.white.opacity(0.06))
                listRow(chip: "AI", title: "ASK EMILY", sub: "Your AI race engineer", filled: true, trailing: AnyView(
                    Image(systemName: "mic.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.onAccent)
                        .frame(width: 32, height: 32).background(Circle().fill(Theme.accentGradient))))
            }
            .appCard()
            }
        }
    }
}

/// A row in the race-weekend list language.
private func listRow(chip: String, title: String, sub: String, filled: Bool = false, next: Bool = false, trailing: AnyView) -> some View {
    HStack(spacing: 12) {
        sessionChip(chip, filled: filled, width: 52)
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.f1(15, weight: .bold)).foregroundStyle(.white)
            Text(sub).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
        }
        Spacer(minLength: 6)
        trailing
    }
    .padding(.horizontal, 14).padding(.vertical, 11)
    .background(next ? Theme.accent.opacity(0.08) : .clear)
    .overlay(alignment: .leading) { if next { Rectangle().fill(Theme.accent).frame(width: 3) } }
}

/// The outlined countdown chip, in any colour.
private func outlineChip(_ s: String, _ color: Color) -> some View {
    Text(s).font(.f1(10, weight: .heavy).monospacedDigit()).tracking(1).foregroundStyle(color)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(color.opacity(0.65), lineWidth: 1))
}

// 3 · Timing sheet: everything in the race-weekend list language. A result
// list with outcome chips, then a second list for the vote, Lights Out
// and Emily.
private struct ZoneTimingSheet: View {
    var resultOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            gameZoneHeader("SCORED · R17")
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    sessionChip("R17", filled: true, width: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR RESULT").font(.f1(15, weight: .bold)).foregroundStyle(.white)
                        Text("1st of 1 · beat the AI ✓").font(.system(size: 11, weight: .medium)).foregroundStyle(exactGreen)
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("+4").font(.f1Digits(30))
                        Text("PTS").font(.f1(12))
                    }
                    .foregroundStyle(Theme.accent).shadow(color: Theme.accent.opacity(0.5), radius: 8)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.accent.opacity(0.08))
                .overlay(alignment: .leading) { Rectangle().fill(Theme.accent).frame(width: 3) }
                ForEach(samplePicks) { pick in
                    Divider().overlay(Color.white.opacity(0.06))
                    HStack(spacing: 12) {
                        sessionChip(pick.slot, width: 52)
                        Capsule().fill(pick.team).frame(width: 3, height: 16)
                        Text(pick.code).font(.f1(15, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                        outlineChip(pick.mark, pick.outcome.color)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                }
                Divider().overlay(Color.white.opacity(0.06))
                RadioComment(text: sampleComment).padding(12)
            }
            .appCard()

            if !resultOnly {
            VStack(spacing: 0) {
                listRow(chip: "VOTE", title: "DRIVER OF THE DAY", sub: "LEC leads · 1 vote", trailing: AnyView(countdownChip("3D LEFT")))
                Divider().overlay(Color.white.opacity(0.06))
                listRow(chip: "START", title: "LIGHTS OUT", sub: "Best 0.198 · P1 this week", trailing: AnyView(outlineChip("PLAY", Theme.live)))
                Divider().overlay(Color.white.opacity(0.06))
                listRow(chip: "AI", title: "ASK EMILY", sub: "Your AI race engineer", filled: true, trailing: AnyView(outlineChip("ASK", Theme.accent)))
            }
            .appCard()
            }
        }
    }
}

// MARK: - Separate cards, one bold "Call in your crew" style card

/// A result card from 1–3, then the vote, Lights Out and Emily as their own
/// cards: dark app cards, with one of them bold and filled like the invite.
private struct ZoneMixed: View {
    enum Result { case cockpit, hero, sheet }
    enum Bold { case dotd, lights, emily }
    let result: Result
    let bold: Bold
    var photoLights = false
    var waveEmily = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            resultCard
            Group {
                if bold == .dotd { boldDotd } else { darkDotd }
            }
            .id("zoneLower")
            if photoLights { photoLightsCard } else if bold == .lights { boldLights } else { darkLights }
            if waveEmily { waveEmilyBar } else if bold == .emily { boldEmily } else { darkEmily }
        }
    }

    /// Lights Out on the AI-made car under the five red lights.
    private var photoLightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REACTION TEST").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.live)
            Text("LIGHTS\nOUT").font(.f1(32).italic()).foregroundStyle(Theme.chromeText)
            HStack(spacing: 12) {
                LEDText(text: "0.198", pitch: 3.4)
                Text("Best · P1\nthis week").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            }
            NeonChip(title: "HOLD TO START ▸", tint: Theme.live, selected: true).frame(width: 170)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .background(
            ZStack {
                Color.clear.overlay(alignment: .trailing) {
                    Image("LightsOutHero").resizable().scaledToFill()
                }
                .clipped()
                // keep the left side dark enough for the text
                LinearGradient(stops: [.init(color: Theme.background.opacity(0.95), location: 0),
                                       .init(color: Theme.background.opacity(0.6), location: 0.45),
                                       .init(color: .clear, location: 0.75)],
                               startPoint: .leading, endPoint: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
            .trioGlow(cornerRadius: 20)
        )
    }

    /// The Emily bar from the built Game Zone: glass, waveform, mic.
    private var waveEmilyBar: some View {
        HStack(spacing: 12) {
            Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
                .frame(width: 44, height: 44).clipShape(Circle())
                .shadow(color: Theme.accent.opacity(0.7), radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("ASK EMILY").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                Text("AI race engineer").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
            }
            RadioWave().frame(height: 26)
            Image(systemName: "mic.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.onAccent)
                .frame(width: 42, height: 42).background(Circle().fill(Theme.accentGradient))
        }
        .padding(8).padding(.leading, 2)
        .glassPanel(Capsule(), light: Theme.violet, lightOffset: CGSize(width: 0, height: 10))
    }

    /// Only the result card of each draft (the header and lower cards dropped).
    @ViewBuilder
    private var resultCard: some View {
        switch result {
        case .cockpit: ZoneCockpit(resultOnly: true)
        case .hero: ZoneHero(resultOnly: true)
        case .sheet: ZoneTimingSheet(resultOnly: true)
        }
    }

    // Dark cards: the app's standard panel.

    private var darkDotd: some View {
        HStack(spacing: 16) {
            LEDText(text: "LEC", pitch: 4.6, color: ferrariRed)
            VStack(alignment: .leading, spacing: 4) {
                Text("DRIVER OF THE DAY").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                Text("LEC leads · 1 vote").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.dimText)
                Text("CHANGE VOTE →").font(.f1(12).italic()).tracking(1.5).foregroundStyle(Theme.accent).padding(.top, 2)
            }
            Spacer(minLength: 4)
            countdownChip("3D LEFT")
        }
        .padding(18)
        .appCard(20)
    }

    private var darkLights: some View {
        HStack(spacing: 16) {
            LEDText(text: "0.198", pitch: 3.6)
            VStack(alignment: .leading, spacing: 4) {
                Text("LIGHTS OUT").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                Text("Best · P1 this week").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.dimText)
            }
            Spacer(minLength: 4)
            NeonChip(title: "PLAY", tint: Theme.live, selected: true).frame(width: 74)
        }
        .padding(18)
        .appCard(20)
    }

    private var darkEmily: some View {
        HStack(spacing: 12) {
            Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
                .frame(width: 46, height: 46).clipShape(Circle())
                .shadow(color: Theme.accent.opacity(0.6), radius: 6)
            VStack(alignment: .leading, spacing: 3) {
                Text("ASK EMILY").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                Text("Your AI race engineer").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.dimText)
            }
            Spacer()
            Image(systemName: "mic.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.onAccent)
                .frame(width: 42, height: 42).background(Circle().fill(Theme.accentGradient))
        }
        .padding(14)
        .appCard(20)
    }

    // Bold cards: the "Call in your crew" recipe in a new colour.

    private var boldDotd: some View {
        boldCard(colors: [Color(red: 1, green: 0.84, blue: 0.35), Color(red: 1, green: 0.55, blue: 0.2)],
                 ring: [Color(red: 1, green: 0.84, blue: 0.35), Color(red: 1, green: 0.55, blue: 0.2)],
                 badge: AnyView(Image(systemName: "star.fill").font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.35))),
                 kicker: "FAN VOTE · 3 DAYS LEFT",
                 title: "DRIVER OF\nTHE DAY",
                 sub: "LEC leads the fans. Change your vote until Thursday.",
                 icon: "hand.thumbsup.fill",
                 // the leader's team suit, standing on the right
                 art: AnyView(Image("Suits/ferrari").resizable().scaledToFit().frame(height: 300)
                    .shadow(color: .black.opacity(0.35), radius: 10, x: -4, y: 8)
                    .offset(x: 18, y: 90)))
    }

    private var boldLights: some View {
        boldCard(colors: [Theme.live, Color(red: 1, green: 0.55, blue: 0.15)],
                 ring: [Theme.live, Color(red: 1, green: 0.6, blue: 0.2)],
                 badge: AnyView(HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { _ in Circle().fill(Theme.live).frame(width: 6, height: 6).shadow(color: Theme.live, radius: 2) }
                 }),
                 kicker: "BEST 0.198 · P1 THIS WEEK",
                 title: "LIGHTS\nOUT",
                 sub: "Hold like the clutch, let go when the lights go out.",
                 icon: "play.fill",
                 // a car on the grid, nose towards you
                 art: AnyView(Image("Cars/red_bull").resizable().scaledToFit().frame(width: 230)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: -4, y: 10)
                    .offset(x: 50, y: 34)))
    }

    private var boldEmily: some View {
        boldCard(colors: [Theme.violet, Color(red: 0.88, green: 0.36, blue: 0.85)],
                 ring: [Theme.violet, Color(red: 0.95, green: 0.45, blue: 0.9)],
                 badge: AnyView(Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Theme.violet, Color(red: 0.95, green: 0.45, blue: 0.9)],
                                                    startPoint: .leading, endPoint: .trailing))),
                 kicker: "TEAM RADIO · AI",
                 title: "ASK YOUR\nENGINEER",
                 sub: "Strategy, tyres, rules or the standings. Emily answers on the radio.",
                 icon: "mic.fill",
                 // Emily herself, fading into the card
                 art: AnyView(Image("EmilyAvatar").resizable().scaledToFill().frame(width: 190, height: 260).clipped()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.45)],
                                         startPoint: .leading, endPoint: .trailing))))
    }

    /// InviteBanner's recipe: gradient fill, dark badge with a neon ring,
    /// big dark title, a round action at the top right.
    private func boldCard(colors: [Color], ring: [Color], badge: AnyView, kicker: String,
                          title: String, sub: String, icon: String, art: AnyView? = nil) -> some View {
        let gradient = LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                badge
                    .frame(width: 58, height: 58)
                    .background(
                        Circle().fill(Theme.onAccent)
                            .overlay(Circle().strokeBorder(LinearGradient(colors: ring, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
                            .shadow(color: ring[0].opacity(0.55), radius: 7)
                    )
                Spacer()
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.onAccent)
                    .frame(width: 42, height: 42).background(Circle().fill(Theme.onAccent.opacity(0.15)))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(kicker).font(.f1(10, weight: .bold)).tracking(1.5).foregroundStyle(Theme.onAccent.opacity(0.6))
                Text(title).font(.f1(32)).foregroundStyle(Theme.onAccent).lineLimit(2).minimumScaleFactor(0.8)
                Text(sub).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.onAccent.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: art == nil ? .infinity : 185, alignment: .leading)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // Art as an overlay so it can never make the card bigger.
            RoundedRectangle(cornerRadius: 20).fill(gradient)
                .overlay(alignment: .bottomTrailing) { if let art { art } }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        )
    }
}

// MARK: - Compact mix with the AI Strategist

/// Separate cards in different sizes: the result (or picks) card, the AI
/// Strategist (sealed before the race, revealed after), a compact yellow
/// driver-of-the-day card, a slim Lights Out photo strip, the Emily bar.
private struct ZoneCompact: View {
    let scored: Bool

    private let aiPicks = [
        SamplePick(slot: "SPR", code: "—", team: .clear, outcome: .miss, points: 0),
        SamplePick(slot: "POLE", code: "NOR", team: papaya, outcome: .miss, points: 0),
        SamplePick(slot: "P1", code: "VER", team: redbullBlue, outcome: .miss, points: 0),
        SamplePick(slot: "P2", code: "ANT", team: mercedes, outcome: .partial, points: 2),
        SamplePick(slot: "P3", code: "PIA", team: papaya, outcome: .miss, points: 0),
        SamplePick(slot: "FL", code: "NOR", team: papaya, outcome: .miss, points: 0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if scored { ZoneHero(resultOnly: true) } else { picksHero }
            strategist.id("zoneLower")
            dotd
            lights
            emily
        }
    }

    // Before the race: the hero card holding your picks.
    private var picksHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            gameZoneHeader("LOCKS IN 12D 11H")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ROUND 18").font(.f1(13).italic()).tracking(1).foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 7))
                    Spacer()
                    Text("YOUR PICKS").font(.f1(15).italic()).foregroundStyle(Theme.dimText)
                }
                Text("UNITED STATES").font(.f1(30).italic()).foregroundStyle(Theme.chromeText)
                HStack(spacing: 6) {
                    pickTile("POLE", "RUS", mercedes)
                    pickTile("P1", "ANT", mercedes)
                    pickTile("P2", "HAM", ferrariRed)
                    pickTile("P3", nil, nil)
                    pickTile("FL", nil, nil)
                }
                Button {} label: { Text("FINISH YOUR PICKS") }.buttonStyle(GamePrimaryButtonStyle())
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Theme.card, Theme.violet.opacity(0.16), Theme.accent.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(alignment: .topTrailing) {
                        Text("🇺🇸").font(.system(size: 100)).opacity(0.14).rotationEffect(.degrees(-12)).offset(x: 14, y: -6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
                    .trioGlow(cornerRadius: 20)
            )
        }
    }

    private func pickTile(_ slot: String, _ code: String?, _ team: Color?) -> some View {
        VStack(spacing: 3) {
            Text(slot).font(.f1(10, weight: .bold)).tracking(1).foregroundStyle(Theme.faintText)
            Text(code ?? "+").font(.f1(15)).foregroundStyle(code == nil ? Theme.accent : .white)
            Capsule().fill(team ?? Theme.accent.opacity(0.4)).frame(width: 18, height: 3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(code == nil ? Theme.accent.opacity(0.4) : .clear))
    }

    // The AI Strategist: violet (the app's AI colour), sealed or revealed.
    private var strategist: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "cpu").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.violet)
                    .frame(width: 36, height: 36).background(Circle().fill(Theme.violet.opacity(0.15)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI STRATEGIST").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                    Text(scored ? "Its Singapore picks, revealed" : "Has picked R18 · revealed at lights out")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
                }
                Spacer(minLength: 4)
                if scored {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("YOU 4 · AI 2").font(.f1(12, weight: .heavy)).foregroundStyle(.white)
                        Text("YOU WIN ✓").font(.f1(10, weight: .bold)).tracking(1).foregroundStyle(exactGreen)
                    }
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.violet)
                }
            }
            // Season duel: totals as rings, every round as 3D bars.
            HStack(spacing: 14) {
                DuelRings(you: 170, ai: 167)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        legend("YOU", Theme.accent)
                        legend("AI", Theme.violet)
                        Spacer()
                        Text("SEASON · R1–R17").font(.f1(9, weight: .bold)).tracking(1).foregroundStyle(Theme.faintText)
                    }
                    DuelBars3D(you: Self.youRounds, ai: Self.aiRounds)
                        .frame(height: 96)
                }
            }
            HStack(spacing: 6) {
                ForEach(aiPicks) { pick in
                    VStack(spacing: 3) {
                        Text(pick.slot).font(.f1(9, weight: .bold)).tracking(1).foregroundStyle(Theme.faintText)
                        Text(scored ? pick.code : "?").font(.f1(14)).foregroundStyle(scored ? .white : Theme.violet)
                        if scored {
                            Text(pick.mark).font(.f1(9, weight: .bold)).foregroundStyle(pick.outcome.color)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.violet.opacity(scored ? 0.08 : 0.12)))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Theme.card, Theme.violet.opacity(0.14)], startPoint: .leading, endPoint: .trailing))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.violet.opacity(0.35), lineWidth: 1))
        )
    }

    static let youRounds: [Double] = [12, 8, 15, 4, 10, 18, 6, 9, 14, 11, 7, 16, 5, 13, 10, 8, 4]
    static let aiRounds: [Double] = [10, 11, 9, 12, 8, 10, 13, 7, 12, 9, 11, 8, 14, 10, 9, 12, 2]

    private func legend(_ s: String, _ c: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 6, height: 6).shadow(color: c, radius: 3)
            Text(s).font(.f1(9, weight: .heavy)).tracking(1).foregroundStyle(.white.opacity(0.8))
        }
    }

    // Driver of the day: the yellow invite-style card, compact.
    private var dotd: some View {
        let yellow = [Color(red: 1, green: 0.84, blue: 0.35), Color(red: 1, green: 0.55, blue: 0.2)]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(yellow[0])
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.onAccent).overlay(Circle().strokeBorder(LinearGradient(colors: yellow, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)))
                Text("FAN VOTE · 3D LEFT").font(.f1(10, weight: .bold)).tracking(1.5).foregroundStyle(Theme.onAccent.opacity(0.6))
            }
            Text("DRIVER OF THE DAY").font(.f1(22)).foregroundStyle(Theme.onAccent)
            VStack(spacing: 5) {
                voteBar("LEC", 0.52)
                voteBar("ANT", 0.30)
                voteBar("VER", 0.18)
            }
            .frame(width: 190)
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 168)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: yellow, startPoint: .leading, endPoint: .trailing))
                .overlay(alignment: .topTrailing) {
                    Image("Suits/ferrari").resizable().scaledToFit().frame(height: 250)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: -3, y: 6)
                        .offset(x: -6, y: 14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        )
    }

    /// A dark bar on the yellow card: code, share, percentage.
    private func voteBar(_ code: String, _ pct: Double) -> some View {
        HStack(spacing: 8) {
            Text(code).font(.f1(12)).foregroundStyle(Theme.onAccent).frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.onAccent.opacity(0.12))
                    Capsule().fill(Theme.onAccent).frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 7)
            Text("\(Int(pct * 100))%").font(.f1Digits(11)).foregroundStyle(Theme.onAccent).frame(width: 32, alignment: .trailing)
        }
    }

    // Lights Out: a slim strip on the AI car photo.
    private var lights: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("REACTION TEST").font(.f1(10, weight: .bold)).tracking(2).foregroundStyle(Theme.live)
                Text("LIGHTS OUT").font(.f1(22).italic()).foregroundStyle(Theme.chromeText)
                HStack(spacing: 10) {
                    LEDText(text: "0.198", pitch: 2.8)
                    Text("P1 this week").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer()
            // last ten starts: shorter is faster, the best one lit
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(reactionHistory.enumerated()), id: \.offset) { i, t in
                    let best = i == reactionHistory.count - 1
                    Capsule().fill(best ? Theme.live : Color.white.opacity(0.35))
                        .frame(width: 4, height: CGFloat((t - 0.15) * 260))
                        .shadow(color: best ? Theme.live : .clear, radius: 3)
                }
            }
            .padding(.trailing, 8)
            NeonChip(title: "PLAY ▸", tint: Theme.live, selected: true).frame(width: 84)
        }
        .padding(16)
        .frame(height: 118)
        .background(
            Color.clear
                .overlay(alignment: .trailing) { Image("LightsOutHero").resizable().scaledToFill() }
                .overlay(LinearGradient(stops: [.init(color: Theme.background.opacity(0.95), location: 0),
                                                .init(color: Theme.background.opacity(0.55), location: 0.5),
                                                .init(color: .clear, location: 0.85)],
                                        startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
        )
    }

    private var emily: some View {
        HStack(spacing: 12) {
            Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
                .frame(width: 44, height: 44).clipShape(Circle())
                .shadow(color: Theme.accent.opacity(0.7), radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("ASK EMILY").font(.f1(16).italic()).foregroundStyle(Theme.chromeText)
                Text("AI race engineer").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dimText)
            }
            RadioWave().frame(height: 26)
            Image(systemName: "mic.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.onAccent)
                .frame(width: 42, height: 42).background(Circle().fill(Theme.accentGradient))
        }
        .padding(8).padding(.leading, 2)
        .glassPanel(Capsule(), light: Theme.violet, lightOffset: CGSize(width: 0, height: 10))
    }
}

/// Season totals as two concentric rings: you (cyan) outside, the AI
/// (violet) inside, each against the larger total.
private struct DuelRings: View {
    let you: Double
    let ai: Double

    var body: some View {
        let top = max(you, ai) * 1.08
        ZStack {
            ring(you / top, Theme.accent, inset: 0)
            ring(ai / top, Theme.violet, inset: 13)
            VStack(spacing: 0) {
                Text("\(Int(you))").font(.f1Digits(18)).foregroundStyle(.white)
                Text("VS \(Int(ai))").font(.f1(9, weight: .heavy)).tracking(1).foregroundStyle(Theme.violet)
            }
        }
    }

    private func ring(_ value: Double, _ color: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 9)
            Circle().trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.8), radius: 4)
        }
        .padding(inset)
    }
}

/// Points per round as glowing 3D bars, you in front and the AI behind,
/// gently swaying (SceneKit, like the circuit map).
private struct DuelBars3D: UIViewRepresentable {
    let you: [Double]
    let ai: [Double]

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isUserInteractionEnabled = false
        view.scene = scene()
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    private func scene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let chart = SCNNode()
        scene.rootNode.addChildNode(chart)
        let n = max(you.count, ai.count)
        let pitch: Float = 0.42
        let x0 = -Float(n - 1) * pitch / 2
        let cyan = UIColor(red: 0.15, green: 0.82, blue: 1, alpha: 1)
        let violet = UIColor(red: 0.52, green: 0.42, blue: 1, alpha: 1)
        for (row, values, color) in [(0, you, cyan), (1, ai, violet)] {
            for (i, v) in values.enumerated() {
                let h = CGFloat(max(v, 0.5) * 0.09)
                let box = SCNBox(width: 0.26, height: h, length: 0.26, chamferRadius: 0.04)
                let m = SCNMaterial()
                m.lightingModel = .lambert
                m.diffuse.contents = color.withAlphaComponent(row == 0 ? 1 : 0.85)
                m.emission.contents = color.withAlphaComponent(0.35)
                box.materials = [m]
                let node = SCNNode(geometry: box)
                node.position = SCNVector3(x0 + Float(i) * pitch, Float(h) / 2, row == 0 ? 0.22 : -0.22)
                chart.addChildNode(node)
            }
        }
        // floor line
        let floor = SCNNode(geometry: SCNBox(width: CGFloat(Float(n) * pitch + 0.3), height: 0.01, length: 0.9, chamferRadius: 0))
        floor.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.06)
        floor.geometry?.firstMaterial?.lightingModel = .constant
        chart.addChildNode(floor)

        chart.runAction(.repeatForever(.sequence([
            .rotateBy(x: 0, y: 0.35, z: 0, duration: 4),
            .rotateBy(x: 0, y: -0.35, z: 0, duration: 4),
        ])))
        chart.eulerAngles.y = -0.45

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.eulerAngles = SCNVector3(-Float.pi / 3, 0.6, 0)
        scene.rootNode.addChildNode(sun)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 30
        camera.position = SCNVector3(0, 3.6, 6.2)
        camera.look(at: SCNVector3(0, 0.35, 0))
        scene.rootNode.addChildNode(camera)
        return scene
    }
}

// MARK: - Full Countdown tab in the blended style

/// The whole Countdown tab, laid out at full length and shifted up by
/// `page` slices so the simulator can capture it in pieces for stitching.
struct FullDraft: View {
    var page = 0
    static let step: CGFloat = 714

    var body: some View {
        GeometryReader { geo in
            // A fixed frame pins the overflowing page to the top edge.
            content
                .fixedSize(horizontal: false, vertical: true)
                .offset(y: -CGFloat(page) * Self.step)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(Theme.background)
        .ignoresSafeArea()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderView(onInfo: {})
                .padding(.bottom, -6)
            hero
            countdown
            BlendDraft(embedded: true).padding(.top, 8)
            schedule
            alerts
            VStack(alignment: .leading, spacing: 14) {
                SectionRule(number: "06", name: "PADDOCK", meta: "INVITE")
                InviteBanner()
            }
            .padding(.top, 8)
            circuit
            standings
            season
            mono("TEAM RADIO · UNOFFICIAL FAN APP · NOT ASSOCIATED WITH FORMULA 1", Theme.faintText, 8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        }
        .padding(.horizontal, 16)
        .padding(.top, 58)
        .background(alignment: .top) { ambient }
    }

    /// Soft coloured light down the page, so the glass has something to bend.
    private var ambient: some View {
        ZStack(alignment: .top) {
            Ellipse().fill(Theme.accent).frame(width: 380, height: 300).blur(radius: 120).opacity(0.28).offset(x: -120, y: 260)
            Ellipse().fill(Theme.live).frame(width: 300, height: 260).blur(radius: 120).opacity(0.22).offset(x: 140, y: 900)
            Ellipse().fill(Theme.violet).frame(width: 360, height: 300).blur(radius: 130).opacity(0.25).offset(x: -110, y: 2100)
            Ellipse().fill(Theme.accent).frame(width: 320, height: 280).blur(radius: 130).opacity(0.2).offset(x: 120, y: 3000)
            Ellipse().fill(Theme.live).frame(width: 300, height: 260).blur(radius: 130).opacity(0.18).offset(x: -100, y: 3900)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Race hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ROUND 18").font(.f1(13, weight: .bold)).tracking(2).foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accentGradient))
                Spacer()
                mono("2026 · 23–25 OCT", Theme.dimText, 11)
            }
            Text("UNITED STATES\nGRAND PRIX").font(.f1(34)).foregroundStyle(Theme.chromeText)
            Text("🇺🇸  Circuit of the Americas · Austin").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 0) {
                stat("LENGTH", "5.513 KM")
                stat("LAPS", "56")
                stat("TURNS", "20")
                stat("RECORD", "1:36.169")
            }
            .padding(.top, 4)
        }
        .padding(20)
        .padding(.top, 34)
        .glassPanel(RoundedRectangle(cornerRadius: 30), light: Theme.accent, lightOffset: CGSize(width: -60, height: 0))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            mono(label, Theme.faintText, 9)
            Text(value).font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) { Rectangle().fill(hair).frame(width: 0.5).offset(x: -8) }
    }

    // MARK: Countdown

    private var countdown: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                chip("FP1", selected: true, color: Theme.accent)
                chip("FP2", selected: false, color: Theme.accent)
                chip("FP3", selected: false, color: Theme.accent)
                chip("Q", selected: false, color: Theme.violet)
                chip("RACE", selected: false, color: Theme.live)
            }
            mono("PRACTICE 1 · FRIDAY 19:30", Theme.dimText, 11)
            DotMatrixBoard(litLights: 5).alignedToContent().allowsHitTesting(false)
            HStack(spacing: 0) {
                unit("11", "DAYS")
                unit("09", "HRS")
                unit("31", "MIN")
                unit("33", "SEC", live: true)
            }
            Label("PIN FP1 TO LOCK SCREEN", systemImage: "pin.fill")
                .font(.f1(13, weight: .bold)).tracking(1.5).foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .modifier(GlassSurface(shape: AnyShape(Capsule()), tint: nil))
        }
        .padding(18)
        .glassPanel(RoundedRectangle(cornerRadius: 30), light: Theme.live, lightOffset: CGSize(width: 110, height: 90))
    }

    private func chip(_ s: String, selected: Bool, color: Color) -> some View {
        Text(s).font(.f1(14)).foregroundStyle(selected ? .white : color)
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .modifier(GlassSurface(shape: AnyShape(Capsule()), tint: selected ? color.opacity(0.6) : nil))
    }

    private func unit(_ value: String, _ label: String, live: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.f1Digits(46))
                .foregroundStyle(live ? AnyShapeStyle(Theme.liveGradient) : AnyShapeStyle(Theme.chromeText))
                .shadow(color: (live ? Theme.live : Theme.accent).opacity(0.5), radius: 10)
            mono(label, live ? Theme.live : Theme.dimText, 10)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if !live { Rectangle().fill(hair).frame(width: 0.5, height: 50) }
        }
    }

    // MARK: Schedule

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionRule(number: "04", name: "WEEKEND SCHEDULE", meta: "YOUR TIME")
            VStack(spacing: 0) {
                session("FRI", "PRACTICE 1", "19:30", "sun.max.fill", "28°", next: true)
                session("FRI", "PRACTICE 2", "23:00", "cloud.sun.fill", "26°")
                session("SAT", "PRACTICE 3", "19:30", "sun.max.fill", "29°")
                session("SAT", "QUALIFYING", "23:00", "cloud.fill", "25°", color: Theme.violet)
                session("SUN", "RACE", "21:00", "cloud.sun.fill", "27°", color: Theme.live, last: true)
            }
            .padding(.horizontal, 18).padding(.vertical, 6)
            .glassPanel(RoundedRectangle(cornerRadius: 26), light: Theme.violet, lightOffset: CGSize(width: 90, height: 0))
        }
        .padding(.top, 8)
    }

    private func session(_ day: String, _ name: String, _ time: String, _ symbol: String, _ temp: String,
                         color: Color = .white, next: Bool = false, last: Bool = false) -> some View {
        HStack(spacing: 12) {
            Capsule().fill(next ? Theme.accent : .clear).frame(width: 3, height: 22)
                .shadow(color: Theme.accent, radius: next ? 4 : 0)
            mono(day, Theme.dimText, 11).frame(width: 34, alignment: .leading)
            Text(name).font(.f1(15)).foregroundStyle(next ? Theme.accent : color).lineLimit(1).fixedSize()
            Spacer()
            Image(systemName: symbol).symbolRenderingMode(.multicolor).font(.system(size: 13))
            mono(temp, Theme.dimText, 11).frame(width: 30, alignment: .trailing)
            Text(time).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(.white).fixedSize()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(hair).frame(height: 0.5) } }
    }

    // MARK: Alerts

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionRule(number: "05", name: "ALERTS", meta: "3 ON", metaColor: Theme.accent)
            VStack(spacing: 0) {
                toggle("Session starts", "15 min before each session", on: true)
                toggle("Qualifying results", "Grid as soon as it's set", on: true)
                toggle("Race results", "Podium and points", on: true)
                VStack(alignment: .leading, spacing: 10) {
                    mono("LOCK SCREEN COUNTDOWN", Theme.dimText)
                    HStack(spacing: 6) {
                        chip("OFF", selected: false, color: Theme.dimText)
                        chip("15M", selected: false, color: Theme.accent)
                        chip("1H", selected: true, color: Theme.accent)
                        chip("3H", selected: false, color: Theme.accent)
                    }
                }
                .padding(.vertical, 14)
            }
            .padding(.horizontal, 18).padding(.vertical, 4)
            .glassPanel(RoundedRectangle(cornerRadius: 26), light: Theme.accent, lightOffset: CGSize(width: -90, height: 20))
        }
        .padding(.top, 8)
    }

    private func toggle(_ title: String, _ sub: String, on: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(sub).font(.system(size: 12)).foregroundStyle(Theme.dimText)
            }
            Spacer()
            Toggle("", isOn: .constant(on)).labelsHidden().tint(Theme.accent)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(hair).frame(height: 0.5) }
    }

    // MARK: Circuit

    private var circuit: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionRule(number: "07", name: "CIRCUIT", meta: "COTA · AUSTIN")
            VStack(spacing: 16) {
                TrackSketch()
                    .frame(height: 190)
                HStack(spacing: 14) {
                    sector("S1", Theme.live)
                    sector("S2", Theme.accent)
                    sector("S3", Color(red: 1, green: 0.85, blue: 0.3))
                    Spacer()
                    mono("DRS ZONES 2", Theme.dimText)
                }
                HStack(spacing: 0) {
                    stat("ELEVATION", "41 M")
                    stat("TOP SPEED", "322")
                    stat("FIRST GP", "2012")
                    stat("OVERTAKES", "64")
                }
            }
            .padding(18)
            .glassPanel(RoundedRectangle(cornerRadius: 26), light: Theme.accent, lightOffset: CGSize(width: 80, height: -20))
        }
        .padding(.top, 8)
    }

    private func sector(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(color).frame(width: 14, height: 3).shadow(color: color, radius: 3)
            mono(name, .white, 10)
        }
    }

    // MARK: Standings

    private var standings: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionRule(number: "08", name: "DRIVERS' STANDINGS", meta: "AFTER R17")
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        mono("LEADER · PIASTRI", Theme.dimText)
                        LEDText(text: "346", pitch: 6.5, color: papaya)
                    }
                    Spacer()
                    mono("+14 PTS", Theme.accent, 12)
                }
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) { Rectangle().fill(hair).frame(height: 0.5) }
                driver(1, "PIA", "PIASTRI", papaya, "346", "—")
                driver(2, "NOR", "NORRIS", papaya, "332", "−14")
                driver(3, "VER", "VERSTAPPEN", Color(red: 0.25, green: 0.35, blue: 0.95), "306", "−40")
                driver(4, "RUS", "RUSSELL", mercedes, "252", "−94")
                driver(5, "LEC", "LECLERC", Color(red: 0.93, green: 0.1, blue: 0.14), "192", "−154", last: true)
            }
            .padding(.horizontal, 18).padding(.vertical, 4)
            .glassPanel(RoundedRectangle(cornerRadius: 26), light: papaya, lightOffset: CGSize(width: -80, height: -60))
            Text("FULL STANDINGS →").font(.f1(13).italic()).tracking(1.5).foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.top, 8)
    }

    private func driver(_ pos: Int, _ code: String, _ name: String, _ team: Color, _ pts: String, _ gap: String, last: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text("\(pos)").font(.f1Digits(16)).foregroundStyle(pos == 1 ? Theme.accent : Theme.dimText).frame(width: 22, alignment: .leading)
            Capsule().fill(team).frame(width: 3, height: 18)
            Text(code).font(.f1(17)).foregroundStyle(.white).frame(width: 46, alignment: .leading)
            mono(name, Theme.faintText)
            Spacer()
            mono(gap, Theme.faintText, 11).frame(width: 40, alignment: .trailing)
            Text(pts).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(.white).frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(hair).frame(height: 0.5) } }
    }

    // MARK: Season

    private var season: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionRule(number: "09", name: "SEASON 2026", meta: "18 / 24", metaColor: Theme.accent)
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 12), spacing: 10) {
                    ForEach(1...24, id: \.self) { r in
                        Circle()
                            .fill(r < 18 ? Color.white.opacity(0.55) : (r == 18 ? Theme.accent : Color.white.opacity(0.07)))
                            .frame(width: 12, height: 12)
                            .shadow(color: r == 18 ? Theme.accent : .clear, radius: 6)
                    }
                }
                VStack(spacing: 0) {
                    race("R19", "MEXICO CITY", "30 OCT – 1 NOV")
                    race("R20", "SÃO PAULO", "7 – 9 NOV")
                    race("R21", "LAS VEGAS", "20 – 22 NOV", last: true)
                }
            }
            .padding(18)
            .glassPanel(RoundedRectangle(cornerRadius: 26), light: Theme.live, lightOffset: CGSize(width: 90, height: 30))
        }
        .padding(.top, 8)
    }

    private func race(_ round: String, _ name: String, _ dates: String, last: Bool = false) -> some View {
        HStack(spacing: 12) {
            mono(round, Theme.dimText, 11).frame(width: 34, alignment: .leading)
            Text(name).font(.f1(15)).foregroundStyle(.white)
            Spacer()
            mono(dates, Theme.dimText, 11)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(hair).frame(height: 0.5) } }
    }
}

/// A rough COTA outline split into three coloured sectors, for the draft only.
private struct TrackSketch: View {
    private let points: [CGPoint] = [
        .init(x: 0.20, y: 0.66), .init(x: 0.10, y: 0.52), .init(x: 0.14, y: 0.38), .init(x: 0.22, y: 0.44),
        .init(x: 0.28, y: 0.32), .init(x: 0.34, y: 0.42), .init(x: 0.40, y: 0.30), .init(x: 0.47, y: 0.38),
        .init(x: 0.52, y: 0.20), .init(x: 0.70, y: 0.14), .init(x: 0.93, y: 0.10), .init(x: 0.96, y: 0.24),
        .init(x: 0.86, y: 0.34), .init(x: 0.78, y: 0.30), .init(x: 0.72, y: 0.44), .init(x: 0.80, y: 0.56),
        .init(x: 0.72, y: 0.74), .init(x: 0.56, y: 0.82), .init(x: 0.44, y: 0.74), .init(x: 0.34, y: 0.86),
        .init(x: 0.24, y: 0.78),
    ]

    var body: some View {
        GeometryReader { geo in
            let path = smooth(in: geo.size)
            ZStack {
                path.stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                path.trimmedPath(from: 0, to: 0.34).stroke(Theme.live, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: Theme.live, radius: 5)
                path.trimmedPath(from: 0.34, to: 0.68).stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: Theme.accent, radius: 5)
                path.trimmedPath(from: 0.68, to: 1).stroke(Color(red: 1, green: 0.85, blue: 0.3), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: Color(red: 1, green: 0.85, blue: 0.3), radius: 5)
                let start = scaled(points[0], geo.size)
                Circle().fill(.white).frame(width: 8, height: 8).position(start).shadow(color: .white, radius: 4)
            }
        }
    }

    private func scaled(_ p: CGPoint, _ size: CGSize) -> CGPoint { CGPoint(x: p.x * size.width, y: p.y * size.height) }

    /// Closed curve through the midpoints, corners rounded by quad curves.
    private func smooth(in size: CGSize) -> Path {
        let pts = points.map { scaled($0, size) }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        var p = Path()
        p.move(to: mid(pts[pts.count - 1], pts[0]))
        for i in 0..<pts.count {
            p.addQuadCurve(to: mid(pts[i], pts[(i + 1) % pts.count]), control: pts[i])
        }
        p.closeSubpath()
        return p
    }
}
#endif
