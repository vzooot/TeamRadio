import SwiftUI

/// The iPhone Duo's inner display shows two screens, one each side of the
/// fold, and each must read as its own screen, not a page cut in two. Every
/// half of every tab is built the same way: its title on top, then its box
/// below (deep night glass, square, bright L-shaped corners), the app's own
/// rounded cards inside it.
extension View {
    /// The box: night glass, square, bright corners.
    func duoDisplay(flag: String? = nil) -> some View {
        self
            .background(DisplayGlass(flag: flag))
            .clipShape(Rectangle())
            .overlay(Rectangle().strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1))
            .overlay(DuoCornerBrackets().stroke(Theme.accent, lineWidth: 2.5).shadow(color: Theme.accent.opacity(0.85), radius: 5))
    }
}

/// One half: the title on top, the box below filling the rest.
struct DuoScreen<Header: View, Content: View>: View {
    var flag: String?
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // above the box: the header's helmet may hang over it
            header.zIndex(1)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .duoDisplay(flag: flag)
        }
    }
}

/// A half's title, the app's page header: the slashes, the chrome title,
/// one line under it, an optional accessory on the right.
struct DuoTitle<Accessory: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 9) {
                    TrioSlashes(height: 24).padding(.top, 6)
                    Text(title)
                }
                .font(.f1(30).italic())
                .foregroundStyle(Theme.chromeText)
                Text(subtitle)
                    .font(.f1(12, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            accessory
        }
        .padding(.top, 8)
    }
}

extension DuoTitle where Accessory == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

extension View {
    /// A strip that scrolls sideways inside a box: it fades out at the box's
    /// edges instead of being cut off there.
    func duoEdgeFade() -> some View {
        mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.05),
                                    .init(color: .black, location: 0.95), .init(color: .clear, location: 1)],
                            startPoint: .leading, endPoint: .trailing))
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

/// The display pickers (what the left screen shows): tiles in the
/// countdown's neon glass, the chosen one lit in its colour with a bloom,
/// a glowing icon and a lit bar under its name.
struct GlowSelector: View {
    struct Option: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let tint: Color
    }

    let options: [Option]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options) { option in
                tile(option, on: option.id == selected)
            }
        }
    }

    private func tile(_ option: Option, on: Bool) -> some View {
        Button { onSelect(option.id) } label: {
            VStack(spacing: 7) {
                Image(systemName: option.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(on ? Color.white : option.tint.opacity(0.75))
                    .shadow(color: on ? option.tint : .clear, radius: 6)
                    .shadow(color: on ? option.tint.opacity(0.6) : .clear, radius: 12)
                Text(option.title)
                    .font(.f1(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(on ? Color.white : Theme.dimText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Capsule()
                    .fill(option.tint)
                    .frame(width: on ? 22 : 8, height: 3)
                    .shadow(color: option.tint, radius: on ? 4 : 0)
                    .opacity(on ? 1 : 0.35)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(chrome(option.tint, on: on))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.25), value: on)
        .accessibilityLabel(option.title.capitalized)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// The neon tile's glass: dark, a sheen, and when chosen the bloom and
    /// the bright tube of the countdown tiles.
    private func chrome(_ tint: Color, on: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color(white: 0.03), on ? tint.opacity(0.16) : Color(white: 0.08)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
            if on {
                RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.9), lineWidth: 3).blur(radius: 5)
            }
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(on ? 0.95 : 0.2), tint.opacity(on ? 1 : 0.45), tint.opacity(on ? 0.8 : 0.25)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: on ? 2.2 : 1)
            RoundedRectangle(cornerRadius: 11)
                .inset(by: 6)
                .strokeBorder(tint.opacity(on ? 0.35 : 0.08), lineWidth: 1)
        }
        .shadow(color: tint.opacity(on ? 0.55 : 0), radius: 12)
    }
}
