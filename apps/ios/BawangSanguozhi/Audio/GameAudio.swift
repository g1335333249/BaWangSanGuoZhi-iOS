import AVFoundation
import Foundation

/// Plays PCM produced by the same FM/PSG drain as the desktop game core.
final class GameAudio {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000,
                                       channels: 2)!
    private let lock = NSLock()
    private var pending = 0

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            player.play()
        } catch {
            // Video and input remain usable when the host has no audio device.
        }
    }

    func stop() {
        player.stop()
        engine.stop()
        lock.lock(); pending = 0; lock.unlock()
    }

    func append(_ pcm: Data) {
        guard engine.isRunning, pcm.count % 4 == 0 else { return }
        lock.lock()
        let room = pending < 5
        if room { pending += 1 }
        lock.unlock()
        guard room else { return }

        let count = pcm.count / 4
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                           frameCapacity: AVAudioFrameCount(count)),
              let channels = buffer.floatChannelData else {
            finished(); return
        }
        buffer.frameLength = AVAudioFrameCount(count)
        pcm.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for i in 0..<count {
                channels[0][i] = Float(samples[i * 2]) / 32768
                channels[1][i] = Float(samples[i * 2 + 1]) / 32768
            }
        }
        player.scheduleBuffer(buffer) { [weak self] in self?.finished() }
    }

    private func finished() {
        lock.lock(); pending = max(0, pending - 1); lock.unlock()
    }
}
