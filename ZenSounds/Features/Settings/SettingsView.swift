import SwiftUI
import WidgetKit
import AVFoundation

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.essencePalette) private var palette

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
            voicePicker(for: .pt, title: "Portuguese voice")
            previewButton(for: .pt)

            voicePicker(for: .en, title: "English voice")
            previewButton(for: .en)

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

            Text("Only voices currently available on this iPhone are shown. Additional voices can be installed in iPhone Settings under Accessibility, Spoken Content, Voices.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func voicePicker(for language: BibleLanguage, title: LocalizedStringKey) -> some View {
        let voices = preferences.voices(for: language)
        if voices.isEmpty {
            LabeledContent(title) {
                Text("No voice available")
                    .foregroundStyle(.secondary)
            }
        } else {
            Picker(title, selection: voiceBinding(for: language)) {
                Text("System default").tag(String?.none)
                ForEach(voices, id: \.identifier) { voice in
                    Text(voiceDisplayName(voice)).tag(Optional(voice.identifier))
                }
            }
        }
    }

    private func previewButton(for language: BibleLanguage) -> some View {
        let previewID = "voice-preview-\(language.rawValue)"
        let isPreviewing = narration.currentItemID == previewID
        return Button {
            if isPreviewing {
                narration.stop()
            } else {
                narration.previewVoice(
                    identifier: preferences.selectedVoiceIdentifier(for: language),
                    language: language
                )
            }
        } label: {
            Label(
                isPreviewing ? "Stop voice sample" : "Listen to voice sample",
                systemImage: isPreviewing ? "stop.fill" : "speaker.wave.2.fill"
            )
        }
        .disabled(preferences.voices(for: language).isEmpty)
    }

    private func voiceBinding(for language: BibleLanguage) -> Binding<String?> {
        Binding(
            get: { preferences.selectedVoiceIdentifier(for: language) },
            set: { identifier in
                if narration.currentItemID == "voice-preview-\(language.rawValue)" {
                    narration.stop()
                }
                preferences.setSelectedVoiceIdentifier(identifier, for: language)
            }
        )
    }

    private func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
        "\(voice.name) · \(voice.language)"
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
