#if DEBUG
import SwiftUI

// Debug-only draft: the Countdown feature cards as a blend of liquid glass,
// telemetry data and the app's own LED board, in the current app palette.
// Nothing here ships.

private let led = Color(red: 1, green: 0.42, blue: 0.12)        // the board's amber-red LEDs
private let mercedes = Color(red: 0, green: 0.85, blue: 0.75)
private let papaya = Color(red: 1, green: 0.53, blue: 0)
private let hair = Color.white.opacity(0.12)
private let reactionHistory: [Double] = [0.312, 0.268, 0.290, 0.241, 0.255, 0.226, 0.233, 0.211, 0.204, 0.198]

// MARK: - LED type (5×7, like the main board)

private let ledGlyphs: [Character: [String]] = [
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    ".": [".", ".", ".", ".", ".", ".", "#"],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
]

/// Text in round LEDs with dim sockets, glowing like the countdown board.
private struct LEDText: View {
    let text: String
    var pitch: CGFloat = 5.5
    var color: Color = led

    private var glyphs: [[String]] { text.compactMap { ledGlyphs[$0] } }
    private var columns: Int { glyphs.reduce(0) { $0 + $1[0].count } + max(0, glyphs.count - 1) }

    var body: some View {
        Canvas { ctx, _ in
            let d = pitch * 0.72
            var x: CGFloat = 0
            for glyph in glyphs {
                for (r, row) in glyph.enumerated() {
                    for (c, ch) in row.enumerated() {
                        let rect = CGRect(x: x + CGFloat(c) * pitch, y: CGFloat(r) * pitch, width: d, height: d)
                        ctx.fill(Path(ellipseIn: rect), with: .color(ch == "#" ? color : .white.opacity(0.05)))
                    }
                }
                x += CGFloat(glyph[0].count + 1) * pitch
            }
        }
        .frame(width: CGFloat(columns) * pitch, height: 7 * pitch)
        .shadow(color: color.opacity(0.75), radius: pitch * 0.8)
    }
}

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

    private var sections: some View {
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
