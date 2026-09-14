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

/// The start gantry: ten round lamps (five columns of two) mounted on a
/// matrix of small LED holes. Lamps are dark red lenses until race week
/// lights them column by column; lights out once the session is running.
struct DotMatrixBoard: View {
    let litLights: Int
    var lightColor: Color = Theme.live

    var body: some View {
        Canvas { ctx, size in
            let cols = 25
            let rows = 6
            let pitch = size.width / CGFloat(cols)
            let top = (size.height - CGFloat(rows) * pitch) / 2
            let hole = pitch * 0.34
            let cellStep = pitch * 0.12
            let cellR = pitch * 0.038
            let lampR = pitch * 1.32

            func center(_ col: CGFloat, _ row: CGFloat) -> CGPoint {
                CGPoint(x: col * pitch + pitch / 2, y: top + row * pitch + pitch / 2)
            }
            func disc(_ p: CGPoint, _ r: CGFloat, _ shading: GraphicsContext.Shading, in c: inout GraphicsContext) {
                c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: shading)
            }
            func ring(_ p: CGPoint, _ r: CGFloat, _ color: Color, _ width: CGFloat, in c: inout GraphicsContext) {
                c.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(color), lineWidth: width)
            }

            // the LED hole matrix
            for c in 0..<cols {
                for r in 0..<rows {
                    let p = center(CGFloat(c), CGFloat(r))
                    ring(CGPoint(x: p.x, y: p.y + 0.6), hole, .white.opacity(0.07), 0.8, in: &ctx)
                    disc(p, hole, .color(.black.opacity(0.7)), in: &ctx)
                    for dx in -1...1 {
                        for dy in -1...1 {
                            disc(CGPoint(x: p.x + CGFloat(dx) * cellStep, y: p.y + CGFloat(dy) * cellStep), cellR, .color(.white.opacity(0.09)), in: &ctx)
                        }
                    }
                }
            }

            // lamp positions: five columns across, two rows
            let first = CGFloat((cols - (5 * 3 + 4)) / 2)
            var lamps: [(CGPoint, Bool)] = []
            for c in 0..<5 {
                for rowCenter in [1.0, 4.0] as [CGFloat] {
                    lamps.append((center(first + 1 + CGFloat(c) * 4, rowCenter), c < litLights))
                }
            }

            // bloom first, so it sits under every lens
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: pitch * 1.1))
                for (p, on) in lamps where on {
                    disc(p, lampR * 1.5, .color(lightColor.opacity(0.8)), in: &layer)
                }
            }
            for (p, on) in lamps {
                // housing
                disc(p, lampR * 1.08, .color(.black.opacity(0.85)), in: &ctx)
                ring(p, lampR * 1.08, .white.opacity(0.10), 1, in: &ctx)
                if on {
                    disc(p, lampR, .radialGradient(Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.6), lightColor, lightColor.opacity(0.9)]),
                                                   center: CGPoint(x: p.x - lampR * 0.2, y: p.y - lampR * 0.25), startRadius: 0, endRadius: lampR), in: &ctx)
                    disc(CGPoint(x: p.x - lampR * 0.3, y: p.y - lampR * 0.35), lampR * 0.22, .color(.white.opacity(0.85)), in: &ctx)
                } else {
                    // dark lens: deep red glass, a faint rim, a whisper of reflection
                    disc(p, lampR, .radialGradient(Gradient(colors: [lightColor.opacity(0.22), lightColor.opacity(0.10), Color.black.opacity(0.6)]),
                                                   center: CGPoint(x: p.x - lampR * 0.2, y: p.y - lampR * 0.25), startRadius: 0, endRadius: lampR), in: &ctx)
                    ring(p, lampR * 0.96, lightColor.opacity(0.22), 0.8, in: &ctx)
                    disc(CGPoint(x: p.x - lampR * 0.32, y: p.y - lampR * 0.38), lampR * 0.16, .color(.white.opacity(0.10)), in: &ctx)
                }
            }
        }
        // taller than the grid so the bloom isn't clipped; the negative
        // padding hands the spare room back to the layout
        .frame(height: 124)
        .padding(.vertical, -14)
    }
}
