import SwiftUI
import UIKit

/// The race hero card with two ways to travel through the season:
/// swipe left or right for the next or previous grand prix, or press and
/// hold to call up a dock of every race. Slide along it without letting go:
/// the race under your finger magnifies like the Mac's Dock, and releasing
/// goes to it.
struct RaceHeroCarousel: View {
    let season: [Race]
    let race: Race
    /// True while the dock is up (the page shouldn't scroll meanwhile).
    @Binding var dockActive: Bool
    let onSelect: (Race) -> Void

    @State private var edge: Edge = .trailing
    @State private var width: CGFloat = 0
    @State private var fingerX: CGFloat?
    @State private var hovered: Int?
    @GestureState private var pull: CGFloat = 0

    private var index: Int? { season.firstIndex { $0.id == race.id } }

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
        .overlay(alignment: .bottom) {
            if dockActive {
                ZStack(alignment: .bottom) {
                    // dim the card so the dock stands out
                    RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.55))
                    dock
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dockActive)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { width = geo.size.width }
                .onChange(of: geo.size.width) { _, w in width = w }
        })
        .contentShape(Rectangle())
        .coordinateSpace(name: "raceHero")
        .simultaneousGesture(swipe)
        .simultaneousGesture(holdAndScrub)
        .accessibilityAction(named: "Next grand prix") { step(1) }
        .accessibilityAction(named: "Previous grand prix") { step(-1) }
        #if DEBUG
        // -RaceDockDemo N: show the dock with round N under the finger, for screenshots
        .task {
            let n = UserDefaults.standard.integer(forKey: "RaceDockDemo")
            guard n > 0 else { return }
            try? await Task.sleep(for: .seconds(2))
            dockActive = true
            hovered = n - 1
            fingerX = center(of: n - 1)
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

    // MARK: Hold and scrub

    private var holdAndScrub: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("raceHero")))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !dockActive {
                    dockActive = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                let x = drag?.location.x ?? center(of: index ?? 0)
                fingerX = x
                let i = slotIndex(at: x)
                if i != hovered {
                    hovered = i
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .onEnded { value in
                if case .second(true, _) = value, let i = hovered, season.indices.contains(i), season[i].id != race.id {
                    edge = i > (index ?? 0) ? .trailing : .leading
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(season[i])
                }
                dockActive = false
                fingerX = nil
                hovered = nil
            }
    }

    private let inset: CGFloat = 14
    private var slot: CGFloat { (width - inset * 2) / CGFloat(max(season.count, 1)) }
    private func center(of i: Int) -> CGFloat { inset + slot * (CGFloat(i) + 0.5) }
    private func slotIndex(at x: CGFloat) -> Int {
        min(max(Int(((x - inset) / max(slot, 1)).rounded(.down)), 0), max(season.count - 1, 0))
    }

    /// The dock: a frosted shelf of flags that swell under the finger.
    private var dock: some View {
        let x = fingerX ?? center(of: index ?? 0)
        let shelf: CGFloat = 46
        return ZStack(alignment: .topLeading) {
            // shelf
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.glassStroke, lineWidth: 1))
                .frame(width: max(width - 12, 0), height: shelf)
                .position(x: width / 2, y: 150 - shelf / 2 - 6)
                .environment(\.colorScheme, .dark)

            ForEach(Array(season.enumerated()), id: \.element.id) { i, r in
                let distance = center(of: i) - x
                let magnify = 1 + 1.9 * exp(-(distance * distance) / (2 * 30 * 30))
                let isNext = r.id == season.first(where: { ($0.startDate ?? .distantPast) > .now })?.id
                Text(Flags.emoji(for: r.circuit.location.country))
                    .font(.system(size: 13))
                    .scaleEffect(magnify, anchor: .bottom)
                    .opacity((r.startDate ?? .distantFuture) < .now && !isNext ? 0.7 : 1)
                    .overlay(alignment: .bottom) {
                        if isNext { Circle().fill(Theme.accent).frame(width: 4, height: 4).offset(y: 6) }
                    }
                    .position(x: center(of: i), y: 150 - shelf / 2 - 12)
                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.8), value: x)
            }

            // label of the race under the finger
            if let i = hovered, season.indices.contains(i) {
                let r = season[i]
                VStack(spacing: 1) {
                    Text("ROUND \(r.roundNumber)").font(.f1(9, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.accent)
                    Text(PicksCard.shortName(r)).font(.f1(13).italic()).foregroundStyle(.white).lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.75)))
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1))
                .fixedSize()
                .position(x: min(max(center(of: i), 70), width - 70), y: 22)
            }
        }
        .frame(width: width, height: 150)
        .allowsHitTesting(false)
    }
}
