import AVFoundation
import Combine
import Foundation

nonisolated enum NarrationVoiceQuality: Int, Codable, CaseIterable, Comparable, Sendable {
    case `default` = 0
    case enhanced = 1
    case premium = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

nonisolated struct VoiceDescriptor: Identifiable, Equatable, Sendable {
    let identifier: String
    let name: String
    let language: String
    let quality: NarrationVoiceQuality
    let isNovelty: Bool
    let isPersonal: Bool

    var id: String { identifier }
}

@MainActor
final class BibleNarrationPreferences: ObservableObject {
    static let shared = BibleNarrationPreferences()

    @Published var portugueseVoiceIdentifier: String? {
        didSet { persist(portugueseVoiceIdentifier, key: portugueseVoiceKey) }
    }
    @Published var englishVoiceIdentifier: String? {
        didSet { persist(englishVoiceIdentifier, key: englishVoiceKey) }
    }
    @Published private(set) var availableVoices: [VoiceDescriptor] = []
    @Published var rate: Double {
        didSet {
            let validRate = NarrationRateRules.clamped(rate)
            if validRate != rate { rate = validRate } else { defaults.set(validRate, forKey: rateKey) }
        }
    }

    private let defaults: UserDefaults
    private let portugueseVoiceKey = "zensounds.narration.voice.pt-BR"
    private let englishVoiceKey = "zensounds.narration.voice.en-US"
    private let rateKey = "zensounds.narration.rate"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        portugueseVoiceIdentifier = defaults.string(forKey: portugueseVoiceKey)
        englishVoiceIdentifier = defaults.string(forKey: englishVoiceKey)
        rate = NarrationRateRules.clamped(defaults.object(forKey: rateKey) == nil
            ? Double(AVSpeechUtteranceDefaultSpeechRate) : defaults.double(forKey: rateKey))
        refreshAvailableVoices()
    }

    func refreshAvailableVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices().map(Self.descriptor)
        validateStoredVoices()
    }

    func descriptors(for language: BibleLanguage) -> [VoiceDescriptor] {
        NarrationVoiceRules.selectorVoices(
            from: availableVoices,
            languageCode: languageCode(for: language),
            exactLocale: localeIdentifier(for: language)
        )
    }

    func voices(for language: BibleLanguage) -> [AVSpeechSynthesisVoice] {
        let identifiers = Set(descriptors(for: language).map(\.identifier))
        return AVSpeechSynthesisVoice.speechVoices().filter { identifiers.contains($0.identifier) }
            .sorted { first, second in
                let ordered = descriptors(for: language).map(\.identifier)
                return (ordered.firstIndex(of: first.identifier) ?? .max) < (ordered.firstIndex(of: second.identifier) ?? .max)
            }
    }

    func selectedVoiceIdentifier(for language: BibleLanguage) -> String? {
        language == .pt ? portugueseVoiceIdentifier : englishVoiceIdentifier
    }

    func setSelectedVoiceIdentifier(_ identifier: String?, for language: BibleLanguage) {
        if language == .pt { portugueseVoiceIdentifier = identifier } else { englishVoiceIdentifier = identifier }
    }

    func effectiveDescriptor(for language: BibleLanguage, preferredIdentifier: String? = nil) -> VoiceDescriptor? {
        let candidates = descriptors(for: language)
        if let identifier = preferredIdentifier ?? selectedVoiceIdentifier(for: language),
           let selected = candidates.first(where: { $0.identifier == identifier }) { return selected }
        return NarrationVoiceRules.automaticVoice(
            from: candidates,
            languageCode: languageCode(for: language),
            exactLocale: localeIdentifier(for: language)
        )
    }

    func resolvedVoice(for language: BibleLanguage, preferredIdentifier: String? = nil) -> AVSpeechSynthesisVoice? {
        guard let descriptor = effectiveDescriptor(for: language, preferredIdentifier: preferredIdentifier) else {
            return AVSpeechSynthesisVoice(language: localeIdentifier(for: language))
        }
        return AVSpeechSynthesisVoice(identifier: descriptor.identifier)
    }

    func localeIdentifier(for language: BibleLanguage) -> String { language == .pt ? "pt-BR" : "en-US" }
    func languageCode(for language: BibleLanguage) -> String { language == .pt ? "pt" : "en" }

    private static func descriptor(_ voice: AVSpeechSynthesisVoice) -> VoiceDescriptor {
        let quality: NarrationVoiceQuality
        switch voice.quality {
        case .premium: quality = .premium
        case .enhanced: quality = .enhanced
        default: quality = .default
        }
        return VoiceDescriptor(
            identifier: voice.identifier,
            name: voice.name,
            language: voice.language,
            quality: quality,
            isNovelty: voice.voiceTraits.contains(.isNoveltyVoice),
            isPersonal: voice.voiceTraits.contains(.isPersonalVoice)
        )
    }

    private func validateStoredVoices() {
        if let portugueseVoiceIdentifier,
           !descriptors(for: .pt).contains(where: { $0.identifier == portugueseVoiceIdentifier }) {
            self.portugueseVoiceIdentifier = nil
        }
        if let englishVoiceIdentifier,
           !descriptors(for: .en).contains(where: { $0.identifier == englishVoiceIdentifier }) {
            self.englishVoiceIdentifier = nil
        }
    }

    private func persist(_ identifier: String?, key: String) {
        if let identifier { defaults.set(identifier, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}

nonisolated enum NarrationRateRules {
    static let range = 0.35...0.60
    static func clamped(_ value: Double) -> Double { min(max(value, range.lowerBound), range.upperBound) }
}

nonisolated enum NarrationVoiceRules {
    static func selectorVoices(from voices: [VoiceDescriptor], languageCode: String, exactLocale: String) -> [VoiceDescriptor] {
        voices.filter {
            !$0.isNovelty && !$0.isPersonal && baseLanguage($0.language) == languageCode.lowercased()
        }.sorted {
            if $0.quality != $1.quality { return $0.quality > $1.quality }
            let firstExact = $0.language.caseInsensitiveCompare(exactLocale) == .orderedSame
            let secondExact = $1.language.caseInsensitiveCompare(exactLocale) == .orderedSame
            if firstExact != secondExact { return firstExact }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func automaticVoice(from voices: [VoiceDescriptor], languageCode: String, exactLocale: String) -> VoiceDescriptor? {
        let candidates = selectorVoices(from: voices, languageCode: languageCode, exactLocale: exactLocale)
        let exact = candidates.filter { $0.language.caseInsensitiveCompare(exactLocale) == .orderedSame }
        return exact.first ?? candidates.first
    }

    static func resolvedIdentifier(preferredIdentifier: String?, availableIdentifiers: [String]) -> String? {
        if let preferredIdentifier, availableIdentifiers.contains(preferredIdentifier) { return preferredIdentifier }
        return availableIdentifiers.first
    }

    private static func baseLanguage(_ identifier: String) -> String {
        identifier.split(separator: "-").first.map(String.init)?.lowercased() ?? identifier.lowercased()
    }
}
