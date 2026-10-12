import CoreHaptics
import UIKit

/// The feel of a rotary dial's detent: a sharp tap as the notch clicks in
/// and a soft rebound a moment later. Strength follows how fast the dial
/// turns. Falls back to a rigid impact where Core Haptics isn't available.
@MainActor
final class DialHaptics {
    static let shared = DialHaptics()

    private var engine: CHHapticEngine?
    private let fallback = UIImpactFeedbackGenerator(style: .rigid)

    func prepare() {
        fallback.prepare()
        guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in try? self?.engine?.start() }
        }
        try? engine?.start()
    }

    /// One detent; `strength` 0…1.
    func detent(strength: Float) {
        guard let engine else {
            fallback.impactOccurred(intensity: CGFloat(strength))
            return
        }
        let events = [
            // the notch: short, crisp
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: strength),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95),
            ], relativeTime: 0),
            // the spring settling back: softer and duller
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: strength * 0.35),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45),
            ], relativeTime: 0.018),
        ]
        guard let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player = try? engine.makePlayer(with: pattern) else {
            fallback.impactOccurred(intensity: CGFloat(strength))
            return
        }
        try? engine.start()
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}
