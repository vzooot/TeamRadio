import AudioToolbox
import UIKit

/// Messenger-style feedback: a pop when something arrives, a swoosh when you send.
/// System sounds, so nothing to bundle; they respect the ringer switch.
enum MessageSounds {
    private static let received: SystemSoundID = 1007   // tri-tone
    private static let sent: SystemSoundID = 1004       // swoosh

    static var enabled: Bool {
        get { !UserDefaults.standard.bool(forKey: "chatSoundsOff") }
        set { UserDefaults.standard.set(!newValue, forKey: "chatSoundsOff") }
    }

    static func playReceived() {
        guard enabled, UIApplication.shared.applicationState == .active else { return }
        AudioServicesPlaySystemSound(received)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func playSent() {
        guard enabled else { return }
        AudioServicesPlaySystemSound(sent)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

extension Notification.Name {
    /// A CloudKit push arrived while the app was in front — recount now.
    static let chatPushReceived = Notification.Name("chatPushReceived")
    /// Jump to the Paddock's Messages pane (toast tap, notification tap).
    static let openPaddockMessages = Notification.Name("openPaddockMessages")
}
