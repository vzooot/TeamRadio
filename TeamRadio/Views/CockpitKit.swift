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

/// The LED board: a sparse 24×4 matrix of small sockets carrying the five
/// start lights — each a rounded block of 12 LEDs — lit from the left as race
/// week counts down. Lights out once the session runs.
struct DotMatrixBoard: View {
    let litLights: Int
    var lightColor: Color = Theme.live

    var body: some View {
        Canvas { ctx, size in
            let cols = 24                   // five 4-wide lights with one dark column between
            let rows = 4
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
            // each light: a 4×4 block with the corners left dark — 12 LEDs, reads as a disc
            var lit: [Int: CGFloat] = [:]   // key: row * 1000 + col, value: intensity
            var armed: Set<Int> = []
            for c in 0..<5 {
                let c0 = c * 5
                for dc in 0..<4 {
                    for dr in 0..<4 {
                        let corner = (dc == 0 || dc == 3) && (dr == 0 || dr == 3)
                        guard !corner else { continue }
                        let key = dr * 1000 + c0 + dc
                        if c < litLights { lit[key] = 1 } else { armed.insert(key) }
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
            // each lit LED: a small halo, a thin bright ring at the lens edge, a hot core
            // the red glowing ring at the lens edge — bright, but with a tight blur
            ctx.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.addFilter(.blur(radius: 0.8))
                for (p, k) in glowing {
                    let r = pitch * 0.26
                    layer.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(lightColor.opacity(0.85 * k)), lineWidth: 1.6)
                }
            }
            // the LED's nine cells light individually, each with its own small halo
            let hot = Color(red: 1.0, green: 0.45, blue: 0.25)
            ctx.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.addFilter(.blur(radius: cellR * 1.6))
                for (p, k) in glowing {
                    for dx in -1...1 {
                        for dy in -1...1 {
                            disc(CGPoint(x: p.x + CGFloat(dx) * cellStep, y: p.y + CGFloat(dy) * cellStep), cellR * 2.2, .color(lightColor.opacity(0.55 * k)), in: &layer)
                        }
                    }
                }
            }
            for (p, k) in glowing {
                for dx in -1...1 {
                    for dy in -1...1 {
                        disc(CGPoint(x: p.x + CGFloat(dx) * cellStep, y: p.y + CGFloat(dy) * cellStep), cellR * 1.35, .color(hot.opacity(0.7 + 0.3 * k)), in: &ctx)
                    }
                }
            }
        }
        // a little taller than the grid so the halos aren't clipped
        .frame(height: 84)
        .padding(.vertical, -8)
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
