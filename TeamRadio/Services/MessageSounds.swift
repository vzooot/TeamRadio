import AudioToolbox
import UIKit

/// Team-radio feedback: a pit-wall "radio call" when something arrives, a
/// key-up chirp when you send. Bundled CAFs (also used by the pushes); they
/// respect the ringer switch.
enum MessageSounds {
    static let receivedFile = "radio-call.caf"
    static let sentFile = "radio-key.caf"

    private static let received: SystemSoundID = load(receivedFile, fallback: 1007)
    private static let sent: SystemSoundID = load(sentFile, fallback: 1004)

    private static func load(_ file: String, fallback: SystemSoundID) -> SystemSoundID {
        guard let url = Bundle.main.url(forResource: file, withExtension: nil) else { return fallback }
        var id: SystemSoundID = 0
        return AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError ? id : fallback
    }

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
    /// Jump to the Paddock room (room notification tap).
    static let openPaddockRoom = Notification.Name("openPaddockRoom")
}
