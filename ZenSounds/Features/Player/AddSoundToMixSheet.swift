import SwiftUI

struct AddSoundToMixSheet: View {
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
                    Text(NSLocalizedString(sound.titleKey, value: sound.id, comment: ""))
                        .foregroundStyle(palette.text)
                }
            }
            .navigationTitle("Add sound")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
