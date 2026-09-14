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

/// The start gantry: five round lamps in a row, each a hexagonal cluster of
/// 19 LEDs in deep sockets. Armed LEDs are dark red glass; lit ones are
/// saturated red-orange points with an additive bloom, like a real lamp.
struct DotMatrixBoard: View {
    let litLights: Int
    var lightColor: Color = Theme.live

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 25                 // LED spacing: five lamps, five LEDs wide each
            let ledR = s * 0.4
            let midY = size.height / 2

            func rect(_ p: CGPoint, _ r: CGFloat) -> CGRect { CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r) }
            func disc(_ p: CGPoint, _ r: CGFloat, _ shading: GraphicsContext.Shading, in c: inout GraphicsContext) {
                c.fill(Path(ellipseIn: rect(p, r)), with: shading)
            }
            /// Deep socket: lit lip at the bottom, wall shadow inside the top.
            func socket(_ p: CGPoint, in c: inout GraphicsContext) {
                disc(CGPoint(x: p.x, y: p.y + 1.2), ledR * 1.12, .color(.white.opacity(0.13)), in: &c)
                disc(p, ledR * 1.08, .linearGradient(Gradient(colors: [Color.black.opacity(0.97), Color.black.opacity(0.6)]),
                                                     startPoint: CGPoint(x: p.x, y: p.y - ledR), endPoint: CGPoint(x: p.x, y: p.y + ledR)), in: &c)
                c.stroke(Path(ellipseIn: rect(CGPoint(x: p.x, y: p.y - 0.6), ledR * 0.98)), with: .color(.black.opacity(0.7)), lineWidth: 1.6)
            }

            // 19 LEDs per lamp: centre, ring of 6 at s, ring of 12 at ~2s
            var leds: [(CGPoint, Bool)] = []
            var lampCenters: [(CGPoint, Bool)] = []
            for i in 0..<5 {
                let on = i < litLights
                let c = CGPoint(x: s * 2.5 + CGFloat(i) * 5 * s, y: midY)
                lampCenters.append((c, on))
                leds.append((c, on))
                for k in 0..<6 {
                    let a = CGFloat(k) * .pi / 3
                    leds.append((CGPoint(x: c.x + s * cos(a), y: c.y + s * sin(a)), on))
                    leds.append((CGPoint(x: c.x + 2 * s * cos(a), y: c.y + 2 * s * sin(a)), on))
                    let b = a + .pi / 6
                    leds.append((CGPoint(x: c.x + s * 1.732 * cos(b), y: c.y + s * 1.732 * sin(b)), on))
                }
            }

            for (p, on) in leds {
                socket(p, in: &ctx)
                if !on {
                    // dark red glass, a hint of the die inside
                    disc(p, ledR * 0.82, .radialGradient(Gradient(colors: [lightColor.opacity(0.28), lightColor.opacity(0.1), Color.black.opacity(0.2)]),
                                                         center: CGPoint(x: p.x, y: p.y - ledR * 0.15), startRadius: 0, endRadius: ledR * 0.82), in: &ctx)
                }
            }

            // light is additive: wide lamp wash, then a tight halo per LED
            let hot = Color(red: 1.0, green: 0.42, blue: 0.14)
            ctx.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.addFilter(.blur(radius: s * 1.4))
                for (c, on) in lampCenters where on {
                    disc(c, s * 2.8, .color(hot.opacity(0.32)), in: &layer)
                }
            }
            ctx.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.addFilter(.blur(radius: ledR * 0.9))
                for (p, on) in leds where on {
                    disc(p, ledR * 1.25, .color(hot.opacity(0.55)), in: &layer)
                }
            }
            for (p, on) in leds where on {
                disc(p, ledR * 0.86, .radialGradient(
                    Gradient(stops: [.init(color: Color(red: 1.0, green: 0.88, blue: 0.66), location: 0),
                                     .init(color: Color(red: 1.0, green: 0.55, blue: 0.22), location: 0.3),
                                     .init(color: Color(red: 1.0, green: 0.3, blue: 0.1), location: 0.75),
                                     .init(color: Color(red: 0.85, green: 0.18, blue: 0.06), location: 1)]),
                    center: CGPoint(x: p.x, y: p.y - ledR * 0.1), startRadius: 0, endRadius: ledR * 0.86), in: &ctx)
            }
        }
        // taller than the lamps so the bloom isn't clipped; the negative
        // padding hands the spare room back to the layout
        .frame(height: 112)
        .padding(.vertical, -14)
    }
}
