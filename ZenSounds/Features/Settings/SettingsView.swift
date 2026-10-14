import SwiftUI
import WidgetKit
import AVFoundation
import Combine

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.essencePalette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $themeManager.mode) {
                        Text("System").tag(ThemeMode.system)
                        Text("Light").tag(ThemeMode.light)
                        Text("Dark").tag(ThemeMode.dark)
                    }
                }
                Section("Language") {
                    Picker("", selection: $languageStore.selection) {
                        Text("System").tag(AppLanguage.system)
                        Text("Português").tag(AppLanguage.pt)
                        Text("English").tag(AppLanguage.en)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityLabel("Language")
                }
                BibleNarrationSettingsSection()
                Section("About") {
                    if let manifest = BibleCatalog.shared.manifest {
                        ForEach(manifest.translations) { translation in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(translation.translationId.uppercased())
                                    .font(.essenceLabelLarge)
                                    .foregroundStyle(palette.text)
                                if let url = URL(string: translation.licenseUrl) {
                                    Link("License", destination: url)
                                        .font(.essenceBodySmall)
                                }
                            }
                        }
                    }
                    Text("Plus Jakarta Sans typeface, licensed under the SIL Open Font License.")
                        .font(.essenceBodySmall)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .navigationTitle(AppLanguage.localized("Settings", defaultValue: "Settings"))
            .onChange(of: languageStore.selection) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active { BibleNarrationPreferences.shared.refreshAvailableVoices() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
                BibleNarrationPreferences.shared.refreshAvailableVoices()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .id(languageStore.selection)
    }
}

private struct BibleNarrationSettingsSection: View {
    @ObservedObject private var preferences = BibleNarrationPreferences.shared
    @ObservedObject private var narration = BibleNarrationService.shared

    var body: some View {
        Section("Bible reading voice") {
            voiceLink(for: .pt, title: "Portuguese voice")
            voiceLink(for: .en, title: "English voice")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Reading speed")
                    Spacer()
                    Text(speedDescription)
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $preferences.rate,
                    in: NarrationRateRules.range,
                    step: 0.05
                ) {
                    Text("Reading speed")
                } minimumValueLabel: {
                    Image(systemName: "tortoise")
                        .accessibilityHidden(true)
                } maximumValueLabel: {
                    Image(systemName: "hare")
                        .accessibilityHidden(true)
                }
                .accessibilityValue(speedDescription)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Improve narration quality")
                    .font(.headline)
                Text("You can download Enhanced or Premium voices in iPhone Settings for more natural reading. In general: Settings > Accessibility > Spoken Content > Voices (names may vary by iOS version).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func voiceLink(for language: BibleLanguage, title: LocalizedStringKey) -> some View {
        NavigationLink {
            NarrationVoiceListView(language: language, title: title)
        } label: {
            LabeledContent(title) {
                if let voice = preferences.effectiveDescriptor(for: language) {
                    Text(selectionSummary(voice, automatic: preferences.selectedVoiceIdentifier(for: language) == nil))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("No voice available").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func selectionSummary(_ voice: VoiceDescriptor, automatic: Bool) -> String {
        let prefix = automatic ? AppLanguage.localized("Automatic", defaultValue: "Automatic") + " — " : ""
        return prefix + voice.name + " · " + qualityText(voice.quality)
    }

    private func qualityText(_ quality: NarrationVoiceQuality) -> String {
        switch quality {
        case .premium: AppLanguage.localized("Premium", defaultValue: "Premium")
        case .enhanced: AppLanguage.localized("Enhanced", defaultValue: "Enhanced")
        case .default: AppLanguage.localized("Default", defaultValue: "Default")
        }
    }

    private var speedDescription: LocalizedStringKey {
        switch preferences.rate {
        case ..<0.43:
            "Slow"
        case 0.43..<0.56:
            "Normal"
        default:
            "Fast"
        }
    }
}

private struct NarrationVoiceListView: View {
    let language: BibleLanguage
    let title: LocalizedStringKey

    @ObservedObject private var preferences = BibleNarrationPreferences.shared
    @ObservedObject private var narration = BibleNarrationService.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        List {
            Section {
                voiceRow(descriptor: preferences.effectiveDescriptor(for: language), identifier: nil, automatic: true)
            }
            ForEach(NarrationVoiceQuality.allCases.reversed(), id: \.self) { quality in
                let voices = preferences.descriptors(for: language).filter { $0.quality == quality }
                if !voices.isEmpty {
                    Section(qualityTitle(quality)) {
                        ForEach(voices) { voice in
                            voiceRow(descriptor: voice, identifier: voice.identifier, automatic: false)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if narration.currentItemID == previewID { narration.stop() }
        }
    }

    private func voiceRow(descriptor: VoiceDescriptor?, identifier: String?, automatic: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                if narration.currentItemID == previewID { narration.stop() }
                preferences.setSelectedVoiceIdentifier(identifier, for: language)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(automatic ? "Automatic (best installed)" : (descriptor?.name ?? "No voice available"))
                        .foregroundStyle(palette.text)
                    if let descriptor {
                        Text("\(localeName(descriptor.language)) · \(qualityText(descriptor.quality))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(descriptor == nil)

            if preferences.selectedVoiceIdentifier(for: language) == identifier {
                Image(systemName: "checkmark").foregroundStyle(palette.accent).accessibilityLabel("Selected")
            }
            Button {
                if narration.currentItemID == previewID { narration.stop() }
                else { narration.previewVoice(identifier: identifier, language: language) }
            } label: {
                Image(systemName: narration.currentItemID == previewID ? "stop.fill" : "speaker.wave.2.fill")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent)
            .disabled(descriptor == nil)
            .accessibilityLabel(narration.currentItemID == previewID ? "Stop voice sample" : "Listen to voice sample")
        }
    }

    private var previewID: String { "voice-preview-\(language.rawValue)" }

    private func qualityTitle(_ quality: NarrationVoiceQuality) -> LocalizedStringKey {
        switch quality { case .premium: "Premium"; case .enhanced: "Enhanced"; case .default: "Default" }
    }
    private func qualityText(_ quality: NarrationVoiceQuality) -> String {
        switch quality {
        case .premium: AppLanguage.localized("Premium", defaultValue: "Premium")
        case .enhanced: AppLanguage.localized("Enhanced", defaultValue: "Enhanced")
        case .default: AppLanguage.localized("Default", defaultValue: "Default")
        }
    }
    private func localeName(_ identifier: String) -> String {
        let localeID = AppLanguageStore.shared.selection.bibleLanguage == .pt ? "pt-BR" : "en-US"
        return Locale(identifier: localeID).localizedString(forIdentifier: identifier) ?? identifier
    }
}

#Preview("Settings") {
    ZenSoundsTheme { SettingsView() }
}

#Preview("Settings Dark") {
    ZenSoundsTheme { SettingsView() }.preferredColorScheme(.dark)
}
