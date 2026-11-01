import ActivityKit
import Foundation

/// Registers this device for server-started Lock Screen countdowns: ActivityKit
/// hands out a "push-to-start" token, and the Team Radio worker uses it to
/// start each session's Live Activity the chosen hours before lights out
/// (1, 2, 4 or 8), app closed or not.
enum PushSync {
    /// The Cloudflare worker's register endpoint.
    private static let endpoint = URL(string: "https://teamradio-push.eam-adio.workers.dev/register")!

    private static var started = false
    private static let tokenKey = "pushToStartToken"
    private static let countdownOnKey = "lockScreenCountdownOn"
    private static let hoursKey = "lockScreenCountdownHours"
    /// Before 1.3.3: one value, minutes (0 = off, 15, 60 or 180).
    private static let legacyLeadKey = "autoCountdownLead"

    static let hourChoices = [1, 2, 4, 8]

    /// The automatic Lock Screen countdown. On unless turned off (an old
    /// "OFF" stays off).
    static var countdownOn: Bool {
        get {
            if let on = UserDefaults.standard.object(forKey: countdownOnKey) as? Bool { return on }
            return (UserDefaults.standard.object(forKey: legacyLeadKey) as? Int ?? 480) != 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: countdownOnKey)
            resend()
        }
    }

    /// Hours before each session the countdown starts. 8 by default, which
    /// is also what the old 15 min / 1 h / 3 h choices always got.
    static var countdownHours: Int {
        get {
            let hours = UserDefaults.standard.integer(forKey: hoursKey)
            return hourChoices.contains(hours) ? hours : 8
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hoursKey)
            resend()
        }
    }

    /// Minutes the server should start the countdown ahead; 0 is off.
    private static var lead: Int { countdownOn ? countdownHours * 60 : 0 }

    private static func resend() {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            Task.detached(priority: .utility) { await upload(token) }
        }
    }

    static func start() {
        guard !started else { return }
        started = true
        Task.detached(priority: .background) {
            guard #available(iOS 17.2, *) else { return }
            for await tokenData in Activity<RaceActivityAttributes>.pushToStartTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                UserDefaults.standard.set(token, forKey: tokenKey)
                await upload(token)
            }
        }
    }

    private static let deviceTokenKey = "deviceToken"
    private static let deviceTokenSentKey = "deviceTokenSent"

    /// The regular APNs token, for the server's announcements. Sent once per
    /// token (it rarely changes), on or off as Settings say.
    static func uploadDeviceToken(_ token: String) async {
        UserDefaults.standard.set(token, forKey: deviceTokenKey)
        guard UserDefaults.standard.string(forKey: deviceTokenSentKey) != token else { return }
        if await sendDeviceToken(token) { UserDefaults.standard.set(token, forKey: deviceTokenSentKey) }
    }

    /// Settings changed: tells the server whether this phone gets its
    /// announcements ("Picks are open", "Results are in").
    @MainActor
    static func syncAnnouncements() async {
        guard let token = UserDefaults.standard.string(forKey: deviceTokenKey)
            ?? UserDefaults.standard.string(forKey: deviceTokenSentKey) else { return }
        _ = await sendDeviceToken(token)
    }

    private static func sendDeviceToken(_ token: String) async -> Bool {
        let off = await MainActor.run { !AppSettings.notificationsOn || !AppSettings.news }
        var request = URLRequest(url: URL(string: "https://teamradio-push.eam-adio.workers.dev/register-device")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": token, "env": BuildSigning.isDevelopment ? "sandbox" : "production", "off": off,
        ])
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    private static func upload(_ token: String) async {
        // Development-signed builds get sandbox APNs tokens; TestFlight/App
        // Store get production ones. The worker needs to know which gate to knock on.
        let env = BuildSigning.isDevelopment ? "sandbox" : "production"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // v2: the lead is in minutes, 0 (off), 60, 120, 240 or 480.
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token, "env": env, "lead": lead, "v": 2])
        _ = try? await URLSession.shared.data(for: request)
    }
}
