import AVFoundation

/// The arcade games' sounds: a beep for each light, a soft "uh-oh" for a
/// jump start, a soft pop for each Reaction Wall hit, the radio key click
/// on a better run, "oh-oh" on a worse one, and the five-lights fanfare on a
/// personal best.
/// Ambient session, so the silent switch mutes them like any game sound.
@MainActor
final class StartSounds {
    static let shared = StartSounds()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var click: AVAudioPlayer?
    private var fanfare: AVAudioPlayer?
    private var ohOhSound: AVAudioPlayer?
    /// Taps go through the engine on their own node: no player start-up
    /// delay, and a new tap cuts the last one off.
    private let tapPlayer = AVAudioPlayerNode()
    private var tapBuffer: AVAudioPCMBuffer?
    private var started = false

    private func start() {
        guard !started else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.attach(tapPlayer)
        engine.connect(tapPlayer, to: engine.mainMixerNode, format: format)
        if let url = Bundle.main.url(forResource: "tap", withExtension: "caf"),
           let file = try? AVAudioFile(forReading: url),
           let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
           (try? file.read(into: buffer)) != nil {
            tapBuffer = buffer
        }
        try? engine.start()
        if let url = Bundle.main.url(forResource: "radio-key", withExtension: "caf") {
            click = try? AVAudioPlayer(contentsOf: url)
            click?.prepareToPlay()
        }
        if let url = Bundle.main.url(forResource: "personal-best", withExtension: "caf") {
            fanfare = try? AVAudioPlayer(contentsOf: url)
            fanfare?.prepareToPlay()
        }
        if let url = Bundle.main.url(forResource: "oh-oh", withExtension: "caf") {
            ohOhSound = try? AVAudioPlayer(contentsOf: url)
            ohOhSound?.prepareToPlay()
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

    /// A Reaction Wall hit: a soft little bubble pop, like a rubber button
    /// (approved, build/mockups/sounds/wall/tap-soft-2-bubble.wav).
    func tap() {
        start()
        guard let tapBuffer else { return }
        tapPlayer.scheduleBuffer(tapBuffer, at: nil, options: .interrupts, completionHandler: nil)
        if !tapPlayer.isPlaying { tapPlayer.play() }
    }

    /// A run that beat neither your best nor your week: a cute "oh-oh", two
    /// kalimba notes, the second bending down (approved,
    /// build/mockups/sounds/wall/oh-oh-cute-1-kalimba.wav).
    func ohOh() {
        start()
        ohOhSound?.currentTime = 0
        ohOhSound?.play()
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
