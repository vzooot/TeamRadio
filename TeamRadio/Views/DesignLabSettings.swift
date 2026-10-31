#if DEBUG
import SwiftUI

// Settings screen drafts (`-DesignLab settingsA|settingsB|settingsC`), and
// the countdown card without the pin button (`-DesignLab settingsCard`).
// Everything here is set once and then just happens every race weekend.

struct SettingsDraft: View {
    let style: String

    @State private var notifications = true
    @State private var sessions = true
    @State private var picks = true
    @State private var news = true
    @State private var chat = false
    @State private var countdown = true
    @State private var hours = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                switch style {
                case "B": bigSwitches
                case "C": preview
                default: grouped
                }
                about
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                TrioSlashes(height: 24)
                Text("SETTINGS").font(.f1(30).italic()).foregroundStyle(Theme.chromeText)
            }
            Spacer()
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.dimText)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.06)))
        }
        .padding(.top, 14)
    }

    // MARK: A · grouped cards, like the rest of the app

    private var grouped: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("NOTIFICATIONS") {
                row("bell.badge.fill", "NOTIFICATIONS", "Everything Team Radio sends you", $notifications, master: true)
                divider
                row("flag.checkered", "SESSION ALERTS", "15 minutes before every session", $sessions).dim(!notifications)
                divider
                row("gamecontroller.fill", "PICKS REMINDERS", "Before your picks lock", $picks).dim(!notifications)
                divider
                row("megaphone.fill", "TEAM RADIO NEWS", "Picks are open, results are in", $news).dim(!notifications)
                divider
                row("bubble.left.and.bubble.right.fill", "PADDOCK CHAT", "New messages in the room", $chat).dim(!notifications)
            }
            section("LOCK SCREEN COUNTDOWN") {
                row("lock.iphone", "AUTOMATIC COUNTDOWN", "On your Lock Screen before every session, all season", $countdown, master: true)
                divider
                hoursPicker.dim(!countdown)
            }
        }
    }

    // MARK: B · two big switches, the details underneath

    private var bigSwitches: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                bigTile("bell.badge.fill", "NOTIFICATIONS", notifications ? "ON" : "OFF", $notifications, Theme.accent)
                bigTile("lock.iphone", "LOCK SCREEN\nCOUNTDOWN", countdown ? "\(hours) H BEFORE" : "OFF", $countdown, Theme.live)
            }
            section("COUNTDOWN STARTS") { hoursPicker.dim(!countdown) }
            section("NOTIFY ME ABOUT") {
                row("flag.checkered", "SESSION ALERTS", "15 minutes before every session", $sessions).dim(!notifications)
                divider
                row("gamecontroller.fill", "PICKS REMINDERS", "Before your picks lock", $picks).dim(!notifications)
                divider
                row("megaphone.fill", "TEAM RADIO NEWS", "Picks are open, results are in", $news).dim(!notifications)
                divider
                row("bubble.left.and.bubble.right.fill", "PADDOCK CHAT", "New messages in the room", $chat).dim(!notifications)
            }
        }
    }

    private func bigTile(_ icon: String, _ title: String, _ state: String, _ on: Binding<Bool>, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).font(.system(size: 26)).foregroundStyle(on.wrappedValue ? tint : Theme.dimText)
                Spacer()
                Toggle("", isOn: on).labelsHidden().tint(tint)
            }
            Text(title).font(.f1(15).italic()).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            Text(state).font(.f1(12, weight: .heavy)).tracking(1.5).foregroundStyle(on.wrappedValue ? tint : Theme.dimText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(on.wrappedValue ? tint.opacity(0.6) : Theme.cardStroke, lineWidth: 1.5))
        .shadow(color: on.wrappedValue ? tint.opacity(0.35) : .clear, radius: 12)
    }

    // MARK: C · a live preview of the Lock Screen countdown

    private var preview: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("LOCK SCREEN COUNTDOWN") {
                row("lock.iphone", "AUTOMATIC COUNTDOWN", "Appears by itself before every session", $countdown, master: true)
                VStack(spacing: 6) {
                    // what it will look like on the Lock Screen
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("🇲🇽 MEXICO CITY").font(.system(size: 14, weight: .heavy))
                            Text("PRACTICE 2").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accent)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(hours):00:00").font(.system(size: 26, weight: .heavy).monospacedDigit())
                            Text("TO GREEN LIGHT").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(Theme.dimText)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.black))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.12)))
                    Text("Shows up \(hours) hours before each session")
                        .font(.system(size: 12)).foregroundStyle(Theme.dimText)
                }
                .padding(.horizontal, 14).padding(.bottom, 6)
                .dim(!countdown)
                hoursPicker.dim(!countdown)
            }
            section("NOTIFICATIONS") {
                row("bell.badge.fill", "NOTIFICATIONS", "Everything Team Radio sends you", $notifications, master: true)
                divider
                row("flag.checkered", "SESSION ALERTS", "15 minutes before every session", $sessions).dim(!notifications)
                divider
                row("gamecontroller.fill", "PICKS REMINDERS", "Before your picks lock", $picks).dim(!notifications)
                divider
                row("megaphone.fill", "TEAM RADIO NEWS", "Picks are open, results are in", $news).dim(!notifications)
                divider
                row("bubble.left.and.bubble.right.fill", "PADDOCK CHAT", "New messages in the room", $chat).dim(!notifications)
            }
        }
    }

    // MARK: Shared pieces

    private var hoursPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("START THE COUNTDOWN").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
            HStack(spacing: 6) {
                ForEach([1, 2, 4, 8], id: \.self) { h in
                    Button { hours = h } label: { NeonChip(title: "\(h) H BEFORE", tint: Theme.accent, selected: hours == h) }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
    }

    private var about: some View {
        section("ABOUT") {
            link("info.circle", "About Team Radio")
            divider
            link("hand.raised", "Privacy")
            divider
            link("star", "Rate Team Radio")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.accent).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke, lineWidth: 1))
        }
    }

    private func row(_ icon: String, _ title: String, _ sub: String, _ on: Binding<Bool>, master: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: master ? 20 : 17))
                .foregroundStyle(on.wrappedValue ? Theme.accent : Theme.dimText)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.f1(master ? 15 : 14).italic()).foregroundStyle(.white)
                Text(sub).font(.system(size: 12)).foregroundStyle(Theme.dimText)
            }
            Spacer()
            Toggle("", isOn: on).labelsHidden().tint(Theme.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func link(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Theme.accent).frame(width: 30)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.dimText)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, 56)
    }
}

/// The countdown card's bottom line once the pin button is gone: what will
/// happen by itself, with a way into Settings.
struct SettingsCardDraft: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BOTTOM OF THE COUNTDOWN CARD").font(.f1(11, weight: .heavy)).tracking(2).foregroundStyle(Theme.accent)
            Group {
                Text("NOW").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                HStack(spacing: 6) {
                    Image(systemName: "pin.fill").font(.system(size: 11, weight: .bold))
                    Text("PIN FP2 TO LOCK SCREEN").font(.f1(12, weight: .bold)).tracking(1)
                }
                .foregroundStyle(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 9)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1))
            }
            Group {
                Text("NEW · COUNTDOWN ON").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                status("lock.iphone", "ON YOUR LOCK SCREEN 8 H BEFORE", Theme.accent)
                Text("NEW · COUNTDOWN OFF").font(.f1(10, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.dimText)
                status("lock.slash", "LOCK SCREEN COUNTDOWN OFF", Theme.dimText)
            }
            Text("Tapping the line opens Settings.").font(.system(size: 12)).foregroundStyle(Theme.dimText)
            Spacer()
        }
        .padding(16)
        .padding(.top, 20)
    }

    private func status(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
            Text(text).font(.f1(12, weight: .bold)).tracking(1)
            Spacer()
            Image(systemName: "gearshape.fill").font(.system(size: 12))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.08)))
    }
}

private extension View {
    func dim(_ off: Bool) -> some View { opacity(off ? 0.4 : 1).allowsHitTesting(!off) }
}
#endif
