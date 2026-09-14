import SwiftUI
import UIKit

/// Cockpit hardware look for the countdown: carbon weave, neon-edged glass
/// tiles, hex screws and a dot-matrix LED board.

/// Pre-rendered carbon weave with a sweeping sheen (Assets/Carbon), so the
/// surface reads as one lit panel rather than a repeating tile.
struct CarbonFiber: View {
    var body: some View {
        Color.black.overlay(
            Image("Carbon")
                .resizable()
                .scaledToFill()
        )
        .clipped()
    }
}

/// Machine screw with a slot, catching light from the top-left.
struct Screw: View {
    var size: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.55), Color(white: 0.22), Color(white: 0.08)],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
            Circle()
                .strokeBorder(Color.black.opacity(0.8), lineWidth: 1)
            Capsule()
                .fill(Color.black.opacity(0.85))
                .frame(width: size * 0.7, height: size * 0.16)
                .rotationEffect(.degrees(-35))
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: size * 0.7, height: size * 0.06)
                .offset(y: -size * 0.09)
                .rotationEffect(.degrees(-35))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.8), radius: 1.5, y: 1)
    }
}

/// Neon-edged glass tile: white digits inside a cyan (or hot orange) rim.
struct NeonTile: View {
    let value: Int
    let label: String
    var tint: Color = Theme.accent
    var hot: Bool = false

    private var rim: Color { hot ? Theme.live : tint }

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.f1Digits(38))
                .foregroundStyle(hot ? AnyShapeStyle(Theme.liveGradient) : AnyShapeStyle(Theme.chromeText))
                .shadow(color: (hot ? Theme.live : .white).opacity(0.55), radius: 6)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.3), value: value)
            Text(label)
                .font(.f1(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(hot ? Theme.live.opacity(0.9) : Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Color(white: 0.03), Color(white: 0.09)], startPoint: .top, endPoint: .bottom))
                // glass sheen across the upper half
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
                // bloom behind the rim
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(rim.opacity(0.9), lineWidth: 3)
                    .blur(radius: 5)
                // the neon tube itself: bright core, tinted edge
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.95), rim, rim.opacity(0.8)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.2)
                RoundedRectangle(cornerRadius: 13)
                    .inset(by: 6)
                    .strokeBorder(rim.opacity(0.35), lineWidth: 1)
            }
        )
        .shadow(color: rim.opacity(0.5), radius: 12)
    }
}

/// The LED matrix: 24×4 sockets. At rest it shows the five start lights
/// (rounded blocks, lit from the left through race week). Tap it and it
/// scrambles like a sci-fi readout, resolves to the next info page (session
/// time, date, days to go, round) in cyan, then falls back to the lights.
struct DotMatrixBoard: View {
    let litLights: Int
    var pages: [String] = []
    var lightColor: Color = Theme.live
    var infoColor: Color = Color(red: 0.45, green: 0.9, blue: 1.0)

    // TEMP screenshot hook: `-DemoPage 1` opens on an info page.
    @State private var page = UserDefaults.standard.integer(forKey: "DemoPage")
    @State private var transitionStart: Date?
    @State private var settle: Task<Void, Never>?

    private static let cols = 24, rows = 4
    private static let scramble: TimeInterval = 0.9
    private static let hold: TimeInterval = 5

    // 3 columns × 4 rows, top row first
    private static let glyphs: [Character: String] = [
        "0": "####.##.####", "1": ".#.##..#.###", "2": "###..##..###", "3": "###.##..####",
        "4": "#.##.####..#", "5": "#####...####", "6": "#..####.####", "7": "###..#.#..#.",
        "8": "#######.####", "9": "####.####..#", "A": ".#.#.#####.#", "B": "##.####.###.",
        "C": "####..#..###", "D": "##.#.##.###.", "E": "#####.#..###", "F": "#####.#..#..",
        "G": "##.#..#.####", "H": "#.#####.##.#", "I": "###.#..#.###", "J": "..#..##.####",
        "K": "#.###.#.##.#", "L": "#..#..#..###", "M": "#.#####.##.#", "N": "##.#.##.##.#",
        "O": "####.##.####", "P": "####.#####..", "Q": "####.####..#", "R": "##.#.###.#.#",
        "S": ".###....###.", "T": "###.#..#..#.", "U": "#.##.##.####", "V": "#.##.##.#.#.",
        "W": "#.##.#####.#", "X": "#.#.#..#.#.#", "Y": "#.#.#..#..#.", "Z": "###..##..###",
        ":": "....#.....#.", "-": "...###......", ".": "..........#.", " ": "............",
    ]

    /// Cells lit by the current page: key row*1000+col → 1 (lit) or 0 (armed/dim).
    private func target(for page: Int) -> [Int: Double] {
        var cells: [Int: Double] = [:]
        if page == 0 {
            // five round 4×4 blocks (corners dark), one dark column between
            for c in 0..<5 {
                let c0 = c * 5
                for dc in 0..<4 {
                    for dr in 0..<4 {
                        let corner = (dc == 0 || dc == 3) && (dr == 0 || dr == 3)
                        guard !corner else { continue }
                        cells[dr * 1000 + c0 + dc] = c < litLights ? 1 : 0
                    }
                }
            }
        } else {
            let text = Array(pages[page - 1].uppercased().prefix(6))
            let width = text.count * 4 - 1
            var col = max(0, (Self.cols - width) / 2)
            for ch in text {
                let bits = Array(Self.glyphs[ch] ?? Self.glyphs[" "]!)
                for row in 0..<4 {
                    for k in 0..<3 where bits[row * 3 + k] == "#" && col + k < Self.cols {
                        cells[row * 1000 + col + k] = 1
                    }
                }
                col += 4
            }
        }
        return cells
    }

    /// Cheap deterministic noise in 0..<1 for the scramble frames.
    private static func noise(_ a: Int, _ b: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: a) &* 0x9E37_79B9_7F4A_7C15
        h ^= UInt64(truncatingIfNeeded: b) &* 0xBF58_476D_1CE4_E5B9
        h ^= h >> 29; h &*= 0x94D0_49BB_1331_11EB; h ^= h >> 32
        return Double(h % 10_000) / 10_000
    }

    private func advance() {
        guard !pages.isEmpty else { return }
        page = (page + 1) % (pages.count + 1)
        show()
    }

    private func show() {
        transitionStart = Date()
        settle?.cancel()
        settle = Task {
            try? await Task.sleep(for: .seconds(Self.scramble))
            guard !Task.isCancelled else { return }
            transitionStart = nil
            guard page != 0 else { return }
            try? await Task.sleep(for: .seconds(Self.hold))
            guard !Task.isCancelled else { return }
            page = 0
            transitionStart = Date()
            try? await Task.sleep(for: .seconds(Self.scramble))
            guard !Task.isCancelled else { return }
            transitionStart = nil
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: transitionStart == nil)) { context in
            Canvas { ctx, size in
                let cols = Self.cols, rows = Self.rows
                let pitch = size.width / CGFloat(cols)
                let top = (size.height - CGFloat(rows) * pitch) / 2
                let hole = pitch * 0.42
                let die = hole * 0.26            // side of one grey square in an unlit socket
                let dieStep = hole * 0.34

                func center(_ col: Int, _ row: Int) -> CGPoint {
                    CGPoint(x: CGFloat(col) * pitch + pitch / 2, y: top + CGFloat(row) * pitch + pitch / 2)
                }
                func rect(_ p: CGPoint, _ r: CGFloat) -> CGRect { CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r) }
                func disc(_ p: CGPoint, _ r: CGFloat, _ shading: GraphicsContext.Shading, in c: inout GraphicsContext) {
                    c.fill(Path(ellipseIn: rect(p, r)), with: shading)
                }

                // what's lit right now: the page, or the scramble resolving into it
                let goal = target(for: page)
                let color = page == 0 ? lightColor : infoColor
                var lit: [Int: Double] = [:]
                var armed: Set<Int> = []
                if let start = transitionStart {
                    let t = min(1, max(0, context.date.timeIntervalSince(start) / Self.scramble))
                    let frame = Int(context.date.timeIntervalSinceReferenceDate * 24)
                    let density = 0.45 * pow(1 - t, 1.6)
                    for r in 0..<rows {
                        for c in 0..<cols {
                            let key = r * 1000 + c
                            if let v = goal[key], v > 0, Self.noise(key, 7) < t * 1.3 {
                                lit[key] = 1
                            } else if Self.noise(key, frame) < density {
                                lit[key] = 0.6 + 0.4 * Self.noise(key, frame + 1)
                            } else if goal[key] == 0 {
                                armed.insert(key)
                            }
                        }
                    }
                } else {
                    for (key, v) in goal { if v > 0 { lit[key] = 1 } else { armed.insert(key) } }
                }

                // sockets: dark cavity with a faint rim; unlit ones show the 3×3 grey die
                for c in 0..<cols {
                    for r in 0..<rows {
                        let p = center(c, r)
                        let key = r * 1000 + c
                        disc(p, hole, .color(.black.opacity(0.85)), in: &ctx)
                        ctx.stroke(Path(ellipseIn: rect(CGPoint(x: p.x, y: p.y + 0.4), hole)), with: .color(.white.opacity(0.07)), lineWidth: 0.8)
                        if lit[key] == nil {
                            let tint: Color = armed.contains(key) ? lightColor.opacity(0.35) : .white.opacity(0.17)
                            for dx in -1...1 {
                                for dy in -1...1 {
                                    let q = CGPoint(x: p.x + CGFloat(dx) * dieStep, y: p.y + CGFloat(dy) * dieStep)
                                    ctx.fill(Path(roundedRect: CGRect(x: q.x - die / 2, y: q.y - die / 2, width: die, height: die), cornerRadius: die * 0.2), with: .color(tint))
                                }
                            }
                        }
                    }
                }

                // lit LEDs: soft halo outside, light caught on the cavity wall, a big soft-edged core
                let glowing = lit.map { (center($0.key % 1000, $0.key / 1000), $0.value) }
                ctx.drawLayer { layer in
                    layer.blendMode = .plusLighter
                    layer.addFilter(.blur(radius: hole * 0.9))
                    for (p, k) in glowing { disc(p, hole * 1.3, .color(color.opacity(0.55 * k)), in: &layer) }
                }
                ctx.drawLayer { layer in
                    layer.blendMode = .plusLighter
                    layer.addFilter(.blur(radius: 0.6))
                    for (p, k) in glowing {
                        layer.stroke(Path(ellipseIn: rect(p, hole * 0.97)), with: .color(color.opacity(0.5 * k)), lineWidth: 1)
                    }
                }
                let warm = page == 0
                for (p, k) in glowing {
                    let core = hole * 0.78
                    let stops: [Gradient.Stop] = warm
                        ? [.init(color: Color(red: 1.0, green: 0.88, blue: 0.55), location: 0),
                           .init(color: Color(red: 1.0, green: 0.62, blue: 0.25), location: 0.55),
                           .init(color: Color(red: 1.0, green: 0.4, blue: 0.15), location: 1)]
                        : [.init(color: Color(red: 0.85, green: 1.0, blue: 1.0), location: 0),
                           .init(color: Color(red: 0.45, green: 0.92, blue: 1.0), location: 0.55),
                           .init(color: Color(red: 0.15, green: 0.75, blue: 0.95), location: 1)]
                    ctx.opacity = 0.35 + 0.65 * k
                    disc(p, core, .radialGradient(Gradient(stops: stops), center: p, startRadius: 0, endRadius: core), in: &ctx)
                    ctx.opacity = 1
                }
            }
        }
        // a little taller than the grid so the halos aren't clipped
        .frame(height: 96)
        .padding(.vertical, -8)
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .onDisappear { settle?.cancel() }
    }
}

/// Session chip in the countdown tiles' language: dark glass with a neon
/// rim in the circuit's sector colours — cyan for practice, violet for
/// qualifying, red for the race. Lit when selected, quiet otherwise.
struct NeonChip: View {
    let title: String
    let tint: Color
    let selected: Bool

    var body: some View {
        Text(title)
            .font(.f1(13).italic())
            .foregroundStyle(selected ? Color.white : tint.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color(white: 0.03), Color(white: 0.085)], startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.09), .clear], startPoint: .top, endPoint: .center))
                    if selected {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(tint.opacity(0.9), lineWidth: 2.5)
                            .blur(radius: 4)
                    }
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(LinearGradient(colors: [selected ? Color.white.opacity(0.95) : tint.opacity(0.55), tint.opacity(selected ? 1 : 0.5), tint.opacity(selected ? 0.8 : 0.35)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: selected ? 1.6 : 1)
                }
            )
            .shadow(color: tint.opacity(selected ? 0.5 : 0), radius: 8)
    }
}
