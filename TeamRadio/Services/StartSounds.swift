import AVFoundation

/// Short synthesized tones for Lights Out: a beep for each light, a soft
/// two-note "uh-oh" for a jump start, and the app's radio key click on a good start.
/// Ambient session, so the silent switch mutes them like any game sound.
@MainActor
final class StartSounds {
    static let shared = StartSounds()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    /// Dial ticks get their own voice so a new tick can cut off the last.
    private let tickPlayer = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var click: AVAudioPlayer?
    private var ticks: [AVAudioPCMBuffer] = []
    private var started = false

    private func start() {
        guard !started else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.attach(tickPlayer)
        engine.connect(tickPlayer, to: engine.mainMixerNode, format: format)
        ticks = (0..<4).compactMap { detentClick(variant: $0) }
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

    /// A dial detent, `volume` 0…1: one of a few slightly different
    /// pre-made clicks, each cutting off the one before.
    func tick(volume: Float = 1) {
        start()
        guard let buffer = ticks.randomElement() else { return }
        tickPlayer.volume = volume
        tickPlayer.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !tickPlayer.isPlaying { tickPlayer.play() }
    }

    /// A mechanical detent, about 30 ms: the contact snap (high-passed
    /// noise), the plastic ringing (a damped tone), a low thump of body,
    /// and the spring settling back a moment later. Variants shift the
    /// pitch and timing a touch so repeated ticks sound alive.
    private func detentClick(variant: Int) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * 0.032)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SystemRandomNumberGenerator()
        let ring = 1900 + Double(variant) * 140      // plastic resonance
        let thump = 160 + Double(variant) * 12       // body
        let rebound = 0.010 + Double(variant) * 0.0012
        var previousNoise = 0.0
        var samples = [Double](repeating: 0, count: Int(frames))
        for i in 0..<Int(frames) {
            let t = Double(i) / format.sampleRate
            let noise = Double.random(in: -1...1, using: &rng)
            let snap = (noise - previousNoise) * exp(-t * 2600) * 0.9     // high-passed burst
            previousNoise = noise
            let ringing = sin(2 * .pi * ring * t) * exp(-t * 420) * 0.32
            let body = sin(2 * .pi * thump * t) * exp(-t * 240) * 0.3
            var settle = 0.0
            if t > rebound {
                let u = t - rebound
                settle = Double.random(in: -1...1, using: &rng) * exp(-u * 3200) * 0.28
                    + sin(2 * .pi * ring * 1.3 * u) * exp(-u * 600) * 0.1
            }
            samples[i] = snap + ringing + body + settle
        }
        let peak = samples.map(abs).max() ?? 1
        for i in samples.indices {
            // a hair of fade at both ends so it never clicks digitally
            let edge = min(Double(i), Double(samples.count - 1 - i)) / 40
            data[i] = Float(samples[i] / peak * 0.42 * min(1, edge))
        }
        return buffer
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
