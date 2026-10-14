import SwiftUI

struct VerseNarrationControls: View {
    enum Style {
        case compact
        case labeled
    }

    let verse: Verse
    var isDailyWord = false
    var style: Style = .compact
    var tint: Color? = nil

    @ObservedObject private var narration = BibleNarrationService.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Button(action: primaryAction) {
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else if style == .labeled {
                    Label(primaryTitle, systemImage: primaryIcon)
                } else {
                    Image(systemName: primaryIcon)
                        .frame(width: 44, height: 44)
                }
            }
            .disabled(isPreparing)
            .accessibilityLabel(primaryTitle)
            .accessibilityAddTraits(primaryAccessibilityTraits)

            if isActiveVerse {
                Button(action: narration.stop) {
                    if style == .labeled {
                        Label("Stop", systemImage: "stop.fill")
                    } else {
                        Image(systemName: "stop.fill")
                            .frame(width: 44, height: 44)
                    }
                }
                .accessibilityLabel("Stop reading")
            }
        }
        .foregroundStyle(tint ?? palette.accent)
    }

    private var isActiveVerse: Bool {
        narration.isCurrent(verse)
    }

    private var isPreparing: Bool {
        isActiveVerse && narration.isPreparing
    }

    private var primaryTitle: LocalizedStringKey {
        guard isActiveVerse else { return "Listen" }
        switch narration.state {
        case .speaking:
            return "Pause"
        case .paused:
            return "Continue"
        case .stopped:
            return "Listen"
        }
    }

    private var primaryIcon: String {
        guard isActiveVerse else { return "speaker.wave.2.fill" }
        switch narration.state {
        case .speaking:
            return "pause.fill"
        case .paused:
            return "play.fill"
        case .stopped:
            return "speaker.wave.2.fill"
        }
    }

    private var primaryAccessibilityTraits: AccessibilityTraits {
        isActiveVerse ? [] : .startsMediaSession
    }

    private func primaryAction() {
        guard isActiveVerse else {
            SuperwallService.shared.gate(
                .verseNarration(isDailyWord: isDailyWord),
                parameters: [
                    "book": verse.book,
                    "chapter": String(verse.chapter)
                ]
            ) {
                narration.speak(verse)
            }
            return
        }
        switch narration.state {
        case .speaking:
            narration.pause()
        case .paused:
            narration.resume()
        case .stopped:
            narration.speak(verse)
        }
    }
}
