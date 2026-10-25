import AVFoundation

/// Short synthesized tones for Lights Out: a beep for each light, a soft
/// two-note "uh-oh" for a jump start, and the app's radio key click on a good start.
/// Ambient session, so the silent switch mutes them like any game sound.
@MainActor
final class StartSounds {
    static let shared = StartSounds()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var click: AVAudioPlayer?
    private var fanfare: AVAudioPlayer?
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
        if let url = Bundle.main.url(forResource: "personal-best", withExtension: "caf") {
            fanfare = try? AVAudioPlayer(contentsOf: url)
            fanfare?.prepareToPlay()
        }
        started = true
    }

    /// Call when the game opens so the first beep has no delay.
    func prepare() { start() }

    /// One light coming on.
    func beep() { tone(frequency: 880, duration: 0.11, volume: 0.35) }

    /// Jump start: two gentle falling notes, a friendly "uh-oh".
    func buzz() {
        start()
        let notes: [(frequency: Double, duration: Double)] = [(659.3, 0.13), (493.9, 0.28)]
        let total = notes.reduce(0) { $0 + Int(format.sampleRate * $1.duration) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(total)
        var offset = 0
        for note in notes {
            let frames = Int(format.sampleRate * note.duration)
            for i in 0..<frames {
                let t = Double(i) / format.sampleRate
                // soft attack, exponential decay, a touch of the octave for warmth
                let envelope = min(1, t / 0.012) * exp(-t * 7)
                let phase = 2 * Double.pi * note.frequency * t
                data[offset + i] = Float((sin(phase) + 0.25 * sin(2 * phase)) * envelope * 0.3)
            }
            offset += frames
        }
        let fade = Int(format.sampleRate * 0.008)
        for i in 0..<fade { data[total - 1 - i] *= Float(i) / Float(fade) }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    /// A personal best, in either game: the five start lights as five
    /// rising beeps, resolving into a warm chord (approved take 2,
    /// build/mockups/sounds/highscore/five-lights-2.wav).
    func personalBest() {
        start()
        fanfare?.currentTime = 0
        fanfare?.play()
    }

    /// Reaction recorded.
    func radioClick() {
        start()
        click?.currentTime = 0
        click?.play()
    }

    private func tone(frequency: Double, duration: Double, volume: Float) {
        start()
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        let fade = Int(format.sampleRate * 0.01)
        for i in 0..<Int(frames) {
            let phase = 2 * Double.pi * frequency * Double(i) / format.sampleRate
            var v = Float(sin(phase))
            // short fade in/out so the beep doesn't click
            let edge = min(i, Int(frames) - 1 - i)
            if edge < fade { v *= Float(edge) / Float(fade) }
            data[i] = v * volume
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
