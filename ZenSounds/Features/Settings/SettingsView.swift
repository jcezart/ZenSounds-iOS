import SwiftUI

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @AppStorage(BibleLanguage.storageKey) private var languageRaw = BibleLanguage.systemDefault.rawValue
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
                Section("Bible translation") {
                    Picker("Language", selection: $languageRaw) {
                        Text("Português").tag(BibleLanguage.pt.rawValue)
                        Text("English").tag(BibleLanguage.en.rawValue)
                    }
                    .pickerStyle(.segmented)
                }
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
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
