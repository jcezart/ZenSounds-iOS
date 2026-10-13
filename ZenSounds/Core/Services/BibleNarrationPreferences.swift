import AVFoundation
import Combine
import Foundation

@MainActor
final class BibleNarrationPreferences: ObservableObject {
    static let shared = BibleNarrationPreferences()

    @Published var portugueseVoiceIdentifier: String? {
        didSet { persist(portugueseVoiceIdentifier, key: portugueseVoiceKey) }
    }

    @Published var englishVoiceIdentifier: String? {
        didSet { persist(englishVoiceIdentifier, key: englishVoiceKey) }
    }

    @Published var rate: Double {
        didSet {
            let validRate = NarrationRateRules.clamped(rate)
            if validRate != rate {
                rate = validRate
            } else {
                defaults.set(validRate, forKey: rateKey)
            }
        }
    }

    private let defaults = UserDefaults.standard
    private let portugueseVoiceKey = "zensounds.narration.voice.pt-BR"
    private let englishVoiceKey = "zensounds.narration.voice.en-US"
    private let rateKey = "zensounds.narration.rate"

    private init() {
        portugueseVoiceIdentifier = defaults.string(forKey: portugueseVoiceKey)
        englishVoiceIdentifier = defaults.string(forKey: englishVoiceKey)
        rate = NarrationRateRules.clamped(
            defaults.object(forKey: rateKey) == nil
                ? Double(AVSpeechUtteranceDefaultSpeechRate)
                : defaults.double(forKey: rateKey)
        )

        validateStoredVoices()
    }

    func voices(for language: BibleLanguage) -> [AVSpeechSynthesisVoice] {
        let locale = localeIdentifier(for: language)
        let languageCode = language == .pt ? "pt" : "en"
        return AVSpeechSynthesisVoice.speechVoices()
            .filter {
                $0.language.caseInsensitiveCompare(locale) == .orderedSame
                    || $0.language.lowercased().hasPrefix("\(languageCode)-")
            }
            .sorted {
                if $0.language.caseInsensitiveCompare(locale) != $1.language.caseInsensitiveCompare(locale) {
                    return $0.language.caseInsensitiveCompare(locale) == .orderedSame
                }
                if $0.quality != $1.quality {
                    return $0.quality.rawValue > $1.quality.rawValue
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    func selectedVoiceIdentifier(for language: BibleLanguage) -> String? {
        language == .pt ? portugueseVoiceIdentifier : englishVoiceIdentifier
    }

    func setSelectedVoiceIdentifier(_ identifier: String?, for language: BibleLanguage) {
        if language == .pt {
            portugueseVoiceIdentifier = identifier
        } else {
            englishVoiceIdentifier = identifier
        }
    }

    func resolvedVoice(for language: BibleLanguage, preferredIdentifier: String? = nil) -> AVSpeechSynthesisVoice? {
        let available = voices(for: language)
        let identifier = preferredIdentifier ?? selectedVoiceIdentifier(for: language)
        if let identifier,
           let selected = available.first(where: { $0.identifier == identifier }) {
            return selected
        }

        let locale = localeIdentifier(for: language)
        return AVSpeechSynthesisVoice(language: locale) ?? available.first
    }

    func localeIdentifier(for language: BibleLanguage) -> String {
        language == .pt ? "pt-BR" : "en-US"
    }

    private func validateStoredVoices() {
        if let portugueseVoiceIdentifier,
           !voices(for: .pt).contains(where: { $0.identifier == portugueseVoiceIdentifier }) {
            self.portugueseVoiceIdentifier = nil
        }
        if let englishVoiceIdentifier,
           !voices(for: .en).contains(where: { $0.identifier == englishVoiceIdentifier }) {
            self.englishVoiceIdentifier = nil
        }
    }

    private func persist(_ identifier: String?, key: String) {
        if let identifier {
            defaults.set(identifier, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

enum NarrationRateRules {
    static let range = 0.35...0.60

    static func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
