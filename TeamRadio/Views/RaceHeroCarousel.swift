import SwiftUI
import UIKit

/// The race hero card with two ways to travel through the season:
/// swipe left or right for the next or previous grand prix, or press and
/// hold to bring up a strip of the season's race boxes over the card. Keep
/// holding and drag: the strip slides with your finger, the box in the
/// middle is zoomed, and letting go goes to that race.
struct RaceHeroCarousel: View {
    let season: [Race]
    let race: Race
    /// True while the strip is up (the page shouldn't scroll meanwhile).
    @Binding var dockActive: Bool
    let onSelect: (Race) -> Void

    @State private var edge: Edge = .trailing
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    /// Where the strip was centred when it opened, and how far it's dragged.
    @State private var startIndex = 0
    @State private var dragX: CGFloat = 0
    @State private var centered: Int?
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
        .animation(.snappy(duration: 0.35), value: race.id)
        .offset(x: dockActive ? 0 : pull * 0.35)
        .overlay {
            if dockActive {
                strip.transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: dockActive)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { width = geo.size.width; height = geo.size.height }
                .onChange(of: geo.size) { _, size in width = size.width; height = size.height }
        })
        .contentShape(Rectangle())
        .simultaneousGesture(swipe)
        .simultaneousGesture(holdAndSlide)
        .accessibilityAction(named: "Next grand prix") { step(1) }
        .accessibilityAction(named: "Previous grand prix") { step(-1) }
        #if DEBUG
        // -RaceStripDemo N: show the strip with round N in the middle, for screenshots
        .task {
            let n = UserDefaults.standard.integer(forKey: "RaceStripDemo")
            guard n > 0 else { return }
            try? await Task.sleep(for: .seconds(2))
            startIndex = n - 1
            centered = n - 1
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

    // MARK: Hold, then slide the strip

    /// Distance between box centres in the strip.
    private let pitch: CGFloat = 104

    /// The strip's position in boxes: the current race plus the drag.
    private var position: CGFloat {
        let raw = CGFloat(startIndex) - dragX / pitch
        return min(max(raw, -0.4), CGFloat(max(season.count - 1, 0)) + 0.4)
    }

    private var holdAndSlide: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !dockActive {
                    startIndex = index ?? 0
                    centered = startIndex
                    dockActive = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                dragX = drag?.translation.width ?? 0
                let i = min(max(Int(position.rounded()), 0), max(season.count - 1, 0))
                if i != centered {
                    centered = i
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .onEnded { value in
                if case .second(true, _) = value, let i = centered, season.indices.contains(i), season[i].id != race.id {
                    edge = i > (index ?? 0) ? .trailing : .leading
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(season[i])
                }
                dockActive = false
                dragX = 0
                centered = nil
            }
    }

    /// The season's race boxes over the dimmed card: they slide with the
    /// finger, the middle one zoomed and lit, the others shrinking away.
    private var strip: some View {
        let p = position
        return ZStack {
            RoundedRectangle(cornerRadius: 20).fill(Theme.background.opacity(0.96))
            RoundedRectangle(cornerRadius: 20).fill(RadialGradient(colors: [Theme.violet.opacity(0.18), .clear],
                                                                   center: .center, startRadius: 0, endRadius: 200))
            ForEach(Array(season.enumerated()), id: \.element.id) { i, r in
                let distance = CGFloat(i) - p
                if abs(distance) < 3.5 {
                    let zoom = max(0.68, 1.22 - 0.24 * abs(distance))
                    RoundCard(race: r, isNext: r.id == nextRaceId, isSelected: i == centered)
                        .scaleEffect(zoom)
                        .opacity(Double(max(0.3, 1 - 0.28 * abs(distance))))
                        .zIndex(10 - Double(abs(distance)))
                        .position(x: width / 2 + distance * pitch, y: height / 2 + 6)
                        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: p)
                }
            }
            Text("SLIDE · RELEASE TO GO")
                .font(.f1(9, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Theme.dimText)
                .position(x: width / 2, y: height - 16)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .allowsHitTesting(false)
    }
}
