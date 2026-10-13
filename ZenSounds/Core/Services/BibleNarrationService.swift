import AVFoundation
import Combine
import Foundation

@MainActor
final class BibleNarrationService: NSObject, ObservableObject {
    enum PlaybackState: Equatable {
        case stopped
        case speaking
        case paused
    }

    static let shared = BibleNarrationService()

    @Published private(set) var state: PlaybackState = .stopped
    @Published private(set) var currentItemID: String?
    @Published private(set) var isPreparing = false
    @Published private(set) var errorMessage: String?

    let preferences = BibleNarrationPreferences.shared

    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtteranceIdentifier: ObjectIdentifier?
    private var requestGeneration: UInt64 = 0

    private override init() {
        super.init()
        synthesizer.delegate = self
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        center.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    func isCurrent(_ verse: Verse) -> Bool {
        currentItemID == verse.id && (state != .stopped || isPreparing)
    }

    func speak(_ verse: Verse) {
        start(
            text: verse.text,
            itemID: verse.id,
            language: verse.language,
            preferredVoiceIdentifier: nil
        )
    }

    func previewVoice(identifier: String?, language: BibleLanguage) {
        let sample = language == .pt
            ? "O Senhor é o meu pastor; nada me faltará."
            : "The Lord is my shepherd; I shall not want."
        start(
            text: sample,
            itemID: "voice-preview-\(language.rawValue)",
            language: language,
            preferredVoiceIdentifier: identifier
        )
    }

    func pause() {
        guard state == .speaking, synthesizer.isSpeaking else { return }
        _ = synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        guard state == .paused, synthesizer.isPaused else { return }
        let generation = requestGeneration
        isPreparing = true
        Task { [weak self] in
            guard let self else { return }
            let isReady = await AudioEngine.shared.prepareAudioSessionForNarration()
            guard generation == requestGeneration else {
                if currentItemID == nil {
                    AudioEngine.shared.finishNarrationAudioSession()
                }
                return
            }
            guard isReady else {
                failCurrentRequest("Narration is unavailable right now.")
                return
            }
            AudioEngine.shared.setNarrationDucking(true)
            try? await Task.sleep(for: .milliseconds(180))
            guard generation == requestGeneration else { return }
            isPreparing = false
            if !synthesizer.continueSpeaking() {
                failCurrentRequest("Narration could not be resumed.")
            }
        }
    }

    func stop() {
        requestGeneration &+= 1
        isPreparing = false
        activeUtteranceIdentifier = nil
        currentItemID = nil
        state = .stopped
        if synthesizer.isSpeaking || synthesizer.isPaused {
            _ = synthesizer.stopSpeaking(at: .immediate)
        }
        AudioEngine.shared.finishNarrationAudioSession()
    }

    func clearError() {
        errorMessage = nil
    }

    private func start(
        text: String,
        itemID: String,
        language: BibleLanguage,
        preferredVoiceIdentifier: String?
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        requestGeneration &+= 1
        let generation = requestGeneration
        errorMessage = nil
        isPreparing = true
        currentItemID = itemID
        state = .stopped

        if synthesizer.isSpeaking || synthesizer.isPaused {
            activeUtteranceIdentifier = nil
            _ = synthesizer.stopSpeaking(at: .immediate)
        }

        Task { [weak self] in
            guard let self else { return }
            let isReady = await AudioEngine.shared.prepareAudioSessionForNarration()
            guard generation == requestGeneration else {
                if currentItemID == nil {
                    AudioEngine.shared.finishNarrationAudioSession()
                }
                return
            }
            guard isReady else {
                failCurrentRequest("Narration is unavailable right now.")
                return
            }

            guard let voice = preferences.resolvedVoice(
                for: language,
                preferredIdentifier: preferredVoiceIdentifier
            ) else {
                failCurrentRequest("No compatible voice is installed for this language.")
                return
            }

            AudioEngine.shared.setNarrationDucking(true)
            try? await Task.sleep(for: .milliseconds(180))
            guard generation == requestGeneration else { return }

            let utterance = AVSpeechUtterance(string: trimmedText)
            utterance.voice = voice
            utterance.rate = Float(preferences.rate)
            utterance.pitchMultiplier = 1
            utterance.preUtteranceDelay = 0.05
            utterance.postUtteranceDelay = 0.05
            activeUtteranceIdentifier = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        }
    }

    private func failCurrentRequest(_ message: String) {
        isPreparing = false
        currentItemID = nil
        activeUtteranceIdentifier = nil
        state = .stopped
        errorMessage = message
        AudioEngine.shared.finishNarrationAudioSession()
    }

    private func finish(_ identifier: ObjectIdentifier) {
        guard identifier == activeUtteranceIdentifier else { return }
        activeUtteranceIdentifier = nil
        isPreparing = false
        currentItemID = nil
        state = .stopped
        AudioEngine.shared.finishNarrationAudioSession()
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

extension BibleNarrationService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, identifier == activeUtteranceIdentifier else { return }
            isPreparing = false
            state = .speaking
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, identifier == activeUtteranceIdentifier else { return }
            state = .paused
            AudioEngine.shared.setNarrationDucking(false)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, identifier == activeUtteranceIdentifier else { return }
            state = .speaking
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.finish(identifier)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.finish(identifier)
        }
    }
}
