import SwiftUI

/// Launch intro, about two seconds: the start gantry fades in, the five
/// lights come on one by one, lights out, and the TEAM RADIO wordmark
/// slams in with a glow and a shine sweep, then everything fades into the
/// app. Tap to skip; skipped entirely with Reduce Motion.
struct IntroView: View {
    let onFinish: () -> Void

    @State private var gantryIn = false
    @State private var lit = 0
    @State private var lightsOut = false
    @State private var flash = 0.0
    @State private var logoIn = false
    @State private var shine: CGFloat = -1
    @State private var fading = false
    @State private var sequence: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            CarbonFiber().ignoresSafeArea().opacity(0.5)
            RadialGradient(colors: [(lightsOut ? Theme.accent : Theme.live).opacity(lit > 0 || lightsOut ? 0.25 : 0), .clear],
                           center: .center, startRadius: 0, endRadius: 460)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: lit)
                .animation(.easeOut(duration: 0.3), value: lightsOut)

            gantry
                .scaleEffect(lightsOut ? 1.6 : (gantryIn ? 1 : 0.9))
                .opacity(lightsOut ? 0 : (gantryIn ? 1 : 0))
                .blur(radius: lightsOut ? 8 : 0)

            wordmark
                .scaleEffect(logoIn ? 1 : 1.8)
                .opacity(logoIn ? 1 : 0)
                .blur(radius: logoIn ? 0 : 12)

            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .opacity(fading ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task { run() }
        .onDisappear { sequence?.cancel() }
    }

    private var gantry: some View {
        HStack(spacing: 9) {
            ForEach(0..<5, id: \.self) { column in
                let on = column < lit
                VStack(spacing: 7) {
                    ForEach(0..<2, id: \.self) { _ in
                        Circle()
                            .fill(on ? Theme.live : Color(white: 0.09))
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.8), lineWidth: 2.5))
                            .frame(width: 34, height: 34)
                            .shadow(color: on ? Theme.live.opacity(0.95) : .clear, radius: 14)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 7)
                    .fill(LinearGradient(colors: [Color(white: 0.13), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.05), value: lit)
    }

    private var wordmark: some View {
        Image("HeaderWordmark")
            .resizable()
            .scaledToFit()
            .frame(width: 300)
            .shadow(color: Theme.accent.opacity(0.8), radius: 24)
            .overlay {
                // a single light sweep across the chrome
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white.opacity(0.75), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.35)
                        .rotationEffect(.degrees(18))
                        .offset(x: shine * geo.size.width * 1.3)
                }
                .mask(Image("HeaderWordmark").resizable().scaledToFit())
                .allowsHitTesting(false)
            }
    }

    private func run() {
        sequence = Task { @MainActor in
            StartSounds.shared.prepare()
            withAnimation(.easeOut(duration: 0.35)) { gantryIn = true }
            try? await Task.sleep(for: .seconds(0.35))
            for n in 1...5 {
                if Task.isCancelled { return }
                lit = n
                StartSounds.shared.beep()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                try? await Task.sleep(for: .seconds(0.22))
            }
            try? await Task.sleep(for: .seconds(0.35))
            if Task.isCancelled { return }
            // lights out
            withAnimation(.easeIn(duration: 0.25)) { lightsOut = true }
            flash = 0.55
            withAnimation(.easeOut(duration: 0.4)) { flash = 0 }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { logoIn = true }
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.easeInOut(duration: 0.7)) { shine = 1.2 }
            try? await Task.sleep(for: .seconds(0.9))
            if Task.isCancelled { return }
            finish()
        }
    }

    private func finish() {
        sequence?.cancel()
        withAnimation(.easeOut(duration: 0.35)) { fading = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            onFinish()
        }
    }
}
