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
    private var playbackGeneration: UInt64 = 0
    private let scheduleQueue = DispatchQueue(label: "com.juliocezar.zensounds.loopingplayer")

    init(url: URL) throws {
        file = try AVAudioFile(forReading: url)
    }

    func start() {
        scheduleQueue.sync {
            guard !isLooping else {
                if !node.isPlaying {
                    node.play()
                }
                return
            }

            isLooping = true
            playbackGeneration &+= 1
            let generation = playbackGeneration

            // Queue two complete file segments before starting the node. While the second segment
            // is playing, completion of the first schedules the next one, keeping long MP3 loops
            // continuous without loading the file into an in-memory PCM buffer.
            scheduleNextLocked(generation: generation)
            scheduleNextLocked(generation: generation)
            node.play()
        }
    }

    func pause() {
        scheduleQueue.sync {
            guard isLooping, node.isPlaying else { return }
            node.pause()
        }
    }

    func resume() {
        scheduleQueue.sync {
            guard isLooping, !node.isPlaying else { return }
            node.play()
        }
    }

    func stop() {
        scheduleQueue.sync {
            guard isLooping || node.isPlaying else { return }
            isLooping = false
            playbackGeneration &+= 1
            node.stop()
        }
    }

    private func scheduleNextLocked(generation: UInt64) {
        guard isLooping, generation == playbackGeneration else { return }
        file.framePosition = 0
        node.scheduleFile(file, at: nil, completionCallbackType: .dataRendered) { [weak self] _ in
            guard let self else { return }
            self.scheduleQueue.async { [weak self] in
                self?.scheduleNextLocked(generation: generation)
            }
        }
    }
}
