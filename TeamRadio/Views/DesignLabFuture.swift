#if DEBUG
import SwiftUI

// Debug-only drafts: brighter, futuristic Countdown cards. Nothing here ships.

private let hotPink = Color(red: 1, green: 0.22, blue: 0.55)
private let magenta = Color(red: 0.82, green: 0.2, blue: 0.9)
private let electric = Color(red: 0.18, green: 0.42, blue: 1)
private let cyan = Color(red: 0.2, green: 0.9, blue: 1)
private let mint = Color(red: 0.35, green: 1, blue: 0.8)
private let lime = Color(red: 0.75, green: 1, blue: 0.3)
private let deepViolet = Color(red: 0.28, green: 0.1, blue: 0.75)
private let gold = Color(red: 1, green: 0.82, blue: 0.3)
private let orange = Color(red: 1, green: 0.5, blue: 0.15)
private let blood = Color(red: 0.5, green: 0.02, blue: 0.05)
private let mercedes = Color(red: 0, green: 0.95, blue: 0.85)
private let ferrari = Color(red: 1, green: 0.15, blue: 0.2)
private let redbull = Color(red: 0.35, green: 0.45, blue: 1)

// MARK: - Shared pieces

/// A 3×3 mesh of colour: the soft, liquid gradient of modern iOS.
private struct Aurora: View {
    let colors: [Color]
    var body: some View {
        if #available(iOS 18, *) {
            MeshGradient(width: 3, height: 3,
                         points: [[0, 0], [0.5, 0], [1, 0],
                                  [0, 0.5], [0.62, 0.42], [1, 0.5],
                                  [0, 1], [0.45, 1], [1, 1]],
                         colors: colors)
        } else {
            LinearGradient(colors: [colors[0], colors[4], colors[8]], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Cut corners top-left and bottom-right.
private struct Chamfer: Shape {
    var cut: CGFloat = 26
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX + cut, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cut))
            p.addLine(to: CGPoint(x: r.maxX - cut, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + cut))
            p.closeSubpath()
        }
    }
}

/// HUD corner brackets.
private struct Brackets: Shape {
    var length: CGFloat = 18
    func path(in r: CGRect) -> Path {
        Path { p in
            for (corner, dx, dy) in [(CGPoint(x: r.minX, y: r.minY), 1.0, 1.0), (CGPoint(x: r.maxX, y: r.minY), -1.0, 1.0),
                                     (CGPoint(x: r.minX, y: r.maxY), 1.0, -1.0), (CGPoint(x: r.maxX, y: r.maxY), -1.0, -1.0)] {
                p.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
                p.addLine(to: corner)
                p.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
            }
        }
    }
}

/// Fine horizontal scan lines.
private struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white))
                y += 3
            }
        }
        .opacity(0.08)
        .allowsHitTesting(false)
    }
}

/// Soft white light across the top, like a glass edge catching light.
private struct TopSheen: View {
    var body: some View {
        LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }
}

/// Glossy start light with a specular highlight.
private struct Orb: View {
    var size: CGFloat
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(red: 1, green: 0.78, blue: 0.62), Theme.live, Color(red: 0.42, green: 0, blue: 0.02)],
                                 center: .init(x: 0.36, y: 0.3), startRadius: 1, endRadius: size * 0.72))
            .overlay(Ellipse().fill(.white.opacity(0.6)).frame(width: size * 0.38, height: size * 0.2)
                .offset(x: -size * 0.1, y: -size * 0.25).blur(radius: 1.2))
            .frame(width: size, height: size)
            .shadow(color: Theme.live.opacity(0.95), radius: size * 0.35)
    }
}

private func kicker(_ s: String, _ color: Color = .white) -> some View {
    Text(s).font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(color)
}

private struct Glass: ViewModifier {
    var shape: AnyShape = AnyShape(Capsule())
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .background(shape.fill(.white.opacity(0.14)))
            .environment(\.colorScheme, .light)
    }
}

private extension View {
    func glass(_ shape: some Shape = Capsule()) -> some View { modifier(Glass(shape: AnyShape(shape))) }
}

// MARK: - Set 7: Aurora (one idea per card, liquid colour, glass, HUD)

struct CardsDraft7: View {
    /// Shows only the lower cards, for a second screenshot.
    var tail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if !tail {
                    dotd
                    pass
                }
                emily
                lights
            }
            .padding(16).padding(.top, 46)
        }
    }

    // Driver of the day: chamfered aurora panel, glass vote rings.
    private var dotd: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(.white).frame(width: 6, height: 6).shadow(color: .white, radius: 4)
                        kicker("FAN VOTE · LIVE · R17")
                    }
                    Text("DRIVER OF\nTHE DAY").font(.f1(32).italic()).foregroundStyle(.white)
                        .shadow(color: deepViolet.opacity(0.4), radius: 8, y: 2)
                }
                Spacer()
                Text("VOTE").font(.f1(13).italic()).tracking(2).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10).glass()
            }
            HStack(spacing: 12) {
                ring("ANT", 0.52, mercedes)
                ring("LEC", 0.24, ferrari)
                ring("VER", 0.18, redbull)
                Spacer(minLength: 0)
            }
        }
        .padding(22)
        .background(ZStack {
            Aurora(colors: [orange, gold, hotPink,
                            orange, hotPink, magenta,
                            hotPink, magenta, deepViolet])
            TopSheen()
        }.clipShape(Chamfer()))
        .shadow(color: hotPink.opacity(0.45), radius: 24, y: 10)
    }

    private func ring(_ code: String, _ pct: Double, _ team: Color) -> some View {
        ZStack {
            Circle().fill(.clear).glass(Circle())
            Circle().trim(from: 0, to: pct)
                .stroke(team, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(4)
                .shadow(color: team, radius: 6)
            VStack(spacing: 0) {
                Text(code).font(.f1(16))
                Text("\(Int(pct * 100))%").font(.f1Digits(12)).opacity(0.85)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 76, height: 76)
    }

    // Picks: a holographic pass with a sheen and a live lock countdown.
    private var pass: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cpu").font(.system(size: 20, weight: .medium))
                kicker("PICK PASS", .black.opacity(0.65))
                Spacer()
                kicker("R17 · SINGAPORE", .black.opacity(0.65))
            }
            .foregroundStyle(.black.opacity(0.65))
            Text("MAKE YOUR PICKS").font(.f1(30).italic()).foregroundStyle(.black)
            HStack(spacing: 8) {
                slot("POLE", "NOR"); slot("WINNER", "PIA"); slot("FAST LAP", "—")
            }
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold))
                kicker("LOCKS IN", .black.opacity(0.6))
                Text("2D 04:31:07").font(.f1Digits(16)).foregroundStyle(.black)
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(Circle().fill(.black))
            }
            .foregroundStyle(.black.opacity(0.6))
        }
        .padding(20)
        .background(ZStack {
            AngularGradient(colors: [cyan, lime, gold, hotPink, magenta, electric, cyan], center: .init(x: 0.75, y: 0.2))
            Color.white.opacity(0.25)
            // diagonal holo sheen
            LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .init(x: 0.2, y: 0), endPoint: .init(x: 0.6, y: 1))
                .blendMode(.plusLighter)
        }.clipShape(RoundedRectangle(cornerRadius: 28)))
        .shadow(color: cyan.opacity(0.4), radius: 24, y: 10)
    }

    private func slot(_ label: String, _ code: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.f1(9, weight: .bold)).tracking(1.5).foregroundStyle(.black.opacity(0.55))
            Text(code).font(.f1(20)).foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .glass(RoundedRectangle(cornerRadius: 16))
    }

    // Emily: cyan duotone photo, HUD frame, AI input bar.
    private var emily: some View {
        ZStack(alignment: .bottom) {
            Color.clear.overlay(
                Image("EmilyAvatar").resizable().scaledToFill()
                    .saturation(0).colorMultiply(Color(red: 0.55, green: 0.88, blue: 1))
            )
            .clipped()
            LinearGradient(colors: [deepViolet.opacity(0.1), electric.opacity(0.35), deepViolet.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            Scanlines()
            Brackets().stroke(cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .padding(12).shadow(color: cyan, radius: 4)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(lime).frame(width: 7, height: 7).shadow(color: lime, radius: 4)
                        kicker("AI ONLINE", lime)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    Spacer()
                }
                Spacer()
                Text("EMILY").font(.f1(30).italic()).foregroundStyle(.white)
                kicker("YOUR RACE ENGINEER", cyan)
                HStack {
                    Text("Ask about strategy, tyres…").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Image(systemName: "mic.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.onAccent)
                        .frame(width: 40, height: 40).background(Circle().fill(Theme.accentGradient))
                }
                .padding(.leading, 18).padding(5)
                .background(Capsule().fill(.white.opacity(0.16)))
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(22)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: electric.opacity(0.45), radius: 24, y: 10)
    }

    // Lights out: liquid red, glossy lights, glass time pill.
    private var lights: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) { ForEach(0..<5, id: \.self) { _ in Orb(size: 46) } }
                .padding(.top, 6)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIGHTS OUT").font(.f1(26).italic()).foregroundStyle(.white)
                    kicker("REACTION TEST · #4 THIS WEEK", .white.opacity(0.75))
                }
                Spacer()
                VStack(spacing: 0) {
                    kicker("BEST", .white.opacity(0.7))
                    Text("0.198").font(.f1Digits(22)).foregroundStyle(.white)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glass(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(22)
        .background(ZStack {
            Aurora(colors: [blood, Theme.live, orange,
                            Theme.live, orange, Theme.live,
                            blood, Theme.live, blood])
            TopSheen()
        }.clipShape(RoundedRectangle(cornerRadius: 36)))
        .shadow(color: Theme.live.opacity(0.5), radius: 24, y: 10)
    }
}

// MARK: - Set 8: Bento (tiles of different sizes, vivid gradients, data first)

struct CardsDraft8: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                picks
                HStack(spacing: 12) { dotd; lights }
                emily
            }
            .padding(16).padding(.top, 46)
        }
    }

    private func tile<Content: View>(_ colors: [Color], radius: CGFloat = 30, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(ZStack { Aurora(colors: colors); TopSheen() }.clipShape(RoundedRectangle(cornerRadius: radius)))
    }

    // Wide tile: progress ring and the lock time.
    private var picks: some View {
        tile([electric, deepViolet, magenta,
              cyan, electric, deepViolet,
              electric, cyan, electric]) {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(.white.opacity(0.22), lineWidth: 11)
                    Circle().trim(from: 0, to: 0.5)
                        .stroke(LinearGradient(colors: [.white, lime], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 11, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: lime.opacity(0.8), radius: 8)
                    VStack(spacing: 0) {
                        Text("3/6").font(.f1Digits(28)).foregroundStyle(.white)
                        kicker("PICKS", .white.opacity(0.7))
                    }
                }
                .frame(width: 104, height: 104)
                VStack(alignment: .leading, spacing: 8) {
                    kicker("PREDICTION GAME", lime)
                    Text("FINISH\nYOUR PICKS").font(.f1(26).italic()).foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
                        Text("SAT 15:00").font(.f1(12, weight: .bold)).tracking(1.5)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7).glass()
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .shadow(color: electric.opacity(0.45), radius: 22, y: 10)
    }

    // Square tile: donut of the fan vote.
    private var dotd: some View {
        tile([hotPink, orange, gold,
              magenta, hotPink, orange,
              hotPink, magenta, magenta]) {
            VStack(alignment: .leading, spacing: 10) {
                kicker("DRIVER OF THE DAY")
                ZStack {
                    arc(0.00, 0.50, mercedes)
                    arc(0.52, 0.74, ferrari)
                    arc(0.76, 0.92, redbull)
                    VStack(spacing: 0) {
                        Text("ANT").font(.f1(20)).foregroundStyle(.white)
                        Text("52%").font(.f1Digits(14)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(width: 104, height: 104)
                .frame(maxWidth: .infinity)
                Text("VOTE →").font(.f1(13).italic()).tracking(1.5).foregroundStyle(.white)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(0.86, contentMode: .fit)
        }
        .shadow(color: hotPink.opacity(0.45), radius: 22, y: 10)
    }

    private func arc(_ from: Double, _ to: Double, _ color: Color) -> some View {
        Circle().trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .shadow(color: color, radius: 5)
    }

    // Square tile: lights and the best time.
    private var lights: some View {
        tile([blood, Theme.live, orange,
              blood, Theme.live, orange,
              blood, blood, Theme.live]) {
            VStack(alignment: .leading, spacing: 10) {
                kicker("LIGHTS OUT")
                HStack(spacing: 5) { ForEach(0..<5, id: \.self) { _ in Orb(size: 22) } }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                Spacer(minLength: 0)
                kicker("BEST", .white.opacity(0.7))
                Text("0.198").font(.f1Digits(34)).foregroundStyle(.white)
                Text("#4 this week").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(0.86, contentMode: .fit)
        }
        .shadow(color: Theme.live.opacity(0.45), radius: 22, y: 10)
    }

    // Wide tile: Emily as a chat input, bright mint.
    private var emily: some View {
        tile([cyan, mint, lime,
              electric, cyan, mint,
              cyan, mint, lime]) {
            HStack(alignment: .center, spacing: 14) {
                Color.clear.overlay(Image("EmilyAvatar").resizable().scaledToFill())
                    .frame(width: 76, height: 76).clipShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                VStack(alignment: .leading, spacing: 8) {
                    kicker("EMILY · AI RACE ENGINEER", .black.opacity(0.6))
                    Text("\"Copy. What do you want to know?\"").font(.system(size: 16, weight: .semibold).italic()).foregroundStyle(.black)
                    HStack {
                        Text("Ask anything…").font(.system(size: 14, weight: .medium)).foregroundStyle(.black.opacity(0.55))
                        Spacer()
                        Image(systemName: "arrow.up").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                            .frame(width: 30, height: 30).background(Circle().fill(.black))
                    }
                    .padding(.leading, 14).padding(4)
                    .glass()
                }
            }
            .padding(18)
        }
        .shadow(color: mint.opacity(0.4), radius: 22, y: 10)
    }
}
#endif
