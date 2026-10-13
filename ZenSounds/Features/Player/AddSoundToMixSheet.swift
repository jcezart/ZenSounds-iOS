import SwiftUI

struct AddSoundToMixSheet: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    let excluding: Set<String>
    let onSelect: (String) -> Void

    @Environment(\.essencePalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(SoundCatalog.all.filter { !excluding.contains($0.id) }) { sound in
                Button {
                    onSelect(sound.id)
                } label: {
                    Text(LocalizedStringKey(sound.titleKey))
                        .foregroundStyle(palette.text)
                }
            }
            .navigationTitle(AppLanguage.localized("Add sound", defaultValue: "Add sound"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
