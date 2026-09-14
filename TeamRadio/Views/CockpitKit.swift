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

/// The start gantry as an LED matrix: five round lamps in a row, each a
/// disc-shaped cluster of 21 LEDs. Dark red while armed, they light column
/// by column through race week; lights out once the session is running.
struct DotMatrixBoard: View {
    let litLights: Int
    var lightColor: Color = Theme.live

    var body: some View {
        Canvas { ctx, size in
            let cols = 29                   // five 5-wide lamps with single gaps, edge to edge
            let rows = 5
            let pitch = size.width / CGFloat(cols)
            let top = (size.height - CGFloat(rows) * pitch) / 2
            let hole = pitch * 0.42
            let cellStep = pitch * 0.14
            let cellR = pitch * 0.042

            func center(_ col: Int, _ row: Int) -> CGPoint {
                CGPoint(x: CGFloat(col) * pitch + pitch / 2, y: top + CGFloat(row) * pitch + pitch / 2)
            }
            func rect(_ p: CGPoint, _ r: CGFloat) -> CGRect { CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r) }
            func disc(_ p: CGPoint, _ r: CGFloat, _ shading: GraphicsContext.Shading, in c: inout GraphicsContext) {
                c.fill(Path(ellipseIn: rect(p, r)), with: shading)
            }
            func cells(_ p: CGPoint, _ r: CGFloat, _ shading: GraphicsContext.Shading, in c: inout GraphicsContext) {
                for dx in -1...1 {
                    for dy in -1...1 {
                        disc(CGPoint(x: p.x + CGFloat(dx) * cellStep, y: p.y + CGFloat(dy) * cellStep), r, shading, in: &c)
                    }
                }
            }
            /// Recessed hole: light from the top-left, so a shadow inside the top edge
            /// and a thin lit lip along the bottom.
            func socket(_ p: CGPoint, in c: inout GraphicsContext) {
                disc(CGPoint(x: p.x, y: p.y + 0.9), hole * 1.02, .color(.white.opacity(0.11)), in: &c)
                disc(p, hole, .color(.black.opacity(0.8)), in: &c)
                c.stroke(Path(ellipseIn: rect(CGPoint(x: p.x, y: p.y + 0.7), hole * 0.86)), with: .color(.black.opacity(0.55)), lineWidth: 1.2)
            }
            func lens(_ p: CGPoint, on: Bool, in c: inout GraphicsContext) {
                let r = hole * 0.78
                let focus = CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.4)
                if on {
                    disc(p, r, .radialGradient(Gradient(colors: [Color(red: 1, green: 0.8, blue: 0.55), lightColor, lightColor.opacity(0.75)]),
                                               center: focus, startRadius: 0, endRadius: r * 1.15), in: &c)
                    disc(CGPoint(x: p.x - r * 0.38, y: p.y - r * 0.42), r * 0.22, .color(.white.opacity(0.75)), in: &c)
                } else {
                    disc(p, r, .radialGradient(Gradient(colors: [lightColor.opacity(0.4), lightColor.opacity(0.16), Color.black.opacity(0.5)]),
                                               center: focus, startRadius: 0, endRadius: r * 1.1), in: &c)
                    disc(CGPoint(x: p.x - r * 0.38, y: p.y - r * 0.42), r * 0.2, .color(.white.opacity(0.12)), in: &c)
                }
            }

            // lamp c: a 5×5 block with the corners cut — reads as a disc
            var lit: Set<Int> = []          // key: row * 1000 + col
            var armed: Set<Int> = []
            var lampCenters: [(CGPoint, Bool)] = []
            for c in 0..<5 {
                let cc = 2 + c * 6
                lampCenters.append((center(cc, 2), c < litLights))
                for dc in -2...2 {
                    for dr in -2...2 where abs(dc) + abs(dr) <= 3 {
                        let key = (2 + dr) * 1000 + cc + dc
                        if c < litLights { lit.insert(key) } else { armed.insert(key) }
                    }
                }
            }

            // bloom under the lit lamps
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: pitch * 1.0))
                for (p, on) in lampCenters where on {
                    disc(p, pitch * 2.5, .color(lightColor.opacity(0.5)), in: &layer)
                }
            }

            for c in 0..<cols {
                for r in 0..<rows {
                    let p = center(c, r)
                    socket(p, in: &ctx)
                    let key = r * 1000 + c
                    if lit.contains(key) {
                        lens(p, on: true, in: &ctx)
                    } else if armed.contains(key) {
                        lens(p, on: false, in: &ctx)
                    } else {
                        cells(p, cellR, .color(.white.opacity(0.09)), in: &ctx)
                    }
                }
            }
        }
        // taller than the grid so the bloom isn't clipped; the negative
        // padding hands the spare room back to the layout
        .frame(height: 104)
        .padding(.vertical, -16)
    }
}
