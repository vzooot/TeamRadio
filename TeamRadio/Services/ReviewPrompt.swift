import StoreKit
import UIKit

/// Asks for an App Store rating at a good moment — after the user has done
/// something that shows they like the app — never more than the system
/// allows (three prompts a year) and never twice for the same milestone.
@MainActor
enum ReviewPrompt {
    private static let countKey = "reviewGoodMoments"
    private static let askedVersionKey = "reviewAskedVersion"

    /// Call when something went well (a pinned countdown, a sent message…).
    /// Asks on the third good moment of a version, once per version.
    static func goodMoment() {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard count >= 3, defaults.string(forKey: askedVersionKey) != version else { return }
        defaults.set(version, forKey: askedVersionKey)
        defaults.set(0, forKey: countKey)
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }
}
