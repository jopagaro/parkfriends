import AVFoundation

/// Procedural chip-sound synth for EarthBound-style UI audio: square-wave
/// text blips (pitched per speaker) and the rapid HP-odometer tick. Buffers
/// are rendered once at launch — no audio assets involved.
@MainActor
final class SoundFX {
    static let shared = SoundFX()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private let sampleRate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                            channels: 1)!

    // voice (0 low / 1 mid / 2 high) × two alternating pitches each,
    // so sustained typing warbles like the SNES voices did.
    private var blips: [[AVAudioPCMBuffer]] = []
    private var blipFlip = [false, false, false]
    private var tickDown: AVAudioPCMBuffer?
    private var tickUp: AVAudioPCMBuffer?

    private init() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.9

        let voices: [Double] = [392, 540, 718]
        blips = voices.map { f in
            [square(freq: f, dur: 0.040, amp: 0.16),
             square(freq: f * 1.07, dur: 0.040, amp: 0.16)]
        }
        tickDown = square(freq: 980, dur: 0.022, amp: 0.07)
        tickUp = square(freq: 1240, dur: 0.022, amp: 0.07)
        startEngine()
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            players.forEach { $0.play() }
        } catch {
            // Audio unavailable (e.g. stripped-down simulator) — stay silent.
        }
    }

    private func square(freq: Double, dur: Double, amp: Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(dur * sampleRate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let data = buf.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let phase = (t * freq).truncatingRemainder(dividingBy: 1)
            let sq: Float = phase < 0.5 ? 1 : -1
            let env = Float(1 - Double(i) / Double(frames))
            data[i] = sq * amp * env * env
        }
        return buf
    }

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer else { return }
        startEngine()
        guard engine.isRunning else { return }
        let p = players[next]
        next = (next + 1) % players.count
        p.scheduleBuffer(buffer, completionHandler: nil)
        if !p.isPlaying { p.play() }
    }

    /// Short text blip; voice 0 = low, 1 = mid (battle narrator), 2 = high.
    func textBlip(voice: Int) {
        let v = max(0, min(2, voice))
        blipFlip[v].toggle()
        play(blips[v][blipFlip[v] ? 0 : 1])
    }

    /// One step of the rolling HP odometer.
    func hpTick(down: Bool) { play(down ? tickDown : tickUp) }

    /// Stable blip pitch for a speaker name (same speaker, same voice every run).
    nonisolated static func voice(for speaker: String) -> Int {
        if speaker == "You" { return 2 }
        var h: UInt64 = 1_469_598_103_934_665_603
        for b in speaker.utf8 { h = (h ^ UInt64(b)) &* 1_099_511_628_211 }
        return Int(h % 3)
    }
}
