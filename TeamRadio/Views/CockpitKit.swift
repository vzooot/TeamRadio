import SwiftUI
import UIKit

/// Cockpit hardware look for the countdown: carbon weave, neon-edged glass
/// tiles, hex screws, a brushed-steel pin bar and a dot-matrix LED board.
enum Cockpit {
    /// One weave repeat, rendered once and tiled — cheap to redraw every tick.
    static let carbonTile: UIImage = {
        let cell: CGFloat = 3        // fine 2×2 twill, perforated every other cell
        let n = 4
        let size = CGSize(width: cell * CGFloat(n), height: cell * CGFloat(n))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(red: 0.03, green: 0.034, blue: 0.045, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            for i in 0..<n {
                for j in 0..<n {
                    let rect = CGRect(x: CGFloat(i) * cell, y: CGFloat(j) * cell, width: cell, height: cell).insetBy(dx: 0.25, dy: 0.25)
                    let light = (i + j) % 2 == 0
                    c.setFillColor(UIColor(white: light ? 0.095 : 0.062, alpha: 1).cgColor)
                    c.fill(rect)
                    // sheen on the raised threads
                    c.setStrokeColor(UIColor(white: 1, alpha: light ? 0.06 : 0.02).cgColor)
                    c.setLineWidth(0.7)
                    c.move(to: CGPoint(x: rect.minX, y: light ? rect.maxY : rect.minY))
                    c.addLine(to: CGPoint(x: rect.maxX, y: light ? rect.minY : rect.maxY))
                    c.strokePath()
                }
            }
            // perforation: one hole per 2×2 block
            c.setFillColor(UIColor(white: 0, alpha: 0.6).cgColor)
            for i in stride(from: 0, to: n, by: 2) {
                for j in stride(from: 0, to: n, by: 2) {
                    let cx = CGFloat(i + 1) * cell, cy = CGFloat(j + 1) * cell
                    c.fillEllipse(in: CGRect(x: cx - 0.9, y: cy - 0.9, width: 1.8, height: 1.8))
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

/// Brushed-steel bar with end screws and etched lettering.
struct BrushedBar<Label: View>: View {
    var lit: Bool = false
    @ViewBuilder let label: Label

    private var brushed: LinearGradient {
        // fine horizontal streaks: many alternating gray bands
        var stops: [Gradient.Stop] = []
        let n = 26
        for i in 0...n {
            let t = Double(i) / Double(n)
            let base = 0.30 - 0.10 * t
            let jitter = [0.0, 0.05, -0.03, 0.035, -0.045, 0.02][i % 6]
            stops.append(.init(color: Color(white: base + jitter), location: t))
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        label
            .font(.f1(13, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(lit ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color(white: 0.62)))
            .shadow(color: lit ? Theme.accent.opacity(0.6) : .black.opacity(0.9), radius: lit ? 6 : 0.5, y: lit ? 0 : 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(brushed)
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.45), Color.black.opacity(0.7)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 3)
                        .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
                }
            )
            .overlay(alignment: .leading) { Screw(size: 11).padding(.leading, 9) }
            .overlay(alignment: .trailing) { Screw(size: 11).padding(.trailing, 9) }
            .shadow(color: .black.opacity(0.7), radius: 6, y: 4)
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

    private var columns: Int { text.count * 6 - 1 }

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let gantryCols: CGFloat = 5 * 2.6
                let pitch = min(5.2, max(3.0, (size.width - 24) / (CGFloat(columns) + gantryCols + 4)))
                let dot = pitch * 0.62
                let top = (size.height - 7 * pitch) / 2

                func led(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: Color, in c: inout GraphicsContext) {
                    c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                }

                // ticker text
                var lit: [(CGFloat, CGFloat)] = []
                var col = 0
                for ch in text.uppercased() {
                    let glyph = Self.glyphs[ch] ?? Self.glyphs[" "]!
                    let bits = Array(glyph)
                    for row in 0..<7 {
                        for k in 0..<5 {
                            let x = 4 + CGFloat(col + k) * pitch + pitch / 2
                            let y = top + CGFloat(row) * pitch + pitch / 2
                            let i = row * 5 + k
                            if i < bits.count, bits[i] == "#" {
                                lit.append((x, y))
                            } else {
                                led(x, y, dot / 2, Color.white.opacity(0.05), in: &ctx)
                            }
                        }
                    }
                    col += 6
                }
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: pitch * 0.8))
                    for (x, y) in lit { led(x, y, dot * 0.9, textColor.opacity(0.9), in: &layer) }
                }
                for (x, y) in lit { led(x, y, dot / 2, textColor, in: &ctx) }
                for (x, y) in lit { led(x, y, dot / 4, .white.opacity(0.7), in: &ctx) }

                // gantry: 5 columns × 2 lamps, lit from the left
                let lamp = pitch * 1.05
                let gap = pitch * 2.6
                let x0 = size.width - 4 - gap * 4 - lamp
                for c in 0..<5 {
                    for r in 0..<2 {
                        let x = x0 + CGFloat(c) * gap + lamp / 2
                        let y = top + pitch * 1.2 + CGFloat(r) * gap + lamp / 2
                        let on = c < litLights
                        if on {
                            ctx.drawLayer { layer in
                                layer.addFilter(.blur(radius: lamp))
                                led(x, y, lamp, lightColor.opacity(0.9), in: &layer)
                            }
                            led(x, y, lamp / 2, lightColor, in: &ctx)
                            led(x, y, lamp / 4, .white.opacity(0.75), in: &ctx)
                        } else {
                            led(x, y, lamp / 2, Color.white.opacity(0.16), in: &ctx)
                            led(x, y, lamp / 2 - 1, Color(red: 0.16, green: 0.06, blue: 0.04).opacity(0.9), in: &ctx)
                        }
                    }
                }
            }
        }
        .frame(height: 46)
    }
}
