import UIKit

/// The arcade games' taps, kept prepared: a generator made fresh for every
/// hit isn't warmed up, and iOS drops many of those in a fast game.
@MainActor
enum ArcadeHaptics {
    private static let hitTap = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyTap = UIImpactFeedbackGenerator(style: .heavy)
    private static let missKnock = UIImpactFeedbackGenerator(style: .rigid)
    private static let result = UINotificationFeedbackGenerator()

    /// When a game opens, so the first tap is instant.
    static func prepare() {
        hitTap.prepare()
        heavyTap.prepare()
        missKnock.prepare()
        result.prepare()
    }

    /// A light hit; a red (double) light hits harder.
    static func hit(double: Bool) {
        let generator = double ? heavyTap : hitTap
        generator.impactOccurred(intensity: double ? 1 : 0.85)
        generator.prepare()
    }

    static func miss() {
        missKnock.impactOccurred(intensity: 1)
        missKnock.prepare()
    }

    /// A finished run; a personal best gets a triple buzz.
    static func finished(personalBest: Bool) {
        result.notificationOccurred(.success)
        guard personalBest else { return }
        Task {
            for _ in 0..<2 {
                try? await Task.sleep(for: .milliseconds(140))
                heavyTap.impactOccurred(intensity: 1)
            }
        }
    }
}
