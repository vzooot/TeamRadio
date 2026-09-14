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
            let cols = 31                   // five 5-wide lamps, single gaps, one spare column each side
            let rows = 5
            let pitch = size.width / CGFloat(cols)
            let top = (size.height - CGFloat(rows) * pitch) / 2
            let hole = pitch * 0.36
            let cellStep = pitch * 0.13
            let cellR = pitch * 0.04

            func center(_ col: Int, _ row: Int) -> CGPoint {
                CGPoint(x: CGFloat(col) * pitch + pitch / 2, y: top + CGFloat(row) * pitch + pitch / 2)
            }
            func disc(_ p: CGPoint, _ r: CGFloat, _ shading: GraphicsContext.Shading, in c: inout GraphicsContext) {
                c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: shading)
            }
            func cells(_ p: CGPoint, _ r: CGFloat, _ shading: GraphicsContext.Shading, in c: inout GraphicsContext) {
                for dx in -1...1 {
                    for dy in -1...1 {
                        disc(CGPoint(x: p.x + CGFloat(dx) * cellStep, y: p.y + CGFloat(dy) * cellStep), r, shading, in: &c)
                    }
                }
            }

            // lamp c: a 5×5 block with the corners cut — reads as a disc
            var lit: Set<Int> = []          // key: row * 1000 + col
            var armed: Set<Int> = []
            var lampCenters: [(CGPoint, Bool)] = []
            for c in 0..<5 {
                let cc = 3 + c * 6
                lampCenters.append((center(cc, 2), c < litLights))
                for dc in -2...2 {
                    for dr in -2...2 where abs(dc) + abs(dr) <= 3 {
                        let key = (2 + dr) * 1000 + cc + dc
                        if c < litLights { lit.insert(key) } else { armed.insert(key) }
                    }
                }
            }

            // every hole: dark recess with a rim; armed ones glow deep red, the rest stay grey
            for c in 0..<cols {
                for r in 0..<rows {
                    let p = center(c, r)
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - hole, y: p.y - hole + 0.6, width: 2 * hole, height: 2 * hole)),
                               with: .color(.white.opacity(0.07)), lineWidth: 0.8)
                    disc(p, hole, .color(.black.opacity(0.7)), in: &ctx)
                    let key = r * 1000 + c
                    if armed.contains(key) {
                        disc(p, hole * 0.9, .color(lightColor.opacity(0.14)), in: &ctx)
                        cells(p, cellR * 1.1, .color(lightColor.opacity(0.5)), in: &ctx)
                    } else if !lit.contains(key) {
                        cells(p, cellR, .color(.white.opacity(0.09)), in: &ctx)
                    }
                }
            }

            // lit lamps: one bloom per lamp, then every LED in the disc burns
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: pitch * 1.0))
                for (p, on) in lampCenters where on {
                    disc(p, pitch * 2.6, .color(lightColor.opacity(0.7)), in: &layer)
                }
            }
            for key in lit {
                let p = center(key % 1000, key / 1000)
                disc(p, hole * 0.95, .color(lightColor.opacity(0.4)), in: &ctx)
                disc(p, hole * 0.72, .color(lightColor), in: &ctx)
                disc(p, hole * 0.34, .color(.white.opacity(0.9)), in: &ctx)
            }
        }
        // taller than the grid so the bloom isn't clipped; the negative
        // padding hands the spare room back to the layout
        .frame(height: 100)
        .padding(.vertical, -16)
    }
}
