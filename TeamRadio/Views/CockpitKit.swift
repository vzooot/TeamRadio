import SwiftUI
import UIKit

/// Cockpit hardware look for the countdown: carbon weave, neon-edged glass
/// tiles, hex screws and a dot-matrix LED board.
enum Cockpit {
    /// One weave repeat, rendered once and tiled — cheap to redraw every tick.
    static let carbonTile: UIImage = {
        let cell: CGFloat = 3        // fine 2×2 twill, barely there
        let n = 2
        let size = CGSize(width: cell * CGFloat(n), height: cell * CGFloat(n))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(red: 0.04, green: 0.045, blue: 0.058, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            for i in 0..<n {
                for j in 0..<n {
                    let rect = CGRect(x: CGFloat(i) * cell, y: CGFloat(j) * cell, width: cell, height: cell).insetBy(dx: 0.2, dy: 0.2)
                    let light = (i + j) % 2 == 0
                    c.setFillColor(UIColor(white: light ? 0.075 : 0.058, alpha: 1).cgColor)
                    c.fill(rect)
                    // sheen on the raised threads
                    c.setStrokeColor(UIColor(white: 1, alpha: light ? 0.035 : 0.012).cgColor)
                    c.setLineWidth(0.7)
                    c.move(to: CGPoint(x: rect.minX, y: light ? rect.maxY : rect.minY))
                    c.addLine(to: CGPoint(x: rect.maxX, y: light ? rect.minY : rect.maxY))
                    c.strokePath()
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
                RadialGradient(colors: [.clear, .black.opacity(0.45)], center: .center, startRadius: 40, endRadius: 320)
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

/// Dot-matrix LED board: a 5×7 pixel ticker on the left, the five-column
/// start gantry on the right. Lit LEDs bloom, unlit ones sit dark in the grid.
struct DotMatrixBoard: View {
    let text: String
    let litLights: Int
    var textColor: Color = Theme.accent
    var lightColor: Color = Theme.live

    private static let glyphs: [Character: String] = [
        "0": ".###.#...##..###.#.###..##...#.###.", "1": "..#...##....#....#....#....#...###.",
        "2": ".###.#...#....#...#...#...#...#####", "3": "#####...#...#.....#.....##...#.###.",
        "4": "...#...##..#.#.#..#.#####...#....#.", "5": "######....####.....#....##...#.###.",
        "6": "..###.#...#....####.#...##...#.###.", "7": "#####....#...#...#...#....#....#...",
        "8": ".###.#...##...#.###.#...##...#.###.", "9": ".###.#...##...#.####....#...#.###..",
        "A": ".###.#...##...#######...##...##...#", "B": "####.#...##...#####.#...##...#####.",
        "C": ".###.#...##....#....#....#...#.###.", "D": "###..#..#.#...##...##...##..#.###..",
        "E": "######....#....####.#....#....#####", "F": "######....#....####.#....#....#....",
        "G": ".###.#...##....#.####...##...#.####", "H": "#...##...##...#######...##...##...#",
        "I": ".###...#....#....#....#....#...###.", "J": "..###...#....#....#....#.#..#..##..",
        "K": "#...##..#.#.#..##...#.#..#..#.#...#", "L": "#....#....#....#....#....#....#####",
        "M": "#...###.###.#.##.#.##...##...##...#", "N": "#...##...###..##.#.##..###...##...#",
        "O": ".###.#...##...##...##...##...#.###.", "P": "####.#...##...#####.#....#....#....",
        "Q": ".###.#...##...##...##.#.##..#..##.#", "R": "####.#...##...#####.#.#..#..#.#...#",
        "S": ".#####....#.....###.....#....#####.", "T": "#####..#....#....#....#....#....#..",
        "U": "#...##...##...##...##...##...#.###.", "V": "#...##...##...##...##...#.#.#...#..",
        "W": "#...##...##...##.#.##.#.###.###...#", "X": "#...##...#.#.#...#...#.#.#...##...#",
        "Y": "#...##...#.#.#...#....#....#....#..", "Z": "#####....#...#...#...#...#....#####",
        ":": ".......#....#..........#....#......", ".": "..........................##...##..",
        "-": "...............###.................", "/": "....#...#....#...#...#....#...#....",
        " ": "...................................",
    ]

    private var textColumns: Int { text.count * 6 - 1 }

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                // One uniform LED grid across the whole board; the ticker
                // lights the left, the gantry lights the right.
                let gantryCols = 5 * 2 + 1
                let pitch = min(5.2, max(3.0, size.width / CGFloat(textColumns + 4 + gantryCols)))
                let dot = pitch * 0.6
                let rows = 7
                let cols = Int(size.width / pitch)
                let x0 = (size.width - CGFloat(cols) * pitch) / 2
                let top = (size.height - CGFloat(rows) * pitch) / 2

                func center(_ col: Int, _ row: Int) -> CGPoint {
                    CGPoint(x: x0 + CGFloat(col) * pitch + pitch / 2, y: top + CGFloat(row) * pitch + pitch / 2)
                }
                func led(_ p: CGPoint, _ r: CGFloat, _ color: Color, in c: inout GraphicsContext) {
                    c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                }

                // dark LEDs everywhere
                for col in 0..<cols {
                    for row in 0..<rows {
                        led(center(col, row), dot / 2, Color.white.opacity(0.10), in: &ctx)
                    }
                }

                // ticker glyphs
                var cyan: [CGPoint] = []
                var col = 0
                for ch in text.uppercased() {
                    let bits = Array(Self.glyphs[ch] ?? Self.glyphs[" "]!)
                    for row in 0..<rows {
                        for k in 0..<5 where bits[row * 5 + k] == "#" && col + k < cols {
                            cyan.append(center(col + k, row))
                        }
                    }
                    col += 6
                }

                // gantry: 5 lamp columns on the right, each lamp = 2 LEDs, lit from the left
                var orange: [CGPoint] = []
                var dark: [CGPoint] = []
                for c in 0..<5 {
                    let gc = cols - 2 - (4 - c) * 2
                    for row in [2, 4] {
                        if c < litLights { orange.append(center(gc, row)) } else { dark.append(center(gc, row)) }
                    }
                }
                for p in dark { led(p, dot / 2, lightColor.opacity(0.22), in: &ctx) }

                for (points, color) in [(cyan, textColor), (orange, lightColor)] where !points.isEmpty {
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: pitch * 0.8))
                        for p in points { led(p, dot * 0.9, color.opacity(0.9), in: &layer) }
                    }
                    for p in points { led(p, dot / 2, color, in: &ctx) }
                    for p in points { led(p, dot / 4, .white.opacity(0.7), in: &ctx) }
                }
            }
        }
        .frame(height: 46)
    }
}
