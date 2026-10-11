import AVFoundation

/// Gapless infinite loop of a single audio file on one `AVAudioPlayerNode`, using the
/// Apple-recommended pattern of keeping two file-length segments queued ahead of playback
/// (re-scheduling from the start as each segment finishes rendering) rather than loading the
/// whole file into an in-memory buffer — important here since some bundled sounds (e.g. the
/// thunder loop) are over ten minutes long.
final class LoopingPlayer {
    let node = AVAudioPlayerNode()
    var format: AVAudioFormat { file.processingFormat }

    private let file: AVAudioFile
    private var isLooping = false
    private let scheduleQueue = DispatchQueue(label: "com.juliocezar.zensounds.loopingplayer")

    init(url: URL) throws {
        file = try AVAudioFile(forReading: url)
    }

    func start() {
        isLooping = true
        scheduleQueue.async { [weak self] in
            self?.scheduleNextLocked()
            self?.scheduleNextLocked()
        }
        node.play()
    }

    func pause() { node.pause() }
    func resume() { node.play() }

    func stop() {
        isLooping = false
        node.stop()
    }

    private func scheduleNextLocked() {
        guard isLooping else { return }
        file.framePosition = 0
        node.scheduleFile(file, at: nil, completionCallbackType: .dataRendered) { [weak self] _ in
            self?.scheduleQueue.async { self?.scheduleNextLocked() }
        }
    }
}
