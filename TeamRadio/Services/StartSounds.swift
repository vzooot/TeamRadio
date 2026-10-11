import AVFoundation

/// Short synthesized tones for Lights Out: a beep for each light, a low
/// buzz for a jump start, and the app's radio key click on a good start.
/// Ambient session, so the silent switch mutes them like any game sound.
@MainActor
final class StartSounds {
    static let shared = StartSounds()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var click: AVAudioPlayer?
    private var started = false

    private func start() {
        guard !started else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
        if let url = Bundle.main.url(forResource: "radio-key", withExtension: "caf") {
            click = try? AVAudioPlayer(contentsOf: url)
            click?.prepareToPlay()
        }
        started = true
    }

    /// Call when the game opens so the first beep has no delay.
    func prepare() { start() }

    /// One light coming on.
    func beep() { tone(frequency: 880, duration: 0.11, volume: 0.35) }

    /// Jump start.
    func buzz() { tone(frequency: 140, duration: 0.35, volume: 0.5, square: true) }

    /// Reaction recorded.
    func radioClick() {
        start()
        click?.currentTime = 0
        click?.play()
    }

    private func tone(frequency: Double, duration: Double, volume: Float, square: Bool = false) {
        start()
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        let fade = Int(format.sampleRate * 0.01)
        for i in 0..<Int(frames) {
            let phase = 2 * Double.pi * frequency * Double(i) / format.sampleRate
            var v = Float(square ? (sin(phase) >= 0 ? 0.6 : -0.6) : sin(phase))
            // short fade in/out so the beep doesn't click
            let edge = min(i, Int(frames) - 1 - i)
            if edge < fade { v *= Float(edge) / Float(fade) }
            data[i] = v * volume
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
