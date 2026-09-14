import SwiftUI
import UIKit

/// Cockpit hardware look for the countdown: carbon weave, neon-edged glass
/// tiles, hex screws and a dot-matrix LED board.
enum Cockpit {
    /// One weave repeat, rendered once and tiled — cheap to redraw every tick.
    static let carbonTile: UIImage = {
        // 2×2 twill, near-black: the "over" strands step one cell per row, which
        // is what gives real carbon its diagonal look. Low contrast on purpose.
        let cell: CGFloat = 2.5
        let n = 4
        let size = CGSize(width: cell * CGFloat(n), height: cell * CGFloat(n))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(red: 0.035, green: 0.04, blue: 0.05, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            let space = CGColorSpaceCreateDeviceGray()
            for i in 0..<n {
                for j in 0..<n {
                    let rect = CGRect(x: CGFloat(i) * cell, y: CGFloat(j) * cell, width: cell, height: cell).insetBy(dx: 0.2, dy: 0.2)
                    let over = (i + j) % 4 < 2
                    let shades: [CGFloat] = over ? [0.125, 0.095, 0.065] : [0.075, 0.06, 0.045]
                    let colors = shades.map { CGColor(gray: $0, alpha: 1) } as CFArray
                    guard let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) else { continue }
                    c.saveGState()
                    c.clip(to: rect)
                    c.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
                    c.restoreGState()
                }
            }
        }
    }()
}

struct CarbonFiber: View {
    var body: some View {
        Image(uiImage: Cockpit.carbonTile)
            .resizable(resizingMode: .tile)
            .overlay(
                // vignette so the weave sinks away from the glowing parts
                RadialGradient(colors: [.clear, .black.opacity(0.28)], center: .center, startRadius: 60, endRadius: 340)
            )
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

/// Dot-matrix LED board: large LEDs in dark sockets on the carbon, a 3×5
/// ticker lit cyan on the left, the five-column start gantry lit orange on
/// the right. Lit LEDs bloom; unlit ones stay as dim sockets.
struct DotMatrixBoard: View {
    let text: String
    let litLights: Int
    var textColor: Color = Theme.accent
    var lightColor: Color = Theme.live

    // 3 columns × 5 rows, top row first
    private static let glyphs: [Character: String] = [
        "0": "####.##.##.####", "1": ".#.##..#..#.###", "2": "###..#####..###", "3": "###..####..####",
        "4": "#.##.####..#..#", "5": "####..###..####", "6": "####..####.####", "7": "###..#..#..#..#",
        "8": "####.#####.####", "9": "####.####..####",
        "A": "####.#####.##.#", "B": "##.#.###.#.###.", "C": "####..#..#..###", "D": "##.#.##.##.###.",
        "E": "####..####..###", "F": "####..####..#..", "G": "####..#.##.####", "H": "#.##.#####.##.#",
        "I": "###.#..#..#.###", "J": "..#..#..##.####", "K": "#.##.###.#.##.#", "L": "#..#..#..#..###",
        "M": "#.########.##.#", "N": "##.#.##.##.##.#", "O": "####.##.##.####", "P": "####.#####..#..",
        "Q": "####.##.####..#", "R": "####.###.#.##.#", "S": "####..###..####", "T": "###.#..#..#..#.",
        "U": "#.##.##.##.####", "V": "#.##.##.##.#.#.", "W": "#.##.########.#", "X": "#.##.#.#.#.##.#",
        "Y": "#.##.####.#..#.", "Z": "###..#.#.#..###", ":": "....#.....#....", "-": "......###......",
        ".": "............#..", " ": "...............",
    ]

    var body: some View {
        Canvas { ctx, size in
            let textCols = text.count * 4 - 1
            let gantryCols = 9                      // 5 lamps, one dark column between
            let cols = textCols + 3 + gantryCols
            let pitch = min(12, size.width / CGFloat(cols))
            let rows = 7                            // 5 for glyphs + a blank socket row above and below
            let gridCols = Int(size.width / pitch)
            let x0 = (size.width - CGFloat(gridCols) * pitch) / 2
            let top = (size.height - CGFloat(rows) * pitch) / 2

            func center(_ col: Int, _ row: Int) -> CGPoint {
                CGPoint(x: x0 + CGFloat(col) * pitch + pitch / 2, y: top + CGFloat(row) * pitch + pitch / 2)
            }
            func disc(_ p: CGPoint, _ r: CGFloat, _ shading: GraphicsContext.Shading, in c: inout GraphicsContext) {
                c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: shading)
            }

            // unlit LEDs: tiny dim dots, so the grid is only just there
            for col in 0..<gridCols {
                for row in 0..<rows {
                    disc(center(col, row), pitch * 0.09, .color(.white.opacity(0.13)), in: &ctx)
                }
            }

            // ticker glyphs, rows 1...5
            var cyan: [CGPoint] = []
            var col = 0
            for ch in text.uppercased() {
                let bits = Array(Self.glyphs[ch] ?? Self.glyphs[" "]!)
                for row in 0..<5 {
                    for k in 0..<3 where row * 3 + k < bits.count && bits[row * 3 + k] == "#" && col + k < gridCols {
                        cyan.append(center(col + k, row + 1))
                    }
                }
                col += 4
            }

            // gantry: 5 columns, one LED on row 2 and one on row 4, lit from the left
            var orange: [CGPoint] = []
            var off: [CGPoint] = []
            for c in 0..<5 {
                let gc = gridCols - 1 - (4 - c) * 2
                for row in [2, 4] {
                    if c < litLights { orange.append(center(gc, row)) } else { off.append(center(gc, row)) }
                }
            }
            for p in off { disc(p, pitch * 0.13, .color(lightColor.opacity(0.4)), in: &ctx) }

            for (points, color) in [(cyan, textColor), (orange, lightColor)] where !points.isEmpty {
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: pitch * 0.5))
                    for p in points { disc(p, pitch * 0.3, .color(color.opacity(0.8)), in: &layer) }
                }
                for p in points { disc(p, pitch * 0.19, .color(color), in: &ctx) }
                for p in points { disc(p, pitch * 0.08, .color(.white.opacity(0.85)), in: &ctx) }
            }
        }
        .frame(height: 64)
    }
}
