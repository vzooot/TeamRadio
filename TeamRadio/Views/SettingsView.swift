import SwiftUI
import UIKit
import UserNotifications

/// Settings (approved draft C, build/mockups/settings-drafts.png), opened
/// with the steering-wheel button: the automatic Lock Screen countdown with
/// a preview of what will appear, every kind of notification under one main
/// switch, and About. Set once; then every race weekend just happens.
struct SettingsView: View {
    let season: [Race]

    @Environment(\.dismiss) private var dismiss
    @State private var countdown = PushSync.countdownOn
    @State private var hours = PushSync.countdownHours
    @State private var notifications = AppSettings.notificationsOn
    @State private var sessions = NotificationManager.sessionAlertsOn
    @State private var picks = AppSettings.picksReminders
    @State private var news = AppSettings.news
    @State private var chat = ChatService.roomPushEnabled
    @State private var blocked = false
    @State private var liveActivitiesAllowed = LiveActivityManager.allowedByIOS
    @State private var showAbout = false
    @State private var next: (race: Race, session: WeekendSession)?

    private static let privacy = URL(string: "https://github.com/vzooot/TeamRadio/blob/main/PRIVACY.md")!
    private static let review = URL(string: "https://apps.apple.com/app/id6804406860?action=write-review")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                countdownSection
                notificationsSection
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showAbout) { AboutView() }
        .task {
            if let race = try? await F1API.nextRace(),
               let session = race.sessions.first(where: { $0.date > .now }) {
                next = (race, session)
            }
            // iOS may have notifications off for the app altogether.
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            blocked = status == .denied
            liveActivitiesAllowed = LiveActivityManager.allowedByIOS
        }
        .onChange(of: countdown) { _, on in
            PushSync.countdownOn = on
            // off clears the Lock Screen now; on shows the running countdown now
            if on { Task { await LiveActivityManager.ensureCountdown() } } else { LiveActivityManager.endAll() }
            changed()
        }
        .onChange(of: hours) { _, value in
            PushSync.countdownHours = value
            Task { await LiveActivityManager.ensureCountdown() }
            changed()
        }
        .onChange(of: notifications) { old, on in
            guard old != on else { return }
            Task {
                let result = await AppSettings.setNotifications(on)
                if result != on {
                    notifications = result
                    blocked = true
                }
                changed()
            }
        }
        .onChange(of: sessions) { old, on in
            guard old != on else { return }
            Task {
                let result = await NotificationManager.setEnabled(on, season: season)
                if result != on { sessions = result }
            }
        }
        .onChange(of: picks) { _, on in
            AppSettings.picksReminders = on
            if !on { Task { await GameReminders.removeAll() } }
        }
        .onChange(of: news) { _, on in
            AppSettings.news = on
            Task { await PushSync.syncAnnouncements() }
        }
        .onChange(of: chat) { _, on in
            ChatService.roomPushEnabled = on
            Task { await AppSettings.syncChatPushes() }
        }
    }

    private func changed() {
        NotificationCenter.default.post(name: AppSettings.didChange, object: nil)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                TrioSlashes(height: 24)
                Text("SETTINGS").font(.f1(30).italic()).foregroundStyle(Theme.chromeText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.dimText)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, 18)
    }

    // MARK: Lock Screen countdown

    private var countdownSection: some View {
        section("LOCK SCREEN COUNTDOWN") {
            row("lock.iphone", "AUTOMATIC COUNTDOWN", "Appears by itself before every session, all season", $countdown, master: true)
            if countdown && !liveActivitiesAllowed {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Text("Live Activities are off for Team Radio in iPhone Settings, so nothing can appear. Tap to turn them on.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.live)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 6) {
                lockScreenPreview
                Text("Shows up \(hours) \(hours == 1 ? "hour" : "hours") before each session")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dimText)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
            .dimmed(!countdown)
            hoursPicker.dimmed(!countdown)
        }
    }

    /// What will appear on the Lock Screen, for the next session.
    private var lockScreenPreview: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(next.map { "\(Flags.emoji(for: $0.race.circuit.location.country)) \($0.race.raceName.uppercased())" } ?? "🏁 NEXT RACE")
                    .font(.system(size: 14, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(next?.session.kind.rawValue.uppercased() ?? "PRACTICE 1")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(hours):00:00").font(.system(size: 26, weight: .heavy).monospacedDigit())
                Text("TO GREEN LIGHT").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(Theme.dimText)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.12)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lock Screen preview: \(hours) hours to green light")
    }

    private var hoursPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("START THE COUNTDOWN").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
            HStack(spacing: 6) {
                ForEach(PushSync.hourChoices, id: \.self) { h in
                    Button { hours = h } label: {
                        NeonChip(title: "\(h) H BEFORE", tint: Theme.accent, selected: hours == h)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        section("NOTIFICATIONS") {
            row("bell.badge.fill", "NOTIFICATIONS", "Everything Team Radio sends you", $notifications, master: true)
            if blocked {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Notifications are off for Team Radio in iPhone Settings. Tap to turn them on.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.live)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                }
                .buttonStyle(.plain)
            }
            Group {
                divider
                row("flag.checkered", "SESSION ALERTS", "15 minutes before every session", $sessions)
                divider
                row("gamecontroller.fill", "PICKS REMINDERS", "Before your picks lock", $picks)
                divider
                row("megaphone.fill", "TEAM RADIO NEWS", "Picks are open, results are in", $news)
                divider
                row("bubble.left.and.bubble.right.fill", "PADDOCK CHAT", "New messages in the room", $chat)
            }
            .dimmed(!notifications)
        }
    }

    // MARK: About

    private var aboutSection: some View {
        section("ABOUT") {
            Button { showAbout = true } label: { link("info.circle", "About Team Radio") }
                .buttonStyle(.plain)
            divider
            Link(destination: Self.privacy) { link("hand.raised", "Privacy") }
            divider
            Link(destination: Self.review) { link("star", "Rate Team Radio") }
        }
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.accent).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke, lineWidth: 1))
        }
    }

    private func row(_ icon: String, _ title: String, _ subtitle: String, _ on: Binding<Bool>, master: Bool = false) -> some View {
        Toggle(isOn: on) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: master ? 20 : 17))
                    .foregroundStyle(on.wrappedValue ? Theme.accent : Theme.dimText)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.f1(master ? 15 : 14).italic()).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.dimText)
                }
            }
        }
        .tint(Theme.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func link(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Theme.accent).frame(width: 30)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.dimText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, 56)
    }
}

private extension View {
    /// A setting that has no effect while its main switch is off.
    func dimmed(_ off: Bool) -> some View {
        opacity(off ? 0.4 : 1).allowsHitTesting(!off)
    }
}
