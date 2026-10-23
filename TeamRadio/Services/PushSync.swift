import ActivityKit
import Foundation

/// Registers this device for server-started Lock Screen countdowns: ActivityKit
/// hands out a "push-to-start" token, and the Team Radio worker uses it to
/// start the session Live Activity ~15 minutes before lights out — app closed
/// or not.
enum PushSync {
    /// The Cloudflare worker's register endpoint.
    private static let endpoint = URL(string: "https://teamradio-push.eam-adio.workers.dev/register")!

    private static var started = false
    private static let tokenKey = "pushToStartToken"
    static let leadKey = "autoCountdownLead"

    /// Minutes before each session the server starts the Lock Screen
    /// countdown: 0 (off), 15, 60 (default) or 180.
    static var lead: Int {
        get { UserDefaults.standard.object(forKey: leadKey) as? Int ?? 60 }
        set {
            UserDefaults.standard.set(newValue, forKey: leadKey)
            if let token = UserDefaults.standard.string(forKey: tokenKey) {
                Task.detached(priority: .utility) { await upload(token) }
            }
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

    /// The regular APNs token, for the server's announcements. Sent once per
    /// token (it rarely changes).
    static func uploadDeviceToken(_ token: String) async {
        let key = "deviceTokenSent"
        guard UserDefaults.standard.string(forKey: key) != token else { return }
        var request = URLRequest(url: URL(string: "https://teamradio-push.eam-adio.workers.dev/register-device")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": token, "env": BuildSigning.isDevelopment ? "sandbox" : "production",
        ])
        if let (_, response) = try? await URLSession.shared.data(for: request),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            UserDefaults.standard.set(token, forKey: key)
        }
    }

    private static func upload(_ token: String) async {
        // Development-signed builds get sandbox APNs tokens; TestFlight/App
        // Store get production ones. The worker needs to know which gate to knock on.
        let env = BuildSigning.isDevelopment ? "sandbox" : "production"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let lead = UserDefaults.standard.object(forKey: leadKey) as? Int ?? 60
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token, "env": env, "lead": lead])
        _ = try? await URLSession.shared.data(for: request)
    }
}
