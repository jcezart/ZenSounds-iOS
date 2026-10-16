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
    @ObservedObject private var superwall = SuperwallService.shared
    @Environment(\.essencePalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Button(action: primaryAction) {
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else if style == .labeled {
                    HStack(spacing: 6) {
                        Label(primaryTitle, systemImage: primaryIcon)
                        if !isActiveVerse { PremiumLockBadge(feature: narrationFeature) }
                    }
                } else {
                    Image(systemName: primaryIcon)
                        .frame(width: 44, height: 44)
                        .overlay(alignment: .topTrailing) {
                            if !isActiveVerse {
                                PremiumLockBadge(feature: narrationFeature)
                                    .scaleEffect(0.8)
                                    .offset(x: 4, y: -2)
                            }
                        }
                }
            }
            .disabled(isPreparing)
            .accessibilityLabel(primaryTitle)
            .accessibilityHint(lockHint)
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

    private var narrationFeature: PremiumFeature { .verseNarration(isDailyWord: isDailyWord) }

    /// The lock is drawn inside a button that has its own label, so VoiceOver gets it as a hint.
    private var lockHint: Text {
        superwall.premiumGate.shouldShowBadge(for: narrationFeature) && !isActiveVerse
            ? Text("Requires Orante+")
            : Text(verbatim: "")
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
            VerseNarrationStarter.start(verse, isDailyWord: isDailyWord)
            return
        }
        switch narration.state {
        case .speaking:
            narration.pause()
        case .paused:
            narration.resume()
        case .stopped:
            VerseNarrationStarter.start(verse, isDailyWord: isDailyWord)
        }
    }
}

/// Single entry point for starting verse narration from any control (buttons and accessibility
/// actions), so every path goes through the `bible_narration` gate unless it's the Daily Word.
enum VerseNarrationStarter {
    static func start(
        _ verse: Verse,
        isDailyWord: Bool,
        gate: PremiumGate? = nil,
        speak: ((Verse) -> Void)? = nil
    ) {
        let speak = speak ?? { BibleNarrationService.shared.speak($0) }
        (gate ?? SuperwallService.shared.premiumGate).gate(
            .verseNarration(isDailyWord: isDailyWord),
            parameters: [
                "book": verse.book,
                "chapter": String(verse.chapter)
            ]
        ) {
            speak(verse)
        }
    }
}
