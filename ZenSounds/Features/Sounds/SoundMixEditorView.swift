import SwiftUI

struct SoundMixEditorView: View {
    let existingMixId: String?

    @ObservedObject private var prefs = UserPreferencesStore.shared
    @ObservedObject private var audio = AudioEngine.shared
    @Environment(\.essencePalette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var layers: [MixLayer] = []
    @State private var isSaveAlertPresented = false
    @State private var mixName = ""

    var body: some View {
        List {
            Section("Sounds") {
                ForEach(SoundCatalog.all) { sound in
                    let isSelected = layers.contains { $0.soundId == sound.id }
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { isSelected },
                            set: { toggle(sound.id, isOn: $0) }
                        )) {
                            Text(NSLocalizedString(sound.titleKey, value: sound.id, comment: ""))
                        }
                        .tint(palette.accent)

                        if isSelected, let layer = layers.first(where: { $0.soundId == sound.id }) {
                            Slider(value: Binding(
                                get: { layer.volume },
                                set: { updateVolume(sound.id, volume: $0) }
                            ))
                            .tint(palette.accent)
                        }
                    }
                }
            }
        }
        .navigationTitle(existingMixId == nil ? "New mix" : "Edit mix")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Play") {
                    audio.playAdHocMix(layers: layers)
                    PlayerPresentation.shared.isFullPlayerPresented = true
                }
                .disabled(layers.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isSaveAlertPresented = true
            } label: {
                Text("Save mix")
                    .font(.essenceLabelLarge)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(palette.onAccent)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(layers.isEmpty)
            .padding()
        }
        .alert("Save mix", isPresented: $isSaveAlertPresented) {
            TextField("Mix name", text: $mixName)
            Button("Save") {
                if let saved = prefs.saveMix(name: mixName, layers: layers, existingId: existingMixId) {
                    layers = saved.layers
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            guard let id = existingMixId, let mix = prefs.savedMixes.first(where: { $0.id == id }) else { return }
            layers = mix.layers
            mixName = mix.name
        }
    }

    private func toggle(_ soundId: String, isOn: Bool) {
        if isOn {
            guard layers.count < MixRules.maxLayers else { return }
            layers.append(MixLayer(soundId: soundId))
        } else {
            layers.removeAll { $0.soundId == soundId }
        }
    }

    private func updateVolume(_ soundId: String, volume: Double) {
        guard let index = layers.firstIndex(where: { $0.soundId == soundId }) else { return }
        layers[index].volume = volume
    }
}
