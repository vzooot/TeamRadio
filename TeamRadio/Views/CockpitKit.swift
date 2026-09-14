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

/// The LED board: a sparse matrix of small sockets. The session time is lit
/// in pale cyan on the left; the five start-light columns sit at the right
/// as small orange points (two per column), lit from the left as race week
/// counts down. Lights out once the session runs.
struct DotMatrixBoard: View {
    let text: String
    let litLights: Int
    var textColor: Color = Color(red: 0.62, green: 0.93, blue: 1.0)
    var lightColor: Color = Color(red: 1.0, green: 0.5, blue: 0.2)

    // 3 columns × 5 rows, top row first
    private static let glyphs: [Character: String] = [
        "0": "####.##.##.####", "1": ".#.##..#..#.###", "2": "###..#####..###", "3": "###..####..####",
        "4": "#.##.####..#..#", "5": "####..###..####", "6": "####..####.####", "7": "###..#..#..#..#",
        "8": "####.#####.####", "9": "####.####..####", ":": "....#.....#....", " ": "...............",
    ]

    var body: some View {
        Canvas { ctx, size in
            let cols = 25
            let rows = 5
            let pitch = size.width / CGFloat(cols)
            let top = (size.height - CGFloat(rows) * pitch) / 2
            let hole = pitch * 0.3
            let cellStep = pitch * 0.11
            let cellR = pitch * 0.032

            func center(_ col: Int, _ row: Int) -> CGPoint {
                CGPoint(x: CGFloat(col) * pitch + pitch / 2, y: top + CGFloat(row) * pitch + pitch / 2)
            }
            func disc(_ p: CGPoint, _ r: CGFloat, _ shading: GraphicsContext.Shading, in c: inout GraphicsContext) {
                c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: shading)
            }

            // which sockets are lit, and in what colour
            var lit: [Int: Color] = [:]          // key: row * 1000 + col
            var col = 0
            for ch in text {
                let bits = Array(Self.glyphs[ch] ?? Self.glyphs[" "]!)
                for row in 0..<5 {
                    for k in 0..<3 where bits[row * 3 + k] == "#" && col + k < cols - 6 {
                        lit[row * 1000 + col + k] = textColor
                    }
                }
                col += 4
            }
            var armed: Set<Int> = []
            for c in 0..<5 {
                let gc = cols - 5 + c
                for row in [1, 3] {
                    if c < litLights { lit[row * 1000 + gc] = lightColor } else { armed.insert(row * 1000 + gc) }
                }
            }

            // sockets: a dark recess with a faint lip below and a 3×3 hint of the die
            for c in 0..<cols {
                for r in 0..<rows {
                    let p = center(c, r)
                    let key = r * 1000 + c
                    disc(CGPoint(x: p.x, y: p.y + 0.8), hole * 1.05, .color(.white.opacity(0.09)), in: &ctx)
                    disc(p, hole, .color(.black.opacity(0.72)), in: &ctx)
                    if lit[key] == nil {
                        let dieColor: Color = armed.contains(key) ? lightColor.opacity(0.3) : .white.opacity(0.09)
                        for dx in -1...1 {
                            for dy in -1...1 {
                                disc(CGPoint(x: p.x + CGFloat(dx) * cellStep, y: p.y + CGFloat(dy) * cellStep), cellR, .color(dieColor), in: &ctx)
                            }
                        }
                    }
                }
            }

            // lit LEDs: a soft additive halo, a coloured point, a bright core
            let glowing = lit.map { (center($0.key % 1000, $0.key / 1000), $0.value) }
            ctx.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.addFilter(.blur(radius: pitch * 0.45))
                for (p, color) in glowing { disc(p, pitch * 0.42, .color(color.opacity(0.5)), in: &layer) }
            }
            for (p, color) in glowing {
                disc(p, pitch * 0.2, .color(color), in: &ctx)
                disc(p, pitch * 0.09, .color(.white.opacity(0.9)), in: &ctx)
            }
        }
        // a little taller than the grid so the halos aren't clipped
        .frame(height: 92)
        .padding(.vertical, -8)
    }
}
