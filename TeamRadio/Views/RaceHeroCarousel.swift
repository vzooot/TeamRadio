import AudioToolbox
import SwiftUI
import UIKit

private extension View {
    /// Calls `action` with the index of the box in the middle as the strip
    /// scrolls (iOS 18+; on iOS 17 the strip simply has no ticks).
    @ViewBuilder
    func onScrollTicks(pitch: CGFloat, _ action: @escaping (Int) -> Void) -> some View {
        if #available(iOS 18, *) {
            onScrollGeometryChange(for: Int.self) { geo in
                Int(((geo.contentOffset.x + geo.contentInsets.leading) / pitch).rounded())
            } action: { _, index in
                action(index)
            }
        } else {
            self
        }
    }

    /// Calls `action` when scrolling comes to rest (iOS 18+); on iOS 17
    /// whenever `value` changes.
    @ViewBuilder
    func onScrollSettled<V: Equatable>(_ value: V, _ action: @escaping () -> Void) -> some View {
        if #available(iOS 18, *) {
            onScrollPhaseChange { _, phase in
                if phase == .idle { action() }
            }
        } else {
            onChange(of: value) { _, _ in action() }
        }
    }
}

/// The race hero card as a line of every grand prix in the season: drag
/// sideways and the neighbouring cards slide along with your finger, then
/// the line snaps to a card and that race shows. Press and hold to open a
/// strip of the season's race boxes over the card: scroll it freely (the
/// box in the middle is zoomed), then tap the race to go to. Tapping around
/// the boxes closes it.
struct RaceHeroCarousel: View {
    let season: [Race]
    let race: Race
    /// True while the strip is open (the page holds still meanwhile).
    @Binding var dockActive: Bool
    /// Which way the switch goes (shared so the page below follows).
    @Binding var edge: Edge
    /// The next race (its card has no way back; every other card does).
    var nextId: String? = nil
    var onBack: (() -> Void)? = nil
    let onSelect: (Race) -> Void
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    /// The race box in the middle of the strip.
    @State private var centeredId: String?
    /// The card the line has settled on.
    @State private var pagedId: String?
    /// A card the line is gliding to by itself (not the user's scroll).
    @State private var gliding: String?
    /// The box in the middle of the open strip (highlighted; tap to go).
    @State private var middle: Int?

    private var index: Int? { season.firstIndex { $0.id == race.id } }
    private var nextRaceId: String? { season.first { ($0.startDate ?? .distantPast) > .now }?.id }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(season) { r in
                    RaceHeroView(race: r, onBack: r.id == nextId ? nil : onBack)
                        .overlay { ShineSweep(cornerRadius: 20) }
                        .containerRelativeFrame(.horizontal)
                        .id(r.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $pagedId)
        // let the neighbours show at the page edges, like one long line
        .scrollClipDisabled()
        .scrollDisabled(dockActive)
        .onAppear { if pagedId == nil { pagedId = race.id } }
        // Come to rest on a card the user scrolled to: show that race. Cards
        // passed on the way (or during a programmatic glide) don't count.
        .onScrollSettled(pagedId) {
            if let target = gliding {
                if pagedId == target { gliding = nil }
                return
            }
            guard let id = pagedId, id != race.id, let picked = season.first(where: { $0.id == id }) else { return }
            edge = (season.firstIndex { $0.id == id } ?? 0) > (index ?? 0) ? .trailing : .leading
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect(picked)
        }
        // switched elsewhere (strip, season list, back button): glide there
        .onChange(of: race.id) { _, id in
            guard pagedId != id else { return }
            gliding = id
            withAnimation(.snappy(duration: 0.4)) { pagedId = id }
            // never leave the line deaf if the glide's end goes unreported
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                if gliding == id { gliding = nil }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // the card can be held for all races
            if !dockActive {
                HoldHint().padding(12).transition(.opacity)
            }
        }
        .overlay {
            if dockActive {
                strip.transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: dockActive)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { width = geo.size.width; height = geo.size.height }
                .onChange(of: geo.size) { _, size in width = size.width; height = size.height }
        })
        // Hold to open the strip; keep the finger down and slide to run
        // through the races straight away. After lifting, the strip
        // scrolls as usual.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    guard case .second(true, let drag) = value else { return }
                    if !dockActive {
                        open()
                        holdStart = index
                    }
                    if let drag, let start = holdStart { follow(drag.translation.width, from: start) }
                }
                .onEnded { _ in holdStart = nil }
        )
        .accessibilityAction(named: "Next grand prix") { step(1) }
        .accessibilityAction(named: "Previous grand prix") { step(-1) }
        .accessibilityAction(named: "All races") { open() }
        #if DEBUG
        // -RaceStripDemo N: open the strip on round N, for screenshots
        .task {
            let n = UserDefaults.standard.integer(forKey: "RaceStripDemo")
            guard n > 0, season.indices.contains(n - 1) else { return }
            try? await Task.sleep(for: .seconds(2))
            centeredId = season[n - 1].id
            middle = n - 1
            tickIndex = n - 1
            dockActive = true
        }
        #endif
    }

    private func step(_ delta: Int) {
        guard let i = index, season.indices.contains(i + delta) else { return }
        withAnimation(.snappy(duration: 0.4)) { pagedId = season[i + delta].id }
    }

    // MARK: The strip

    private func open() {
        guard !dockActive else { return }
        holdTarget = nil
        centeredId = race.id
        tickIndex = index
        middle = index
        dockActive = true
        DialHaptics.shared.prepare()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// A dial detent each time a box crosses the middle: firm and distinct
    /// when turned slowly, lighter and quicker when spun.
    @State private var tickIndex: Int?
    @State private var lastTick = Date.distantPast

    private func passed(_ i: Int) {
        guard i != tickIndex, season.indices.contains(i) else { return }
        tickIndex = i
        middle = i
        let gap = Date.now.timeIntervalSince(lastTick)
        lastTick = .now
        let strength: Float = gap < 0.05 ? 0.45 : gap < 0.12 ? 0.65 : 0.9
        DialHaptics.shared.detent(strength: strength)
        // the iPhone's own recorded keyboard tock; in a fast spin the
        // clicks blur, so not every one sounds
        if gap > 0.04 { AudioServicesPlaySystemSound(1104) }
    }

    private func close() {
        dockActive = false
    }

    /// The round the strip was on when the holding finger opened it (nil
    /// once it lifts, so later touches scroll the strip normally).
    @State private var holdStart: Int?
    /// The round the holding finger has dragged the strip to.
    @State private var holdTarget: Int?

    /// One box per box-width of finger travel; dragging left goes to later races.
    private func follow(_ dx: CGFloat, from start: Int) {
        let target = min(max(start - Int((dx / (boxWidth + spacing)).rounded()), 0), season.count - 1)
        if target != holdTarget { holdTarget = target }
    }

    /// Go to a race from the strip: the strip closes and the card slides over.
    private func pick(_ picked: Race) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        close()
        guard picked.id != race.id else { return }
        edge = (season.firstIndex { $0.id == picked.id } ?? 0) > (index ?? 0) ? .trailing : .leading
        // let the strip fade first, then slide the card
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            onSelect(picked)
        }
    }

    private let boxWidth: CGFloat = 92
    private let spacing: CGFloat = 10

    private var strip: some View {
        ZStack(alignment: .topTrailing) {
            // tapping around the boxes closes the strip
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.background)
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .fill(RadialGradient(colors: [Theme.violet.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 200)))
                .onTapGesture { close() }

            ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(Array(season.enumerated()), id: \.element.id) { i, r in
                        // the middle box is lit and goes there; a side box
                        // only rolls into the middle
                        Button {
                            if i == middle {
                                pick(r)
                            } else {
                                withAnimation(.snappy(duration: 0.3)) { proxy.scrollTo(r.id, anchor: .center) }
                            }
                        } label: {
                            RoundCard(race: r, isNext: r.id == nextRaceId, isSelected: i == middle)
                        }
                        .buttonStyle(.plain)
                        .id(r.id)
                        // the box in the middle zooms, the others shrink and fade
                        .visualEffect { content, proxy in
                            let frame = proxy.frame(in: .scrollView(axis: .horizontal))
                            let viewport = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? 0
                            let distance = abs(frame.midX - viewport / 2)
                            return content
                                .scaleEffect(max(0.74, 1.2 - distance / 380))
                                .opacity(max(0.35, 1 - distance / 420))
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 24)
            }
            .contentMargins(.horizontal, max((width - boxWidth) / 2, 0), for: .scrollContent)
            // a flick can carry across several races before it snaps
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .onScrollTicks(pitch: boxWidth + spacing) { passed($0) }
            .frame(height: height)
            .onAppear {
                // open centred on the race in the card
                if let id = centeredId { proxy.scrollTo(id, anchor: .center) }
            }
            // the finger that opened the strip steers it until it lifts
            .onChange(of: holdTarget) { _, target in
                guard let target, season.indices.contains(target) else { return }
                withAnimation(.snappy(duration: 0.18)) { proxy.scrollTo(season[target].id, anchor: .center) }
            }
            }

            Button { close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.dimText)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("Close")

            Text("SCROLL · TAP A RACE TO GO")
                .font(.f1(9, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Theme.dimText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

/// A band of light sweeping across a card every few seconds, like light
/// catching glass (none under Reduce Motion).
struct ShineSweep: View {
    var cornerRadius: CGFloat = 20
    var every: Double = 6
    var duration: Double = 1.3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = band just left of the card, 1 = past its right edge.
    @State private var progress: CGFloat = 1

    var body: some View {
        if !reduceMotion {
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.16), .white.opacity(0.28), .white.opacity(0.16), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.4, height: geo.size.height * 1.6)
                    .rotationEffect(.degrees(20))
                    .offset(x: -geo.size.width * 0.5 + progress * geo.size.width * 1.6,
                            y: -geo.size.height * 0.3)
                    .blendMode(.plusLighter)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            // One animation per sweep, idle in between (it used to redraw 30
            // times a second on every card). Timed to the clock, so all cards
            // still sweep together.
            .task {
                while !Task.isCancelled {
                    let now = Date.now.timeIntervalSinceReferenceDate
                    try? await Task.sleep(for: .seconds(every - now.truncatingRemainder(dividingBy: every)))
                    guard !Task.isCancelled else { return }
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) { progress = 0 }
                    withAnimation(.linear(duration: duration)) { progress = 1 }
                }
            }
        }
    }
}

/// "Hold" for all races, gently pulsing in the card's corner.
private struct HoldHint: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap.fill").font(.system(size: 9, weight: .bold))
            Text("HOLD").font(.f1(9, weight: .heavy)).tracking(1.2)
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1))
        .phaseAnimator([0.55, 1.0]) { hint, opacity in
            hint.opacity(opacity)
        } animation: { _ in .easeInOut(duration: 1.2) }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
