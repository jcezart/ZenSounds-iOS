import SwiftUI

struct TimerSheetView: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var audio = AudioEngine.shared
    @ObservedObject private var superwall = SuperwallService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var customMinutesText = ""
    @State private var isCustomMinutesInvalid = false

    /// Non-subscribers always use the default fade, so that's what the control shows them.
    private var displayedFadeSeconds: Double {
        superwall.hasPlus ? audio.timerFadeSeconds : TimerRules.defaultFadeSeconds
    }

    private let presets = [5, 15, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    ForEach(presets, id: \.self) { minutes in
                        Button("\(minutes) min") {
                            let fade = SuperwallService.shared.hasPlus
                                ? audio.timerFadeSeconds
                                : TimerRules.defaultFadeSeconds
                            audio.setTimer(minutes: minutes, fadeSeconds: fade)
                            dismiss()
                        }
                    }
                    HStack {
                        TextField("Custom minutes", text: $customMinutesText)
                            .keyboardType(.numberPad)
                            .accessibilityLabel("Custom minutes")
                        Button("Start") {
                            guard let minutes = Int(customMinutesText) else { return }
                            // Out-of-range values keep the sheet open with an error instead of silently closing.
                            guard TimerRules.durationSeconds(minutes: minutes) != nil else {
                                isCustomMinutesInvalid = true
                                return
                            }
                            SuperwallService.shared.gate(.customTimer) {
                                audio.setTimer(minutes: minutes, fadeSeconds: displayedFadeSeconds)
                                dismiss()
                            }
                        }
                        .disabled(Int(customMinutesText) == nil)
                    }
                    .onChange(of: customMinutesText) { isCustomMinutesInvalid = false }
                    if isCustomMinutesInvalid {
                        Text("Enter a value between \(TimerRules.minMinutes) and \(TimerRules.maxMinutes) minutes.")
                            .font(.essenceBodySmall)
                            .foregroundStyle(.red)
                    }
                }
                Section("Fade out") {
                    if superwall.hasPlus {
                        fadeSlider(value: $audio.timerFadeSeconds)
                    } else {
                        // Shown as a locked preview: one tap registers `custom_timer` once and never changes the value.
                        Button {
                            superwall.gate(.customTimer) {}
                        } label: {
                            HStack {
                                fadeSlider(value: .constant(TimerRules.defaultFadeSeconds))
                                    .allowsHitTesting(false)
                                OrantePlusBadge()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Fade-out duration")
                        .accessibilityValue("\(Int(TimerRules.defaultFadeSeconds))s")
                        .accessibilityHint("Requires Orante+")
                    }
                    Text(displayedFadeSeconds == 0 ? "Stops abruptly, no fade" : "\(Int(displayedFadeSeconds))s volume fade before stopping")
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
            .navigationTitle(AppLanguage.localized("Sleep timer", defaultValue: "Sleep timer"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func fadeSlider(value: Binding<Double>) -> some View {
        Slider(value: value, in: 0...TimerRules.maxFadeSeconds, step: 5)
            .accessibilityLabel("Fade-out duration")
    }
}

#Preview {
    ZenSoundsTheme { TimerSheetView() }
}
