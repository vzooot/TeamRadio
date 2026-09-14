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

/// The LED board: a sparse matrix of small sockets carrying the five start
/// lights — each a small round cluster of five LEDs, spread across the board
/// and lit from the left as race week counts down. Lights out once the
/// session runs.
struct DotMatrixBoard: View {
    let litLights: Int
    var lightColor: Color = Color(red: 1.0, green: 0.5, blue: 0.2)

    var body: some View {
        Canvas { ctx, size in
            let cols = 29                   // five 5-wide lights with a spare column between
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

            // five lights, evenly spread: each a plus-shaped cluster of five LEDs
            // each light is a ring of 12 LEDs (radius 2) with a softer centre
            var lit: [Int: CGFloat] = [:]   // key: row * 1000 + col, value: intensity
            var armed: Set<Int> = []
            var lampCenters: [(CGPoint, Bool)] = []
            for c in 0..<5 {
                let cc = 2 + c * 6
                lampCenters.append((center(cc, 2), c < litLights))
                for dc in -2...2 {
                    for dr in -2...2 {
                        let d = (Double(dc * dc + dr * dr)).squareRoot()
                        let ring = d > 1.9 && d < 2.4
                        let centre = dc == 0 && dr == 0
                        guard ring || centre else { continue }
                        let key = (2 + dr) * 1000 + cc + dc
                        if c < litLights { lit[key] = ring ? 1 : 0.5 } else { armed.insert(key) }
                    }
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
                layer.addFilter(.blur(radius: pitch * 0.9))
                // the ring's light fills the lamp
                for (c, on) in lampCenters where on { disc(c, pitch * 1.6, .color(lightColor.opacity(0.28)), in: &layer) }
            }
            ctx.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.addFilter(.blur(radius: pitch * 0.45))
                for (p, k) in glowing { disc(p, pitch * 0.42, .color(lightColor.opacity(0.5 * k)), in: &layer) }
            }
            for (p, k) in glowing {
                disc(p, pitch * 0.2 * (0.7 + 0.3 * k), .color(lightColor.opacity(0.6 + 0.4 * k)), in: &ctx)
                disc(p, pitch * 0.09 * k, .color(.white.opacity(0.9)), in: &ctx)
            }
        }
        // a little taller than the grid so the halos aren't clipped
        .frame(height: 92)
        .padding(.vertical, -8)
    }
}

/// Apple's Liquid Glass (iOS 26+) for a chip; the flat card style below that.
struct GlassChip: ViewModifier {
    let selected: Bool
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(selected ? .regular.tint(Theme.accent.opacity(0.85)).interactive() : .regular.interactive(),
                                in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(RoundedRectangle(cornerRadius: cornerRadius).fill(selected ? Theme.accent : Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(selected ? .clear : Theme.cardStroke, lineWidth: 1))
        }
    }
}

/// Lets neighbouring glass chips share one material (they blend when close).
struct GlassRow<Content: View>: View {
    var spacing: CGFloat = 6
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
