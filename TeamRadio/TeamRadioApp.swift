import SwiftUI

@main
struct TeamRadioApp: App {
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
        .overlay(alignment: .bottom) {
            if showMessageToast {
                MessageToast(sender: chatBadge.latestSender, text: chatBadge.latestText) {
                    selection = 3
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(sender.isEmpty ? "PADDOCK" : sender.uppercased())
                        .font(.f1(12).italic())
                        .foregroundStyle(Theme.accent)
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
                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 14, y: 4)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 340)
    }
}
