import AVFoundation
import Combine
import Foundation

@MainActor
protocol SpeechSynthesizing: AnyObject {
    var delegate: AVSpeechSynthesizerDelegate? { get set }
    var isSpeaking: Bool { get }
    var isPaused: Bool { get }
    func speak(_ utterance: AVSpeechUtterance)
    func pauseSpeaking(at boundary: AVSpeechBoundary) -> Bool
    func continueSpeaking() -> Bool
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool
}

extension AVSpeechSynthesizer: SpeechSynthesizing {}

@MainActor
protocol NarrationAudioCoordinating: AnyObject {
    func prepareAudioSessionForNarration() async -> Bool
    func setNarrationDucking(_ isDucked: Bool)
    func finishNarrationAudioSession()
}

extension AudioEngine: NarrationAudioCoordinating {}

@MainActor
protocol RosaryNarrating: AnyObject {
    var state: BibleNarrationService.PlaybackState { get }
    func speakRosary(text: String, itemID: String, language: BibleLanguage, onStart: @escaping () -> Void, onFinish: @escaping (String) -> Void, onCancel: @escaping () -> Void, onPause: @escaping () -> Void)
    func pause()
    func resume()
    func stop()
}

@MainActor
final class BibleNarrationService: NSObject, ObservableObject {
    enum PlaybackState: Equatable { case stopped, speaking, paused }
    enum PlaybackEvent { case started, paused, resumed, finished, cancelled, failed }
    enum Owner: Equatable { case bible, rosary, preview }

    static func nextState(after event: PlaybackEvent) -> PlaybackState {
        switch event { case .started, .resumed: .speaking; case .paused: .paused; case .finished, .cancelled, .failed: .stopped }
    }

    static let shared = BibleNarrationService()

    @Published private(set) var state: PlaybackState = .stopped
    @Published private(set) var currentItemID: String?
    @Published private(set) var isPreparing = false
    @Published private(set) var errorMessage: String?

    let preferences: BibleNarrationPreferences
    private let synthesizer: SpeechSynthesizing
    private let audioCoordinator: NarrationAudioCoordinating
    private var activeUtteranceIdentifier: ObjectIdentifier?
    private var requests = OperationGeneration()
    private var owner: Owner?
    private var keepsSessionActive = false
    private var sessionPrepared = false
    private var finishHandler: ((String) -> Void)?
    private var startHandler: (() -> Void)?
    private var cancelHandler: (() -> Void)?
    private var pauseHandler: (() -> Void)?

    init(
        synthesizer: SpeechSynthesizing? = nil,
        audioCoordinator: NarrationAudioCoordinating? = nil,
        preferences: BibleNarrationPreferences? = nil
    ) {
        self.synthesizer = synthesizer ?? AVSpeechSynthesizer()
        self.audioCoordinator = audioCoordinator ?? AudioEngine.shared
        self.preferences = preferences ?? .shared
        super.init()
        self.synthesizer.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption(_:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance())
    }

    func isCurrent(_ verse: Verse) -> Bool { currentItemID == verse.id && (state != .stopped || isPreparing) }

    func speak(_ verse: Verse) {
        start(text: verse.text, itemID: verse.id, language: verse.language, preferredVoiceIdentifier: nil, owner: .bible, keepSession: false)
    }

    func previewVoice(identifier: String?, language: BibleLanguage) {
        let sample = language == .pt ? "O Senhor é o meu pastor; nada me faltará." : "The Lord is my shepherd; I shall not want."
        start(text: sample, itemID: "voice-preview-\(language.rawValue)", language: language, preferredVoiceIdentifier: identifier, owner: .preview, keepSession: false)
    }

    func speakRosary(
        text: String,
        itemID: String,
        language: BibleLanguage,
        onStart: @escaping () -> Void,
        onFinish: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onPause: @escaping () -> Void
    ) {
        start(text: text, itemID: itemID, language: language, preferredVoiceIdentifier: nil, owner: .rosary, keepSession: true, onStart: onStart, onFinish: onFinish, onCancel: onCancel, onPause: onPause)
    }

    func pause() {
        guard state == .speaking, synthesizer.isSpeaking else { return }
        _ = synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        guard state == .paused, synthesizer.isPaused else { return }
        let generation = requests.current
        isPreparing = true
        Task { [weak self] in
            guard let self else { return }
            let ready = await audioCoordinator.prepareAudioSessionForNarration()
            guard requests.isCurrent(generation) else { return }
            guard ready else { failCurrentRequest(AppLanguage.localized("Narration is unavailable right now.", defaultValue: "Narration is unavailable right now.")); return }
            sessionPrepared = true
            audioCoordinator.setNarrationDucking(true)
            try? await Task.sleep(for: .milliseconds(180))
            guard requests.isCurrent(generation) else { return }
            isPreparing = false
            if !synthesizer.continueSpeaking() { failCurrentRequest(AppLanguage.localized("Narration could not be resumed.", defaultValue: "Narration could not be resumed.")) }
        }
    }

    func stop() { cancelActive(notify: true, releaseSession: true) }
    func clearError() { errorMessage = nil }

    private func start(
        text: String, itemID: String, language: BibleLanguage, preferredVoiceIdentifier: String?, owner newOwner: Owner,
        keepSession: Bool, onStart: (() -> Void)? = nil, onFinish: ((String) -> Void)? = nil, onCancel: (() -> Void)? = nil, onPause: (() -> Void)? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let canReuseSession = owner == .rosary && newOwner == .rosary && sessionPrepared && activeUtteranceIdentifier == nil
        if activeUtteranceIdentifier != nil || synthesizer.isSpeaking || synthesizer.isPaused {
            cancelActive(notify: true, releaseSession: !canReuseSession)
        }
        let generation = requests.begin()
        errorMessage = nil
        isPreparing = true
        currentItemID = itemID
        owner = newOwner
        keepsSessionActive = keepSession
        startHandler = onStart
        finishHandler = onFinish
        cancelHandler = onCancel
        pauseHandler = onPause

        Task { [weak self] in
            guard let self else { return }
            let ready: Bool
            if canReuseSession { ready = true } else { ready = await audioCoordinator.prepareAudioSessionForNarration() }
            guard requests.isCurrent(generation) else { return }
            guard ready else { failCurrentRequest(AppLanguage.localized("Narration is unavailable right now.", defaultValue: "Narration is unavailable right now.")); return }
            guard let voice = preferences.resolvedVoice(for: language, preferredIdentifier: preferredVoiceIdentifier) else {
                failCurrentRequest(AppLanguage.localized("No compatible voice is installed for this language.", defaultValue: "No compatible voice is installed for this language.")); return
            }
            sessionPrepared = true
            audioCoordinator.setNarrationDucking(true)
            if !canReuseSession { try? await Task.sleep(for: .milliseconds(180)) }
            guard requests.isCurrent(generation) else { return }
            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = voice
            utterance.rate = Float(preferences.rate)
            utterance.preUtteranceDelay = 0.05
            utterance.postUtteranceDelay = 0.05
            activeUtteranceIdentifier = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        }
    }

    private func cancelActive(notify: Bool, releaseSession: Bool) {
        let callback = cancelHandler
        requests.invalidate()
        activeUtteranceIdentifier = nil
        currentItemID = nil
        isPreparing = false
        state = .stopped
        finishHandler = nil
        startHandler = nil
        cancelHandler = nil
        pauseHandler = nil
        owner = nil
        if synthesizer.isSpeaking || synthesizer.isPaused { _ = synthesizer.stopSpeaking(at: .immediate) }
        if releaseSession { releaseAudioSession() }
        if notify { callback?() }
    }

    private func failCurrentRequest(_ message: String) {
        let callback = cancelHandler
        cancelActive(notify: false, releaseSession: true)
        errorMessage = message
        callback?()
    }

    private func releaseAudioSession() {
        if sessionPrepared {
            audioCoordinator.setNarrationDucking(false)
            audioCoordinator.finishNarrationAudioSession()
        }
        sessionPrepared = false
    }

    private func finish(_ identifier: ObjectIdentifier, cancelled: Bool) {
        guard identifier == activeUtteranceIdentifier else { return }
        let itemID = currentItemID
        let finished = finishHandler
        let cancelledCallback = cancelHandler
        activeUtteranceIdentifier = nil
        currentItemID = nil
        isPreparing = false
        state = .stopped
        finishHandler = nil
        startHandler = nil
        cancelHandler = nil
        pauseHandler = nil
        if cancelled { releaseAudioSession(); cancelledCallback?(); owner = nil; return }
        if !keepsSessionActive { releaseAudioSession(); owner = nil }
        if let itemID { finished?(itemID) }
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: value) == .began else { return }
        pause()
    }
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: value) == .oldDeviceUnavailable else { return }
        pause()
    }
}

extension BibleNarrationService: RosaryNarrating {}

extension BibleNarrationService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in guard let self, id == activeUtteranceIdentifier else { return }; isPreparing = false; state = .speaking; startHandler?() }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, id == activeUtteranceIdentifier else { return }
            state = .paused; releaseAudioSession(); pauseHandler?()
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in guard let self, id == activeUtteranceIdentifier else { return }; state = .speaking }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance); Task { @MainActor [weak self] in self?.finish(id, cancelled: false) }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance); Task { @MainActor [weak self] in self?.finish(id, cancelled: true) }
    }
}
