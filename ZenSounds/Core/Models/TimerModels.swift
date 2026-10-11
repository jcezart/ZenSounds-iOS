import Foundation

/// Mirrors the Android app's `data/PlaybackModels.kt::TimerRules`. Deadlines are expressed in
/// `ProcessInfo.processInfo.systemUptime` seconds (monotonic, immune to wall-clock changes) —
/// the iOS equivalent of Android's `SystemClock.elapsedRealtime()`.
enum TimerRules {
    static let minMinutes = 1
    static let maxMinutes = 1440
    static let defaultFadeSeconds: Double = 10
    static let maxFadeSeconds: Double = 60

    static func durationSeconds(minutes: Int) -> TimeInterval? {
        guard (minMinutes...maxMinutes).contains(minutes) else { return nil }
        return TimeInterval(minutes * 60)
    }

    static func remaining(deadline: TimeInterval, now: TimeInterval) -> TimeInterval {
        max(deadline - now, 0)
    }

    /// Linear fade-out multiplier (1 = full volume, 0 = silent) over the last `fadeSeconds`
    /// before `deadline`. `fadeSeconds == 0` means no fade: full volume until the hard stop.
    static func fadeMultiplier(deadline: TimeInterval, now: TimeInterval, fadeSeconds: Double) -> Double {
        let remaining = remaining(deadline: deadline, now: now)
        guard fadeSeconds > 0 else { return remaining > 0 ? 1 : 0 }
        return min(remaining / fadeSeconds, 1)
    }
}
