import SwiftUI
import UIKit
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

    /// The device's APNs token goes to our server, so it can send
    /// announcements ("Picks are open for Austin").
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task.detached(priority: .utility) { await PushSync.uploadDeviceToken(token) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        // A server announcement can point at a tab: teamradio://games etc.
        if let link = info["link"] as? String, let url = URL(string: link), url.scheme == "teamradio" {
            await UIApplication.shared.open(url)
            return
        }
        let ck = info["ck"] as? [String: Any]
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
    /// Tab tags, also used by deep links and the -Tab screenshot hook.
    enum Tab {
        static let countdown = 0, results = 1, games = 2, paddock = 3, news = 4
    }

    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    // -Tab N: open on a tab, for screenshots
    @State private var selection = UserDefaults.standard.string(forKey: "Tab").flatMap(Int.init) ?? 0
    #else
    @State private var selection = 0
    #endif
    @State private var chatBadge = ChatBadge()
    /// Loaded at launch, so the Games tab opens ready.
    @State private var games = GamesModel()
    @State private var showMessageToast = false
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var profile: ProfileTarget?
    @State private var showNotificationPrompt = false
    @State private var showIntro = false   // the lights intro is out; a designed clip replaces it
    #if DEBUG
    // -ResultsPage standings: open on the standings, for screenshots
    @State private var resultsPage: ResultsHubView.Page = UserDefaults.standard.string(forKey: "ResultsPage") == "standings" ? .standings : .results
    #else
    @State private var resultsPage: ResultsHubView.Page = .results
    #endif
    /// The iPhone Duo's inner display held like a book: our own rail
    /// replaces the system's tab bar (see DuoDock).
    @State private var halves: Halves?
    private var docked: Bool { halves?.axis == .horizontal && halves?.foldable == true }
    /// The season's champion once the title is settled, and its moment.
    @State private var champion: Champion?
    @State private var showChampion = false
    @State private var checkingChampion = false
    #if DEBUG
    private static let designLabOpen = UserDefaults.standard.string(forKey: "DesignLab") != nil
    #else
    private static let designLabOpen = false
    #endif

    var body: some View {
        TabView(selection: $selection) {
            // Outline icons only, no titles (tab bars fill symbols unless told
            // not to; VoiceOver still reads each name).
            ContentView()
                .tabItem { Image(systemName: "flag.checkered").environment(\.symbolVariants, .none).accessibilityLabel("Countdown") }
                .tag(Tab.countdown)
                .toolbar(docked ? .hidden : .automatic, for: .tabBar)
            // Results and the standings, behind a RESULTS | STANDINGS switch.
            ResultsHubView(page: $resultsPage)
                .tabItem { Image(systemName: "trophy").environment(\.symbolVariants, .none).accessibilityLabel("Results") }
                .tag(Tab.results)
                .toolbar(docked ? .hidden : .automatic, for: .tabBar)
            GamesView(model: games)
                .tabItem { Image(systemName: "gamecontroller").environment(\.symbolVariants, .none).accessibilityLabel("Games") }
                .tag(Tab.games)
                .toolbar(docked ? .hidden : .automatic, for: .tabBar)
            ChatView()
                .tabItem { Image(systemName: "bubble.left.and.bubble.right").environment(\.symbolVariants, .none).accessibilityLabel("Paddock") }
                .badge(chatBadge.unread)
                .tag(Tab.paddock)
                .toolbar(docked ? .hidden : .automatic, for: .tabBar)
            NewsView()
                .tabItem { Image(systemName: "newspaper").environment(\.symbolVariants, .none).accessibilityLabel("News") }
                .tag(Tab.news)
                .toolbar(docked ? .hidden : .automatic, for: .tabBar)
        }
        .tint(Theme.accent)
        .onHalves($halves)
        .overlay {
            // in the side strip under the status bar, where the system bar stood
            if docked {
                DuoDock(selection: $selection, items: [
                    .init(tag: Tab.countdown, symbol: "flag.checkered", name: "Countdown"),
                    .init(tag: Tab.results, symbol: "trophy", name: "Results"),
                    .init(tag: Tab.games, symbol: "gamecontroller", name: "Games"),
                    .init(tag: Tab.paddock, symbol: "bubble.left.and.bubble.right", name: "Paddock"),
                    .init(tag: Tab.news, symbol: "newspaper", name: "News"),
                ], unread: chatBadge.unread, privateUnread: chatBadge.unreadDMs > 0)
                .padding(.top, 104)
                .padding(.bottom, 24)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .ignoresSafeArea()
            }
        }
        // No scroll bars anywhere (inherited by every scroll view and sheet).
        .scrollIndicators(.hidden)
        #if DEBUG
        .overlay { if let id = UserDefaults.standard.string(forKey: "DesignLab") { DesignLab(id: id) } }
        #endif
        .overlay {
            if showIntro {
                IntroView { showIntro = false }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task { await games.load() }
        .task { await loadChampion() }
        .environment(\.champion, champion)
        .fullScreenCover(isPresented: $showChampion) {
            if let champion {
                ChampionMoment(champion: champion) {
                    selection = Tab.results
                    resultsPage = .standings
                }
            }
        }
        .environment(\.openProfile, OpenProfileAction { profile = $0 })
        .sheet(item: $profile) { target in
            ProfileSheet(target: target)
                .environment(\.openProfile, OpenProfileAction { profile = $0 })
        }
        .sheet(isPresented: $showNotificationPrompt) {
            NotificationPrompt { showNotificationPrompt = false }
                .presentationDetents([.medium])
                .presentationBackground(Theme.background)
        }
        .task {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "ProvisionalPush") { await NotificationManager.provisionalPushCheck() }
            #endif
            // First launch: ask for notifications once the app has settled.
            guard !Self.designLabOpen, await NotificationManager.shouldPrompt() else { return }
            try? await Task.sleep(for: .seconds(2.5))
            showNotificationPrompt = true
        }
        .onAppear {
            chatBadge.start()
            PushSync.start()
            // APNs: CloudKit's chat pushes, and our server's announcements
            // (the device token goes to the server in the app delegate).
            UIApplication.shared.registerForRemoteNotifications()
        }
        // teamradio://countdown|results|games|standings|paddock|news
        .onOpenURL { url in
            let map = ["countdown": Tab.countdown, "results": Tab.results, "standings": Tab.results,
                       "games": Tab.games, "paddock": Tab.paddock, "news": Tab.news]
            let host = (url.host ?? "").lowercased()
            if let tab = map[host] {
                selection = tab
            }
            if host == "standings" { resultsPage = .standings }
            if host == "results" { resultsPage = .results }
        }
        .onChange(of: selection) { _, tab in
            if tab == Tab.paddock {
                chatBadge.markRead()
                withAnimation(.easeOut(duration: 0.2)) { showMessageToast = false }
            }
        }
        .onChange(of: chatBadge.unread) { old, new in
            guard new > old, selection != Tab.paddock else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showMessageToast = true }
            toastDismissTask?.cancel()
            toastDismissTask = Task {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.35)) { showMessageToast = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPaddockMessages)) { _ in
            selection = Tab.paddock
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPaddockRoom)) { _ in
            selection = Tab.paddock
        }
        // The badge is blue for room chatter, red as soon as a private message waits.
        .onChange(of: chatBadge.unread) { _, _ in TabBarBadge.tint(private: chatBadge.unreadDMs > 0) }
        .onChange(of: chatBadge.unreadDMs) { _, _ in TabBarBadge.tint(private: chatBadge.unreadDMs > 0) }
        .overlay(alignment: .bottom) {
            if showMessageToast && !showIntro && !Self.designLabOpen {
                MessageToast(sender: chatBadge.latestSender, text: chatBadge.latestText, isPrivate: chatBadge.latestIsPrivate) {
                    selection = Tab.paddock
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
                // the title can be settled while the app sits in the background
                Task { await loadChampion() }
            } else {
                chatBadge.stop()
            }
        }
    }

    /// Checks the title; the first time it's settled, the title moment shows
    /// (once a season; not over the first-launch prompt or in spoiler mode).
    private func loadChampion() async {
        // launch and becoming active both ask; one check at a time
        guard !Self.designLabOpen, !checkingChampion else { return }
        checkingChampion = true
        defer { checkingChampion = false }
        champion = await Championship.load()
        guard let champion, !showChampion, Championship.shouldCelebrate(champion),
              await !NotificationManager.shouldPrompt() else { return }
        try? await Task.sleep(for: .seconds(1))
        guard !showNotificationPrompt else { return }
        Championship.celebrated(champion)
        showChampion = true
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
