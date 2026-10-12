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
}

/// The race hero card with two ways to travel through the season:
/// swipe left or right for the next or previous grand prix, or press and
/// hold to open a strip of the season's race boxes over the card. The strip
/// stays open: scroll it freely (the box in the middle is zoomed), then tap
/// the race to go to. Tapping around the boxes closes it.
struct RaceHeroCarousel: View {
    let season: [Race]
    let race: Race
    /// True while the strip is open (the page holds still meanwhile).
    @Binding var dockActive: Bool
    /// Which way the switch goes (shared so the page below follows).
    @Binding var edge: Edge
    let onSelect: (Race) -> Void
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    /// The race box in the middle of the strip.
    @State private var centeredId: String?
    @GestureState private var pull: CGFloat = 0

    private var index: Int? { season.firstIndex { $0.id == race.id } }
    private var nextRaceId: String? { season.first { ($0.startDate ?? .distantPast) > .now }?.id }

    var body: some View {
        ZStack {
            RaceHeroView(race: race)
                .id(race.id)
                .transition(.asymmetric(
                    insertion: .move(edge: edge).combined(with: .opacity),
                    removal: .move(edge: edge == .trailing ? .leading : .trailing).combined(with: .opacity)))
        }
        .animation(.snappy(duration: 0.4), value: race.id)
        .offset(x: dockActive ? 0 : pull * 0.35)
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
        .contentShape(Rectangle())
        .simultaneousGesture(swipe)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in open() }
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
            dockActive = true
        }
        #endif
    }

    // MARK: Swipe

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .updating($pull) { value, state, _ in
                guard !dockActive, abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard !dockActive,
                      abs(value.translation.width) > abs(value.translation.height) * 1.5,
                      abs(value.translation.width) > 50 else { return }
                step(value.translation.width < 0 ? 1 : -1)
            }
    }

    private func step(_ delta: Int) {
        guard let i = index, season.indices.contains(i + delta) else { return }
        edge = delta > 0 ? .trailing : .leading
        UISelectionFeedbackGenerator().selectionChanged()
        onSelect(season[i + delta])
    }

    // MARK: The strip

    private func open() {
        guard !dockActive else { return }
        centeredId = race.id
        tickIndex = index
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
                    ForEach(season) { r in
                        Button { pick(r) } label: {
                            RoundCard(race: r, isNext: r.id == nextRaceId, isSelected: r.id == race.id)
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
