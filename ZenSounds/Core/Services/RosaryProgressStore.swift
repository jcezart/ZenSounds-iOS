import Combine
import Foundation

nonisolated struct RosarySavedProgress: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let mysterySet: RosaryMysterySetID
    let currentStepID: String
    let mode: RosaryMode
    let includeFatimaPrayer: Bool
    let updatedAt: Date
}

@MainActor
final class RosaryProgressStore: ObservableObject {
    static let shared = RosaryProgressStore()
    static let schemaVersion = 1
    static let storageKey = "zensounds.rosary.progress.v1"

    @Published private(set) var progress: RosarySavedProgress?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        progress = Self.decode(defaults.data(forKey: Self.storageKey))
    }

    func save(set: RosaryMysterySetID, stepID: String, mode: RosaryMode, includeFatima: Bool, date: Date = Date()) {
        let value = RosarySavedProgress(schemaVersion: Self.schemaVersion, mysterySet: set, currentStepID: stepID, mode: mode, includeFatimaPrayer: includeFatima, updatedAt: date)
        progress = value
        defaults.set(try? JSONEncoder().encode(value), forKey: Self.storageKey)
    }

    func clear() {
        progress = nil
        defaults.removeObject(forKey: Self.storageKey)
    }

    func restoredIndex(in steps: [RosaryStep], saved: RosarySavedProgress) -> Int {
        if let exact = steps.firstIndex(where: { $0.id == saved.currentStepID }) { return exact }
        guard let set = RosaryRepository.shared.mysterySet(saved.mysterySet) else { return 0 }
        let canonical = RosarySequenceBuilder.build(set: set, options: .init(includeFatimaPrayer: true))
        guard let oldIndex = canonical.firstIndex(where: { $0.id == saved.currentStepID }) else { return 0 }
        for candidate in canonical.dropFirst(oldIndex + 1) {
            if let index = steps.firstIndex(where: { $0.id == candidate.id }) { return index }
        }
        return max(steps.count - 1, 0)
    }

    private static func decode(_ data: Data?) -> RosarySavedProgress? {
        guard let data, let decoded = try? JSONDecoder().decode(RosarySavedProgress.self, from: data),
              decoded.schemaVersion == schemaVersion else { return nil }
        return decoded
    }
}
