import SwiftUI

struct TimerSheetView: View {
    @ObservedObject private var audio = AudioEngine.shared
    @Environment(\.dismiss) private var dismiss
    @State private var customMinutesText = ""

    private let presets = [5, 15, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    ForEach(presets, id: \.self) { minutes in
                        Button("\(minutes) min") {
                            audio.setTimer(minutes: minutes, fadeSeconds: audio.timerFadeSeconds)
                            dismiss()
                        }
                    }
                    HStack {
                        TextField("Custom minutes", text: $customMinutesText)
                            .keyboardType(.numberPad)
                            .accessibilityLabel("Custom minutes")
                        Button("Start") {
                            if let minutes = Int(customMinutesText) {
                                audio.setTimer(minutes: minutes, fadeSeconds: audio.timerFadeSeconds)
                                dismiss()
                            }
                        }
                        .disabled(Int(customMinutesText) == nil)
                    }
                }
                Section("Fade out") {
                    Slider(value: $audio.timerFadeSeconds, in: 0...TimerRules.maxFadeSeconds, step: 5)
                        .accessibilityLabel("Fade-out duration")
                    Text(audio.timerFadeSeconds == 0 ? "Stops abruptly, no fade" : "\(Int(audio.timerFadeSeconds))s volume fade before stopping")
                        .font(.essenceBodySmall)
                        .foregroundStyle(.secondary)
                }
                if audio.timerDeadline != nil {
                    Section {
                        Button("Cancel timer", role: .destructive) {
                            audio.cancelTimer()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Sleep timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
