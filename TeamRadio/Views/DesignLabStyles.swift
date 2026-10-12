#if DEBUG
import SwiftUI

// Debug-only: the same four Countdown features drawn in four visual
// languages, to pick a direction. Nothing here ships.

private let mercedesTeal = Color(red: 0, green: 0.85, blue: 0.75)
private let ferrariRed = Color(red: 0.93, green: 0.1, blue: 0.14)
private let redbullBlue = Color(red: 0.3, green: 0.4, blue: 1)
private let papaya = Color(red: 1, green: 0.53, blue: 0)
private let attempts: [Double] = [0.312, 0.268, 0.290, 0.241, 0.255, 0.226, 0.233, 0.211, 0.204, 0.198]

private struct EmilyFace: View {
    var size: CGFloat
    var body: some View {
        Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
            .frame(width: size, height: size).clipShape(Circle())
    }
}

// MARK: - 1. Liquid glass

struct StyleGlass: View {
    private let primary = Color.white
    private let secondary = Color.white.opacity(0.6)

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.035, blue: 0.05)
            // ambient light for the glass to bend
            Circle().fill(Color(red: 0.2, green: 0.45, blue: 1)).frame(width: 360).blur(radius: 90).offset(x: -130, y: -250)
            Circle().fill(Color(red: 0.55, green: 0.3, blue: 1)).frame(width: 300).blur(radius: 100).offset(x: 160, y: 60)
            Circle().fill(Theme.live).frame(width: 260).blur(radius: 110).offset(x: -110, y: 360).opacity(0.75)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Singapore").font(.system(size: 34, weight: .bold)).foregroundStyle(primary)
                    Text("Round 17 · Race in 2d 4h").font(.system(size: 15)).foregroundStyle(secondary)
                }
                .padding(.bottom, 6)
                picks
                HStack(spacing: 14) { dotd; lights }
                emily
            }
            .padding(.horizontal, 20)
            .padding(.top, 70)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    private var picks: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Your picks").font(.system(size: 17, weight: .semibold)).foregroundStyle(primary)
                Spacer()
                Label("Locks Sat 15:00", systemImage: "lock.fill").font(.system(size: 13)).foregroundStyle(secondary)
            }
            HStack {
                pick("Pole", "NOR", papaya)
                pick("Winner", "PIA", papaya)
                pick("Fastest lap", "—", .clear)
            }
            Text("Finish picks").font(.system(size: 16, weight: .semibold)).foregroundStyle(primary)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .liquid(Capsule(), tint: Color(red: 0.2, green: 0.45, blue: 1).opacity(0.6))
        }
        .padding(20)
        .liquid(RoundedRectangle(cornerRadius: 32))
    }

    private func pick(_ label: String, _ code: String, _ team: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(secondary)
            Text(code).font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(primary)
            Capsule().fill(team).frame(width: 22, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dotd: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Driver of the Day").font(.system(size: 13)).foregroundStyle(secondary)
            Text("ANT").font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(primary)
            Text("52% of fans").font(.system(size: 13)).foregroundStyle(secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(mercedesTeal).frame(width: geo.size.width * 0.52)
                }
            }
            .frame(height: 5)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquid(RoundedRectangle(cornerRadius: 28))
    }

    private var lights: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lights Out").font(.system(size: 13)).foregroundStyle(secondary)
            Text("0.198").font(.system(size: 34, weight: .light, design: .rounded).monospacedDigit()).foregroundStyle(primary)
            Text("Best · #4 this week").font(.system(size: 13)).foregroundStyle(secondary)
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle().fill(Theme.live).frame(width: 9, height: 9).shadow(color: Theme.live, radius: 4)
                }
            }
            .frame(height: 5)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquid(RoundedRectangle(cornerRadius: 28))
    }

    private var emily: some View {
        HStack(spacing: 12) {
            EmilyFace(size: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text("Ask Emily").font(.system(size: 16, weight: .semibold)).foregroundStyle(primary)
                Text("Your AI race engineer").font(.system(size: 13)).foregroundStyle(secondary)
            }
            Spacer()
            Image(systemName: "mic.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(primary)
                .frame(width: 44, height: 44)
                .liquid(Circle(), tint: Color(red: 0.55, green: 0.3, blue: 1).opacity(0.5))
        }
        .padding(8).padding(.trailing, 2)
        .liquid(Capsule())
    }
}

private extension View {
    @ViewBuilder
    func liquid(_ shape: some Shape, tint: Color? = nil) -> some View {
        if #available(iOS 26, *) {
            glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - 2. F1 telemetry HUD

struct StyleTelemetry: View {
    private let accent = Color(red: 0.84, green: 1, blue: 0.22)
    private let dim = Color.white.opacity(0.45)
    private let hair = Color.white.opacity(0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                mono("R17 · SINGAPORE", dim)
                Spacer()
                mono("RACE  T−2D 04:31:07", accent)
            }
            .padding(.bottom, 10)
            ruler
            section("01", "PREDICTIONS", trailing: "LOCK SAT 15:00") { picks }
            section("02", "LIGHTS OUT", trailing: "LAST 10 STARTS") { lights }
            section("03", "DRIVER OF THE DAY", trailing: "412 VOTES") { dotd }
            section("04", "RADIO · EMILY", trailing: "AI") { radio }
        }
        .padding(.horizontal, 20)
        .padding(.top, 66)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.024, green: 0.027, blue: 0.031))
        .ignoresSafeArea()
    }

    private func mono(_ s: String, _ c: Color, _ size: CGFloat = 10) -> some View {
        Text(s).font(.system(size: size, weight: .medium, design: .monospaced)).tracking(1.2).foregroundStyle(c)
    }

    private func title(_ s: String, _ size: CGFloat = 22) -> some View {
        Text(s).font(.system(size: size, weight: .bold).width(.condensed)).foregroundStyle(.white)
    }

    /// Hairline with tick marks, like a measuring rule.
    private var ruler: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(x: 0, y: size.height - 0.5, width: size.width, height: 0.5)), with: .color(hair))
            var x: CGFloat = 0, i = 0
            while x <= size.width {
                let h: CGFloat = i % 10 == 0 ? 6 : 3
                ctx.fill(Path(CGRect(x: x, y: size.height - h, width: 0.5, height: h)), with: .color(i % 10 == 0 ? dim : hair))
                x += 6; i += 1
            }
        }
        .frame(height: 6)
    }

    private func section<C: View>(_ n: String, _ name: String, trailing: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                mono("\(n) / \(name)", dim)
                Spacer()
                mono(trailing, dim)
            }
            content()
            Rectangle().fill(hair).frame(height: 0.5)
        }
        .padding(.top, 16)
    }

    private var picks: some View {
        VStack(spacing: 0) {
            row("POLE", "NOR", "NORRIS", papaya, ai: "NOR")
            row("P1", "PIA", "PIASTRI", papaya, ai: "NOR")
            row("FL", "—", "OPEN", .clear, ai: "VER")
            HStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle().fill(i < 3 ? accent : hair).frame(height: 3)
                }
            }
            .padding(.top, 10)
        }
    }

    private func row(_ slot: String, _ code: String, _ name: String, _ team: Color, ai: String) -> some View {
        HStack(spacing: 10) {
            mono(slot, dim, 11).frame(width: 40, alignment: .leading)
            Rectangle().fill(team).frame(width: 2, height: 16)
            title(code, 20).frame(width: 48, alignment: .leading)
            mono(name, dim)
            Spacer()
            mono("AI \(ai)", dim)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(hair).frame(height: 0.5) }
    }

    private var lights: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("0.198").font(.system(size: 44, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                mono("PERSONAL BEST · P4 WK", accent)
            }
            trace.frame(height: 64)
        }
    }

    /// Reaction times of the last ten starts, best marked.
    private var trace: some View {
        Canvas { ctx, size in
            let lo = 0.18, hi = 0.33
            let pts = attempts.enumerated().map { i, v in
                CGPoint(x: size.width * CGFloat(i) / CGFloat(attempts.count - 1),
                        y: size.height * CGFloat((v - lo) / (hi - lo)))
            }
            var line = Path()
            line.addLines(pts)
            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            ctx.fill(fill, with: .linearGradient(Gradient(colors: [accent.opacity(0.25), .clear]),
                                                 startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            ctx.stroke(line, with: .color(accent), lineWidth: 1.5)
            if let last = pts.last {
                ctx.fill(Path(ellipseIn: CGRect(x: last.x - 3.5, y: last.y - 3.5, width: 7, height: 7)), with: .color(accent))
            }
            for y in stride(from: 0, through: size.height, by: size.height / 3) {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(hair))
            }
        }
    }

    private var dotd: some View {
        VStack(spacing: 8) {
            bar("ANT", 0.52, leader: true)
            bar("LEC", 0.24, leader: false)
            bar("VER", 0.18, leader: false)
        }
    }

    private func bar(_ code: String, _ pct: Double, leader: Bool) -> some View {
        HStack(spacing: 10) {
            title(code, 17).frame(width: 40, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(hair)
                    Rectangle().fill(leader ? accent : Color.white.opacity(0.55)).frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 4)
            mono(String(format: "%02d%%", Int(pct * 100)), leader ? accent : dim, 12).frame(width: 34, alignment: .trailing)
        }
    }

    private var radio: some View {
        HStack(spacing: 14) {
            Canvas { ctx, size in
                var p = Path()
                for x in stride(from: 0, through: size.width, by: 1) {
                    let t = x / size.width
                    let env = sin(Double(t) * .pi)
                    let y = size.height / 2 + CGFloat(sin(Double(x) * 0.22) * 0.6 + sin(Double(x) * 0.07) * 0.4) * size.height * 0.45 * CGFloat(env)
                    x == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                }
                ctx.stroke(p, with: .color(accent), lineWidth: 1.2)
            }
            .frame(height: 36)
            VStack(alignment: .trailing, spacing: 3) {
                title("ASK EMILY", 17)
                mono("PUSH TO TALK", dim)
            }
            Circle().stroke(accent, lineWidth: 1.5).frame(width: 40, height: 40)
                .overlay(Image(systemName: "mic.fill").font(.system(size: 14)).foregroundStyle(accent))
        }
    }
}

// MARK: - 3. Industrial dot-matrix

/// 3×5 dot glyphs, top row first.
private let dotGlyphs: [Character: [String]] = [
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", "###", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", "..#", "..#", "..#"],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
    ".": [".", ".", ".", ".", "#"], "%": ["#.#", "..#", ".#.", "#..", "#.#"],
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "T": ["###", ".#.", ".#.", ".#.", ".#."], "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"], "P": ["##.", "#.#", "##.", "#..", "#.."],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "E": ["###", "#..", "##.", "#..", "###"], "-": ["...", "...", "###", "...", "..."],
    " ": ["..", "..", "..", "..", ".."],
]

/// Text drawn as round LEDs, unlit dots faintly visible.
private struct DotText: View {
    let text: String
    var dot: CGFloat = 5
    var color: Color = .black
    var off: Color = .black.opacity(0.025)

    private var glyphs: [[String]] { text.compactMap { dotGlyphs[$0] } }
    private var columns: Int { glyphs.reduce(0) { $0 + $1[0].count } + max(0, glyphs.count - 1) }
    private var pitch: CGFloat { dot * 1.45 }

    var body: some View {
        Canvas { ctx, _ in
            var x: CGFloat = 0
            for glyph in glyphs {
                for (r, row) in glyph.enumerated() {
                    for (c, ch) in row.enumerated() {
                        let rect = CGRect(x: x + CGFloat(c) * pitch, y: CGFloat(r) * pitch, width: dot, height: dot)
                        ctx.fill(Path(ellipseIn: rect), with: .color(ch == "#" ? color : off))
                    }
                }
                x += CGFloat(glyph[0].count + 1) * pitch
            }
        }
        .frame(width: CGFloat(columns) * pitch, height: 5 * pitch)
    }
}

struct StyleDotMatrix: View {
    private let paper = Color(red: 0.925, green: 0.925, blue: 0.91)
    private let card = Color(red: 0.99, green: 0.99, blue: 0.985)
    private let ink = Color(red: 0.08, green: 0.08, blue: 0.08)
    private let grey = Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0.45)
    private let red = Color(red: 0.86, green: 0.1, blue: 0.08)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                label("TEAM RADIO", ink)
                Spacer()
                Circle().fill(red).frame(width: 7, height: 7)
                label("R17 SINGAPORE", ink)
            }
            .padding(.bottom, 8)
            picks
            HStack(spacing: 12) { dotd; lights }
            emily
        }
        .padding(.horizontal, 16)
        .padding(.top, 66)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(paper)
        .ignoresSafeArea()
    }

    private func label(_ s: String, _ c: Color) -> some View {
        Text(s).font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(1.2).foregroundStyle(c)
    }

    private func panel<C: View>(_ fill: Color, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 26).fill(fill).shadow(color: .black.opacity(0.07), radius: 14, y: 6))
    }

    private var picks: some View {
        panel(card) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    label("PREDICTIONS", grey)
                    Spacer()
                    label("LOCKS SAT 15:00", red)
                }
                HStack(alignment: .bottom) {
                    slot("POLE", "NOR")
                    slot("WIN", "PIA")
                    slot("F.LAP", "-")
                }
                HStack {
                    label("3 OF 6 PICKED", grey)
                    Spacer()
                    Text("FINISH →").font(.system(size: 12, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(card)
                        .padding(.horizontal, 16).padding(.vertical, 10).background(Capsule().fill(ink))
                }
            }
        }
    }

    private func slot(_ label: String, _ code: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            self.label(label, grey)
            DotText(text: code, dot: 6, color: ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dotd: some View {
        panel(card) {
            VStack(alignment: .leading, spacing: 12) {
                label("DRIVER OF\nTHE DAY", grey)
                DotText(text: "52%", dot: 6.5, color: ink)
                label("ANT LEADS", ink)
                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { i in Circle().fill(i < 5 ? red : ink.opacity(0.1)).frame(width: 7, height: 7) }
                }
            }
        }
    }

    private var lights: some View {
        panel(ink) {
            VStack(alignment: .leading, spacing: 12) {
                label("LIGHTS\nOUT", .white.opacity(0.5))
                DotText(text: "0.198", dot: 6, color: .white, off: .white.opacity(0.03))
                label("BEST · #4", .white.opacity(0.8))
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { _ in Circle().fill(red).frame(width: 12, height: 12) }
                }
            }
        }
    }

    private var emily: some View {
        panel(card) {
            HStack(spacing: 14) {
                EmilyFace(size: 52).saturation(0)
                VStack(alignment: .leading, spacing: 4) {
                    Text("EMILY").font(.system(size: 15, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(ink)
                    label("AI RACE ENGINEER", grey)
                }
                Spacer()
                Image(systemName: "mic.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 50, height: 50).background(Circle().fill(red))
            }
        }
    }
}

// MARK: - 4. Sci-fi interface

struct StyleSciFi: View {
    private let line = Color(red: 0.72, green: 0.93, blue: 1)
    private let faint = Color(red: 0.72, green: 0.93, blue: 1).opacity(0.35)

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.05, blue: 0.065)
            RadialGradient(colors: [line.opacity(0.08), .clear], center: .init(x: 0.5, y: 0.3), startRadius: 0, endRadius: 360)
            VStack(spacing: 26) {
                HStack {
                    thin("TEAM RADIO // R17", 11)
                    Spacer()
                    thin("T−2D 04:31:07", 11)
                }
                gauge
                dotd
                picks
                emily
            }
            .padding(.horizontal, 22)
            .padding(.top, 66)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    private func thin(_ s: String, _ size: CGFloat, _ c: Color? = nil) -> some View {
        Text(s).font(.system(size: size, weight: .light)).tracking(size * 0.3).foregroundStyle(c ?? faint)
    }

    /// Lights out as a circular instrument: ticks, five lights on the arc, best time in the middle.
    private var gauge: some View {
        let r: CGFloat = 112
        return ZStack {
            Circle().stroke(faint, lineWidth: 0.6).frame(width: r * 2, height: r * 2)
            Circle().stroke(line.opacity(0.2), style: StrokeStyle(lineWidth: 0.6, dash: [2, 4])).frame(width: r * 1.62, height: r * 1.62)
            Circle().trim(from: 0.62, to: 0.88).stroke(line, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: r * 2 + 14, height: r * 2 + 14)
                .shadow(color: line, radius: 3)
            ForEach(0..<72, id: \.self) { i in
                Rectangle().fill(i % 6 == 0 ? line : faint)
                    .frame(width: 0.8, height: i % 6 == 0 ? 9 : 4)
                    .offset(y: -r + 6)
                    .rotationEffect(.degrees(Double(i) * 5))
            }
            ForEach(0..<5, id: \.self) { i in
                let a = Double(i - 2) * 20 * .pi / 180
                Circle().fill(Theme.live).frame(width: 9, height: 9)
                    .shadow(color: Theme.live, radius: 5)
                    .offset(x: CGFloat(sin(a)) * (r - 26), y: -CGFloat(cos(a)) * (r - 26))
            }
            VStack(spacing: 4) {
                Text("0.198").font(.system(size: 54, weight: .ultraLight).monospacedDigit()).foregroundStyle(.white)
                    .shadow(color: line.opacity(0.5), radius: 6)
                thin("BEST REACTION", 9)
                thin("LIGHTS OUT  ▸", 11, line).padding(.top, 6)
            }
        }
        .frame(height: r * 2 + 20)
    }

    private var dotd: some View {
        VStack(spacing: 12) {
            thin("DRIVER OF THE DAY", 10)
            HStack(spacing: 26) {
                ring("ANT", 0.52, highlight: true)
                ring("LEC", 0.24, highlight: false)
                ring("VER", 0.18, highlight: false)
            }
        }
    }

    private func ring(_ code: String, _ pct: Double, highlight: Bool) -> some View {
        ZStack {
            Circle().stroke(faint, lineWidth: 0.6)
            Circle().trim(from: 0, to: pct).stroke(highlight ? line : faint, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: highlight ? line : .clear, radius: 3)
            VStack(spacing: 0) {
                Text(code).font(.system(size: 13, weight: .regular)).tracking(2).foregroundStyle(.white)
                Text("\(Int(pct * 100))").font(.system(size: 11, weight: .light).monospacedDigit()).foregroundStyle(faint)
            }
        }
        .frame(width: 62, height: 62)
    }

    private var picks: some View {
        VStack(spacing: 10) {
            HStack {
                thin("PREDICTIONS", 10)
                Spacer()
                thin("LOCK SAT 15:00", 10)
            }
            pickRow("POLE", "NOR")
            pickRow("WINNER", "PIA")
            pickRow("FASTEST LAP", "— —")
        }
    }

    private func pickRow(_ label: String, _ code: String) -> some View {
        HStack(spacing: 10) {
            Text("+").font(.system(size: 12, weight: .ultraLight)).foregroundStyle(line)
            thin(label, 11, .white.opacity(0.75))
            Rectangle().fill(faint).frame(height: 0.5)
            Text(code).font(.system(size: 15, weight: .regular)).tracking(3).foregroundStyle(.white)
        }
    }

    private var emily: some View {
        HStack(spacing: 14) {
            EmilyFace(size: 46)
                .saturation(0.3)
                .overlay(Circle().stroke(line, lineWidth: 0.8).padding(-5))
                .shadow(color: line.opacity(0.5), radius: 4)
            VStack(alignment: .leading, spacing: 3) {
                thin("EMILY // ONLINE", 12, .white)
                thin("AI RACE ENGINEER · TAP TO TALK", 9)
            }
            Spacer()
        }
        .padding(.leading, 5)
    }
}
#endif
