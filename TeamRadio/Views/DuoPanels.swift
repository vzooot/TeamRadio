import SwiftUI

/// The iPhone Duo's inner display shows two screens, one each side of the
/// fold, and each must read as its own screen, not a page cut in two. Every
/// tab uses the same two frames: on the left a display (deep night glass,
/// square, bright L-shaped corners), on the right the deck (dark panels with
/// a cut corner and a thin accent edge, `deckPanel` for a deck of several).
extension View {
    /// The left screen: the display.
    func duoDisplay(flag: String? = nil) -> some View {
        self
            .background(DisplayGlass(flag: flag))
            .clipShape(Rectangle())
            .overlay(Rectangle().strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1))
            .overlay(DuoCornerBrackets().stroke(Theme.accent, lineWidth: 2.5).shadow(color: Theme.accent.opacity(0.85), radius: 5))
    }

    /// The right screen as one deck panel: the cut corner, the accent edge.
    func duoDeck(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(DeckShape(cut: 22).fill(LinearGradient(colors: [Color(white: 0.075), Color(white: 0.03)], startPoint: .top, endPoint: .bottom)))
            .clipShape(DeckShape(cut: 22))
            .overlay(DeckShape(cut: 22).stroke(Theme.accent.opacity(0.28), lineWidth: 1))
    }
}

/// The display's ground: deep night with the trio's light, faint stars,
/// and (on the Countdown tab) the race's flag far back.
struct DisplayGlass: View {
    var flag: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.09), Color(red: 0.02, green: 0.02, blue: 0.04)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.accent.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Theme.live.opacity(0.14), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 380)
            Canvas { context, size in
                // fixed stars, the same every time
                var seed: UInt64 = 0x9E3779B97F4A7C15
                for _ in 0..<70 {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let x = CGFloat(seed >> 33 % 10_000) / 10_000 * size.width
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let y = CGFloat(seed >> 33 % 10_000) / 10_000 * size.height
                    let r = CGFloat(seed % 3) * 0.4 + 0.5
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.35)))
                }
            }
            if let flag {
                Text(flag)
                    .font(.system(size: 220))
                    .opacity(0.05)
                    .rotationEffect(.degrees(-12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 40, y: -30)
            }
        }
    }
}

/// Bright L-shaped corners, drawn right on the monitor's square corners.
struct DuoCornerBrackets: Shape {
    var length: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect.insetBy(dx: 1.25, dy: 1.25)
        let corners: [(CGPoint, CGFloat, CGFloat)] = [(CGPoint(x: r.minX, y: r.minY), 1, 1), (CGPoint(x: r.maxX, y: r.minY), -1, 1),
                                                       (CGPoint(x: r.minX, y: r.maxY), 1, -1), (CGPoint(x: r.maxX, y: r.maxY), -1, -1)]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x + dx * length, y: corner.y))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * length))
        }
        return path
    }
}

/// Two screens side by side, each on its own side of the fold (the inner
/// display held like a book), with a gap over the fold. Both get fixed
/// widths: content too wide for its half never pushes the pair across it.
struct DuoSideBySide<Left: View, Right: View>: View {
    /// The fold's line, in this view's coordinates (`Halves.fold`).
    let fold: CGFloat
    @ViewBuilder let left: Left
    @ViewBuilder let right: Right

    private let gap: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let first = max(0, fold - gap / 2 - 16)
            HStack(alignment: .top, spacing: gap) {
                left.frame(width: first)
                right.frame(width: max(0, geo.size.width - 32 - gap - first))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
    }
}
