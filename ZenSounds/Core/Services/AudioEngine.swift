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

    private lazy var engine: AVAudioEngine = {
        AVAudioEngine()
    }()
    private var players: [String: LoopingPlayer] = [:]
    private var tickTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var narrationDuckingTask: Task<Void, Never>?
    private var narrationDuckMultiplier = 1.0
    private var isNarrationSessionActive = false
    private var isAudioConfigured = false
    private let audioSessionQueue = DispatchQueue(label: "com.juliocezar.zensounds.audio-session")
    private var playbackRequests = OperationGeneration()
    private var transportState: AudioTransportState = .stopped

    var isActive: Bool { activeSoundId != nil || activeMix != nil }

    var displayTitle: String {
        if let mix = activeMix { return mix.name }
        if let soundId = activeSoundId, let sound = SoundCatalog.sound(id: soundId) {
            return AppLanguage.localized(sound.titleKey, defaultValue: soundId)
        }
        return "Orante"
    }

    private init() {}

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

        playbackTask?.cancel()
        let generation = playbackRequests.begin()
        playbackTask = Task { [weak self] in
            await self?.startPlayback(
                layers: normalized,
                mix: mix,
                singleSoundId: singleSoundId,
                generation: generation
            )
        }
    }

    private func startPlayback(
        layers newLayers: [MixLayer],
        mix: SavedMix?,
        singleSoundId: String?,
        generation: UInt64
    ) async {
        playbackError = nil
        guard ensureAudioConfigured() else {
            transitionTransport(.startFailed)
            return
        }
        guard await activateAudioSession(), isCurrentPlayback(generation) else {
            transitionTransport(.startFailed)
            return
        }

        var pendingPlayers: [String: LoopingPlayer] = [:]
        for layer in newLayers {
            guard isCurrentPlayback(generation),
                  let player = makePlayer(soundId: layer.soundId) else {
                dispose(pendingPlayers)
                transitionTransport(.startFailed)
                return
            }
            pendingPlayers[layer.soundId] = player
        }

        guard isCurrentPlayback(generation), startEngine() else {
            dispose(pendingPlayers)
            transitionTransport(.startFailed)
            return
        }

        stopAllNodes(keepEngineRunning: true)
        players = pendingPlayers
        activeSoundId = singleSoundId
        activeMix = mix
        layers = newLayers
        applyVolumes()
        for player in players.values {
            player.start()
        }
        transitionTransport(.startSucceeded)
        updateNowPlaying()
    }

    // MARK: - Transport

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        guard isPlaying else { return }
        players.values.forEach { $0.pause() }
        if engine.isRunning {
            engine.pause()
        }
        transitionTransport(.pause)
        updateNowPlaying()
        if !isNarrationSessionActive {
            deactivateAudioSession()
        }
    }

    func resume() {
        guard !isPlaying, isActive else { return }
        playbackTask?.cancel()
        let generation = playbackRequests.begin()
        playbackTask = Task { [weak self] in
            guard let self,
                  await self.startEngineIfNeeded(),
                  self.isCurrentPlayback(generation) else { return }
            for player in self.players.values {
                player.resume()
            }
            self.transitionTransport(.resumeSucceeded)
            self.updateNowPlaying()
        }
    }

    /// Full stop: tears down every layer and the timer. The compact/full player close button
    /// calls this — nothing keeps playing in the background afterward.
    func stop() {
        playbackRequests.invalidate()
        playbackTask?.cancel()
        playbackTask = nil
        stopAllNodes()
        activeSoundId = nil
        activeMix = nil
        layers = []
        transitionTransport(.stop)
        cancelTimer()
        clearNowPlaying()
        if !isNarrationSessionActive {
            deactivateAudioSession()
        }
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
            finishTimerPlayback()
        }
    }

    /// A sleep timer silences playback without discarding the selected sound or mix. Keeping the
    /// nodes and metadata makes the full player remain useful and lets the user start it again.
    private func finishTimerPlayback() {
        players.values.forEach { $0.pause() }
        if engine.isRunning {
            engine.pause()
        }
        transitionTransport(.timerExpired)
        cancelTimer()
        updateNowPlaying()
        if !isNarrationSessionActive {
            deactivateAudioSession()
        }
    }

    // MARK: - Volume

    func setNarrationDucking(_ active: Bool) {
        narrationDuckingTask?.cancel()

        let initialMultiplier = narrationDuckMultiplier
        let targetMultiplier = active ? AudioGainRules.narrationDuckMultiplier : 1.0
        guard abs(initialMultiplier - targetMultiplier) > 0.001 else {
            narrationDuckMultiplier = targetMultiplier
            applyVolumes()
            return
        }

        narrationDuckingTask = Task { [weak self] in
            let steps = 14
            for step in 1...steps {
                guard let self, !Task.isCancelled else { return }
                let progress = Double(step) / Double(steps)
                self.narrationDuckMultiplier = initialMultiplier
                    + ((targetMultiplier - initialMultiplier) * progress)
                self.applyVolumes()
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }

    func finishNarrationAudioSession() {
        isNarrationSessionActive = false
        setNarrationDucking(false)
        if !isActive {
            deactivateAudioSession()
        }
    }

    func clearPlaybackError() {
        playbackError = nil
    }

    private func applyVolumes() {
        let fade = currentFadeMultiplier()
        let gains = MixRules.gains(layers: layers, master: masterVolume, fade: fade)
        for (soundId, gain) in gains {
            players[soundId]?.node.volume = Float(
                AudioGainRules.effectiveGain(baseGain: gain, duckMultiplier: narrationDuckMultiplier)
            )
        }
    }

    private func currentFadeMultiplier() -> Double {
        guard let deadline = timerDeadline else { return 1 }
        return TimerRules.fadeMultiplier(deadline: deadline, now: ProcessInfo.processInfo.systemUptime, fadeSeconds: timerFadeSeconds)
    }

    // MARK: - Engine plumbing

    func prepareAudioSessionForNarration() async -> Bool {
        guard ensureAudioConfigured() else { return false }
        let isReady = await activateAudioSession()
        if isReady {
            isNarrationSessionActive = true
        }
        return isReady
    }

    private func startEngineIfNeeded() async -> Bool {
        guard !engine.isRunning else { return true }
        guard ensureAudioConfigured() else { return false }
        guard await activateAudioSession() else { return false }
        return startEngine()
    }

    private func activateAudioSession() async -> Bool {
        let activationError = await withCheckedContinuation { continuation in
            audioSessionQueue.async {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    continuation.resume(returning: nil as String?)
                } catch {
                    continuation.resume(returning: error.localizedDescription)
                }
            }
        }
        guard activationError == nil else {
            playbackError = activationError ?? "audio_session_activation_failed"
            return false
        }
        return true
    }

    private func startEngine() -> Bool {
        guard !engine.isRunning else { return true }
        configureOutputConnectionIfNeeded()
        engine.prepare()
        do {
            try engine.start()
            return true
        } catch {
            playbackError = error.localizedDescription
            return false
        }
    }

    private func deactivateAudioSession() {
        audioSessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    private func makePlayer(soundId: String) -> LoopingPlayer? {
        guard let url = Bundle.main.url(forResource: soundId, withExtension: "mp3") else {
            playbackError = String(localized: "The audio file for this sound is unavailable.")
            return nil
        }
        do {
            let player = try LoopingPlayer(url: url)
            engine.attach(player.node)
            engine.connect(player.node, to: engine.mainMixerNode, format: player.format)
            return player
        } catch {
            playbackError = error.localizedDescription
            return nil
        }
    }

    private func dispose(_ playersToDispose: [String: LoopingPlayer]) {
        for player in playersToDispose.values {
            player.stop()
            engine.disconnectNodeOutput(player.node)
            engine.detach(player.node)
        }
    }

    private func stopAllNodes(keepEngineRunning: Bool = false) {
        for (_, player) in players {
            player.stop()
            engine.disconnectNodeOutput(player.node)
            engine.detach(player.node)
        }
        players.removeAll()
        if engine.isRunning && !keepEngineRunning { engine.stop() }
    }

    // MARK: - Audio session, interruptions, route changes

    private func ensureAudioConfigured() -> Bool {
        guard !isAudioConfigured else { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch {
            playbackError = error.localizedDescription
            return false
        }
        isAudioConfigured = true

        let session = AVAudioSession.sharedInstance()
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            guard let typeValue = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
            let optionsValue = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] note in
            guard let reasonValue = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
            Task { @MainActor [weak self] in
                self?.handleRouteChange(reasonValue: reasonValue)
            }
        }
        configureRemoteCommands()
        return true
    }

    private func configureOutputConnectionIfNeeded() {
        let mixer = engine.mainMixerNode
        guard engine.outputConnectionPoints(for: mixer, outputBus: 0).isEmpty else { return }
        engine.connect(mixer, to: engine.outputNode, format: nil)
    }

    private func isCurrentPlayback(_ generation: UInt64) -> Bool {
        !Task.isCancelled && playbackRequests.isCurrent(generation)
    }

    private func transitionTransport(_ event: AudioTransportEvent) {
        transportState = AudioTransportRules.nextState(from: transportState, event: event)
        isPlaying = transportState == .playing
    }

    private func handleInterruption(typeValue: UInt, optionsValue: UInt?) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                resume()
            }
        @unknown default:
            break
        }
    }

    /// Mirrors system convention (and Android's "becoming noisy" handling): pause when the
    /// active output disappears (e.g. headphones unplugged) instead of suddenly playing out loud.
    private func handleRouteChange(reasonValue: UInt) {
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
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
            MPMediaItemPropertyArtist: "Orante",
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

enum AudioGainRules {
    static let narrationDuckMultiplier = 0.30

    static func effectiveGain(baseGain: Double, duckMultiplier: Double) -> Double {
        min(max(baseGain, 0), 1) * min(max(duckMultiplier, 0), 1)
    }
}

struct OperationGeneration {
    private(set) var current: UInt64 = 0

    mutating func begin() -> UInt64 {
        current &+= 1
        return current
    }

    mutating func invalidate() {
        current &+= 1
    }

    func isCurrent(_ generation: UInt64) -> Bool {
        generation == current
    }
}

enum AudioTransportState: Equatable {
    case stopped
    case playing
    case paused
}

enum AudioTransportEvent {
    case startSucceeded
    case pause
    case resumeSucceeded
    case stop
    case startFailed
    case timerExpired
}

enum AudioTransportRules {
    static func nextState(from current: AudioTransportState, event: AudioTransportEvent) -> AudioTransportState {
        switch event {
        case .startSucceeded, .resumeSucceeded:
            return .playing
        case .pause, .timerExpired:
            return current == .playing ? .paused : current
        case .stop:
            return .stopped
        case .startFailed:
            return current
        }
    }
}
