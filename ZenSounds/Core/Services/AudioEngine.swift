import AVFoundation
import MediaPlayer
import Combine
import UIKit

/// Native playback engine: one `AVAudioPlayerNode` per active layer on a single
/// `AVAudioEngine`, mixed via `mainMixerNode`. Replaces the Android app's Media3/ExoPlayer
/// `MediaSessionService` 1:1 in responsibility (single sound, mixes with per-layer volume,
/// timer with fade-out, system Now Playing/remote commands, interruptions, route changes) —
/// `AVAudioEngine` is the lighter-weight native fit here since there's no streaming/network
/// media involved, just bundled loops.
@MainActor
final class AudioEngine: ObservableObject {
    static let shared = AudioEngine()

    @Published private(set) var isPlaying = false
    @Published var masterVolume: Double = 1.0 {
        didSet { applyVolumes() }
    }
    @Published private(set) var activeSoundId: String?
    @Published private(set) var activeMix: SavedMix?
    @Published private(set) var layers: [MixLayer] = []
    @Published private(set) var timerDeadline: TimeInterval?
    @Published private(set) var timerDurationMinutes: Int?
    @Published var timerFadeSeconds: Double = TimerRules.defaultFadeSeconds
    @Published private(set) var timerRemaining: TimeInterval?
    @Published private(set) var playbackError: String?

    private let engine = AVAudioEngine()
    private var players: [String: LoopingPlayer] = [:]
    private var tickTask: Task<Void, Never>?

    var isActive: Bool { activeSoundId != nil || activeMix != nil }

    var displayTitle: String {
        if let mix = activeMix { return mix.name }
        if let soundId = activeSoundId, let sound = SoundCatalog.sound(id: soundId) {
            return NSLocalizedString(sound.titleKey, value: soundId, comment: "")
        }
        return "ZenSounds"
    }

    private init() {
        // AVAudioEngine only lazily realizes `outputNode` once something is connected to it.
        // Without this, `engine.start()` throws "inputNode != nullptr || outputNode != nullptr"
        // because nothing in the graph ever references the hardware output.
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
        configureAudioSession()
        configureRemoteCommands()
    }

    // MARK: - Single sound

    func play(soundId: String) {
        guard SoundCatalog.sound(id: soundId) != nil else { return }
        play(layers: [MixLayer(soundId: soundId, volume: SoundCatalog.sound(id: soundId)?.defaultVolume ?? 1)], mix: nil, singleSoundId: soundId)
    }

    /// Sequential browsing through the full sound catalog, matching the Android player's
    /// previous/next controls (only meaningful in single-sound mode).
    func playAdjacentSound(offset: Int) {
        guard let current = activeSoundId, let currentIndex = SoundCatalog.all.firstIndex(where: { $0.id == current }) else { return }
        let count = SoundCatalog.all.count
        let nextIndex = ((currentIndex + offset) % count + count) % count
        play(soundId: SoundCatalog.all[nextIndex].id)
    }

    // MARK: - Mix

    func playMix(_ mix: SavedMix) {
        play(layers: mix.layers, mix: mix, singleSoundId: nil)
    }

    func playAdHocMix(layers: [MixLayer]) {
        play(layers: layers, mix: nil, singleSoundId: nil)
    }

    func setLayerVolume(soundId: String, volume: Double) {
        guard let index = layers.firstIndex(where: { $0.soundId == soundId }) else { return }
        layers[index].volume = min(max(volume, 0), 1)
        applyVolumes()
    }

    /// Adds the currently-playing single sound as a new mix layer (the Android "use in mix" action).
    func addLayer(soundId: String) {
        guard !layers.contains(where: { $0.soundId == soundId }), layers.count < MixRules.maxLayers else { return }
        var newLayers = layers
        newLayers.append(MixLayer(soundId: soundId))
        play(layers: newLayers, mix: activeMix, singleSoundId: nil)
    }

    func removeLayer(soundId: String) {
        let newLayers = layers.filter { $0.soundId != soundId }
        if newLayers.isEmpty {
            stop()
        } else {
            play(layers: newLayers, mix: activeMix, singleSoundId: nil)
        }
    }

    private func play(layers newLayers: [MixLayer], mix: SavedMix?, singleSoundId: String?) {
        let normalized = MixRules.normalize(newLayers)
        guard !normalized.isEmpty else { return }

        // Reopening the exact same combination just updates metadata — keeps playback position,
        // matching the Android app's "no orphaned restart" behavior.
        if layers == normalized, isPlaying {
            activeMix = mix
            activeSoundId = singleSoundId
            updateNowPlaying()
            return
        }

        stopAllNodes()
        activeSoundId = singleSoundId
        activeMix = mix
        layers = normalized
        playbackError = nil
        startEngineIfNeeded()
        for layer in normalized {
            startLayer(soundId: layer.soundId)
        }
        applyVolumes()
        isPlaying = true
        updateNowPlaying()
    }

    // MARK: - Transport

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        guard isPlaying else { return }
        players.values.forEach { $0.pause() }
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard !isPlaying, isActive else { return }
        startEngineIfNeeded()
        players.values.forEach { $0.resume() }
        isPlaying = true
        updateNowPlaying()
    }

    /// Full stop: tears down every layer and the timer. The compact/full player close button
    /// calls this — nothing keeps playing in the background afterward.
    func stop() {
        stopAllNodes()
        activeSoundId = nil
        activeMix = nil
        layers = []
        isPlaying = false
        cancelTimer()
        clearNowPlaying()
        deactivateAudioSession()
    }

    // MARK: - Timer

    func setTimer(minutes: Int, fadeSeconds: Double) {
        guard let duration = TimerRules.durationSeconds(minutes: minutes) else { return }
        timerDurationMinutes = minutes
        timerFadeSeconds = min(max(fadeSeconds, 0), TimerRules.maxFadeSeconds)
        timerDeadline = ProcessInfo.processInfo.systemUptime + duration
        startTick()
    }

    func cancelTimer() {
        timerDeadline = nil
        timerDurationMinutes = nil
        timerRemaining = nil
        tickTask?.cancel()
        tickTask = nil
        applyVolumes()
    }

    private func startTick() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.tick()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func tick() {
        guard let deadline = timerDeadline else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let remaining = TimerRules.remaining(deadline: deadline, now: now)
        timerRemaining = remaining
        applyVolumes()
        if remaining <= 0 {
            stop()
        }
    }

    // MARK: - Volume

    private func applyVolumes() {
        let fade = currentFadeMultiplier()
        let gains = MixRules.gains(layers: layers, master: masterVolume, fade: fade)
        for (soundId, gain) in gains {
            players[soundId]?.node.volume = Float(gain)
        }
    }

    private func currentFadeMultiplier() -> Double {
        guard let deadline = timerDeadline else { return 1 }
        return TimerRules.fadeMultiplier(deadline: deadline, now: ProcessInfo.processInfo.systemUptime, fadeSeconds: timerFadeSeconds)
    }

    // MARK: - Engine plumbing

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        // Must be synchronous and ordered before `engine.start()`: AVAudioEngine needs an
        // active session to realize its I/O nodes, and starting it before activation completes
        // throws "inputNode != nullptr || outputNode != nullptr". Apple logs a main-thread
        // hang-risk advisory for synchronous activation, but it's a single quick call made
        // only once per playback start (user-initiated tap) — not the repeated/blocking use
        // the warning is about.
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.prepare()
        try? engine.start()
    }

    private func deactivateAudioSession() {
        Task.detached(priority: .utility) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func startLayer(soundId: String) {
        guard players[soundId] == nil, let url = Bundle.main.url(forResource: soundId, withExtension: "mp3") else {
            playbackError = "missing_audio_\(soundId)"
            return
        }
        do {
            let player = try LoopingPlayer(url: url)
            engine.attach(player.node)
            engine.connect(player.node, to: engine.mainMixerNode, format: player.format)
            players[soundId] = player
            player.start()
        } catch {
            playbackError = error.localizedDescription
        }
    }

    private func stopAllNodes() {
        for (_, player) in players {
            player.stop()
            engine.disconnectNodeOutput(player.node)
            engine.detach(player.node)
        }
        players.removeAll()
        if engine.isRunning { engine.stop() }
    }

    // MARK: - Audio session, interruptions, route changes

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])

        let session = AVAudioSession.sharedInstance()
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleRouteChange(note) }
        }
    }

    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                resume()
            }
        @unknown default:
            break
        }
    }

    /// Mirrors system convention (and Android's "becoming noisy" handling): pause when the
    /// active output disappears (e.g. headphones unplugged) instead of suddenly playing out loud.
    private func handleRouteChange(_ note: Notification) {
        guard let info = note.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    // MARK: - System now-playing / remote commands

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: displayTitle,
            MPMediaItemPropertyArtist: "ZenSounds",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]
        if let artwork = currentArtwork() {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func currentArtwork() -> MPMediaItemArtwork? {
        guard let soundId = activeSoundId ?? layers.first?.soundId,
              let image = UIImage(named: soundId) else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
