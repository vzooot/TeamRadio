import SwiftUI
import UserNotifications

/// Shows private-message pushes as banners even while the app is open, and
/// routes a tap on one to the Messages pane.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        NotificationCenter.default.post(name: .chatPushReceived, object: nil)
        // Room pushes are for when you're away — in the app, the room's own
        // sound and badge cover it. Private messages still get a banner.
        let ck = notification.request.content.userInfo["ck"] as? [String: Any]
        let subscription = (ck?["qry"] as? [String: Any])?["sid"] as? String ?? ""
        return subscription.hasPrefix("room-") ? [] : [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let ck = response.notification.request.content.userInfo["ck"] as? [String: Any]
        guard ck != nil else { return }
        let subscription = (ck?["qry"] as? [String: Any])?["sid"] as? String ?? ""
        NotificationCenter.default.post(name: subscription.hasPrefix("room-") ? .openPaddockRoom : .openPaddockMessages, object: nil)
    }
}

@main
struct TeamRadioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = 0
    @State private var chatBadge = ChatBadge()
    @State private var showMessageToast = false
    @State private var toastDismissTask: Task<Void, Never>?

    var body: some View {
        TabView(selection: $selection) {
            ContentView()
                .tabItem { Label("Countdown", systemImage: "flag.checkered") }
                .tag(0)
            ResultsView()
                .tabItem { Label("Results", systemImage: "trophy.fill") }
                .tag(1)
            StandingsTabView()
                .tabItem { Label("Standings", systemImage: "list.number") }
                .tag(2)
            ChatView()
                .tabItem { Label("Paddock", systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(chatBadge.unread)
                .tag(3)
            NewsView()
                .tabItem { Label("News", systemImage: "newspaper.fill") }
                .tag(4)
        }
        .tint(Theme.accent)
        .onAppear {
            chatBadge.start()
            PushSync.start()
            // CloudKit delivers private-message notifications through APNs;
            // registering is all it needs (the token stays with Apple).
            UIApplication.shared.registerForRemoteNotifications()
        }
        // teamradio://countdown|results|standings|paddock|news
        .onOpenURL { url in
            let map = ["countdown": 0, "results": 1, "standings": 2, "paddock": 3, "news": 4]
            if let tab = map[(url.host ?? "").lowercased()] {
                selection = tab
            }
        }
        .onChange(of: selection) { _, tab in
            if tab == 3 {
                chatBadge.markRead()
                withAnimation(.easeOut(duration: 0.2)) { showMessageToast = false }
            }
        }
        .onChange(of: chatBadge.unread) { old, new in
            guard new > old, selection != 3 else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showMessageToast = true }
            toastDismissTask?.cancel()
            toastDismissTask = Task {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.35)) { showMessageToast = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPaddockMessages)) { _ in
            selection = 3
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPaddockRoom)) { _ in
            selection = 3
        }
        // The badge is blue for room chatter, red as soon as a private message waits.
        .onChange(of: chatBadge.unread) { _, _ in TabBarBadge.tint(private: chatBadge.unreadDMs > 0) }
        .onChange(of: chatBadge.unreadDMs) { _, _ in TabBarBadge.tint(private: chatBadge.unreadDMs > 0) }
        .overlay(alignment: .bottom) {
            if showMessageToast {
                MessageToast(sender: chatBadge.latestSender, text: chatBadge.latestText, isPrivate: chatBadge.latestIsPrivate) {
                    selection = 3
                    if chatBadge.latestIsPrivate {
                        NotificationCenter.default.post(name: .openPaddockMessages, object: nil)
                    }
                }
                .padding(.bottom, 62)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                LiveActivityManager.refresh()
                chatBadge.start()
            } else {
                chatBadge.stop()
            }
        }
    }
}

/// Social-style drop-in banner for a fresh paddock message; tap to jump there.
struct MessageToast: View {
    let sender: String
    let text: String
    var isPrivate = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isPrivate ? "paperplane.fill" : "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isPrivate ? Theme.live : Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(isPrivate ? "PRIVATE · \(sender.uppercased())" : (sender.isEmpty ? "PADDOCK" : sender.uppercased()))
                        .font(.f1(12).italic())
                        .foregroundStyle(isPrivate ? Theme.live : Theme.accent)
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.dimText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Theme.card)
                    .overlay(Capsule().strokeBorder((isPrivate ? Theme.live : Theme.accent).opacity(0.5), lineWidth: 1))
                    .shadow(color: (isPrivate ? Theme.live : Theme.accent).opacity(0.4), radius: 14, y: 4)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 340)
    }
}

/// Colours the Paddock tab's badge: iOS draws it red; we recolour the
/// UIKit item underneath (blue for the room, red when a private message waits).
enum TabBarBadge {
    static func tint(private isPrivate: Bool) {
        DispatchQueue.main.async {
            let color = UIColor(isPrivate ? Theme.live : Theme.accent)
            let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            for window in windows {
                for bar in window.allSubviews(of: UITabBar.self) {
                    bar.items?.forEach { $0.badgeColor = color }
                }
            }
        }
    }
}

private extension UIView {
    func allSubviews<T: UIView>(of type: T.Type) -> [T] {
        subviews.flatMap { ($0 as? T).map { [$0] } ?? [] + $0.allSubviews(of: type) }
    }
}
