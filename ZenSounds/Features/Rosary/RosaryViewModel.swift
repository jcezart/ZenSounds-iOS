import Combine
import Foundation

@MainActor
final class RosaryGuidedController: ObservableObject {
    enum State: Equatable { case idle, preparing, speaking, paused, completed }

    @Published private(set) var state: State = .idle
    private let narration: RosaryNarrating
    private var generation = OperationGeneration()
    private var currentStepID: String?
    private var currentText = ""
    private var currentLanguage: BibleLanguage = .en
    var onStepFinished: ((String) -> Void)?

    init(narration: RosaryNarrating? = nil) { self.narration = narration ?? BibleNarrationService.shared }

    func start(stepID: String, text: String, language: BibleLanguage) {
        currentStepID = stepID
        currentText = text
        currentLanguage = language
        let token = generation.begin()
        state = .preparing
        narration.speakRosary(text: text, itemID: "rosary:\(stepID)", language: language) { [weak self] in
            guard let self, generation.isCurrent(token) else { return }
            state = .speaking
        } onFinish: { [weak self] itemID in
            guard let self, generation.isCurrent(token), itemID == "rosary:\(stepID)" else { return }
            state = .speaking
            onStepFinished?(stepID)
        } onCancel: { [weak self] in
            guard let self, generation.isCurrent(token), state != .idle, state != .completed else { return }
            state = .paused
        } onPause: { [weak self] in
            guard let self, generation.isCurrent(token) else { return }
            state = .paused
        }
    }

    func pause() {
        guard state == .speaking || state == .preparing else { return }
        if state == .preparing {
            generation.invalidate()
            narration.stop()
            state = .paused
        } else {
            narration.pause()
            // Reflect the requested transport state immediately. The delegate
            // callback still confirms it, but the button must not remain as
            // “Pause” while the synthesizer finishes pausing.
            state = .paused
        }
    }
    func resume() {
        guard state == .paused else { return }
        if narration.state == .paused { state = .preparing; narration.resume(); state = .speaking }
        else if let currentStepID { start(stepID: currentStepID, text: currentText, language: currentLanguage) }
    }
    func invalidateSpeech(keepingPosition: Bool = true) {
        generation.invalidate(); narration.stop(); state = keepingPosition ? .paused : .idle
    }
    func complete() { generation.invalidate(); narration.stop(); state = .completed }
    func reset() { generation.invalidate(); narration.stop(); currentStepID = nil; currentText = ""; state = .idle }
}

@MainActor
final class RosaryViewModel: ObservableObject {
    @Published var mysterySetID: RosaryMysterySetID
    @Published var includeFatimaPrayer: Bool
    @Published var mode: RosaryMode
    @Published private(set) var currentIndex = 0
    @Published private(set) var isCompleted = false
    @Published var isChoosingSet = false
    @Published var pendingSet: RosaryMysterySetID?
    @Published var showsRestartConfirmation = false

    let repository: RosaryRepository
    let progressStore: RosaryProgressStore
    let guided: RosaryGuidedController
    private let entitlements: any EntitlementProviding
    private let premiumGate: PremiumGate
    private var guidedStateObservation: AnyCancellable?
    private let recordRecent: (RecentItem) -> Void

    init(repository: RosaryRepository? = nil, progressStore: RosaryProgressStore? = nil, guided: RosaryGuidedController? = nil, entitlements: (any EntitlementProviding)? = nil, premiumGate: PremiumGate? = nil, recordRecent: ((RecentItem) -> Void)? = nil, date: Date = Date(), calendar: Calendar = .current) {
        let repository = repository ?? .shared
        let progressStore = progressStore ?? .shared
        let guided = guided ?? RosaryGuidedController()
        let entitlements = entitlements ?? SuperwallService.shared
        self.repository = repository
        self.progressStore = progressStore
        self.guided = guided
        self.entitlements = entitlements
        self.premiumGate = premiumGate ?? SuperwallService.shared.premiumGate
        self.recordRecent = recordRecent ?? { UserPreferencesStore.shared.recordRecent($0) }
        if let saved = progressStore.progress {
            mysterySetID = saved.mysterySet
            includeFatimaPrayer = saved.includeFatimaPrayer
            // A guided session saved while subscribed reopens in Manual mode (same position) without Orante+.
            mode = saved.mode == .guided && !Self.canUseGuided(entitlements) ? .manual : saved.mode
        } else {
            mysterySetID = MysterySchedule.suggestedSet(for: date, calendar: calendar)
            includeFatimaPrayer = true
            mode = .manual
        }
        if let saved = progressStore.progress { currentIndex = progressStore.restoredIndex(in: steps, saved: saved) }
        guided.onStepFinished = { [weak self] id in self?.guidedDidFinish(stepID: id) }
        guidedStateObservation = guided.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var mysterySet: RosaryMysterySet {
        repository.mysterySet(mysterySetID) ?? repository.mysterySets.first ?? RosaryMysterySet(id: .joyful, name: .init(pt: "Mistérios Gozosos", en: "Joyful Mysteries"), mysteries: [])
    }
    var steps: [RosaryStep] { RosarySequenceBuilder.build(set: mysterySet, options: .init(includeFatimaPrayer: includeFatimaPrayer)) }
    var currentStep: RosaryStep? { steps.indices.contains(currentIndex) ? steps[currentIndex] : nil }
    var hasProgress: Bool { currentIndex > 0 || progressStore.progress != nil }

    func setMode(_ newMode: RosaryMode) {
        if mode == .guided && newMode == .manual { guided.invalidateSpeech() }
        mode = newMode; persist()
    }
    func toggleFatima(_ enabled: Bool) {
        let oldID = currentStep?.id
        if mode == .guided { guided.invalidateSpeech() }
        includeFatimaPrayer = enabled
        if let oldID, let exact = steps.firstIndex(where: { $0.id == oldID }) { currentIndex = exact }
        else if let saved = progressStore.progress { currentIndex = progressStore.restoredIndex(in: steps, saved: saved) }
        persist()
    }
    func requestSet(_ id: RosaryMysterySetID) {
        if hasProgress { pendingSet = id; showsRestartConfirmation = true } else { beginNew(set: id) }
    }
    func confirmSetChange() { if let pendingSet { beginNew(set: pendingSet) }; pendingSet = nil; showsRestartConfirmation = false }
    func beginNew(set: RosaryMysterySetID? = nil) {
        guided.reset(); if let set { mysterySetID = set }; currentIndex = 0; isCompleted = false; progressStore.clear(); persist()
    }
    func previous() {
        guard let previous = RosaryNavigationRules.previousIndex(current: currentIndex) else { return }
        guided.invalidateSpeech(); currentIndex = previous; isCompleted = false; persist()
        speakCurrentIfGuidedAllowed()
    }
    func next() {
        guided.invalidateSpeech()
        recordPrayed()
        guard let next = RosaryNavigationRules.nextIndex(current: currentIndex, count: steps.count) else { complete(); return }
        currentIndex = next; persist()
        speakCurrentIfGuidedAllowed()
    }
    func go(toBead beadID: String) {
        guard let index = RosaryNavigationRules.firstIndex(for: beadID, in: steps) else { return }
        guided.invalidateSpeech(); currentIndex = index; isCompleted = false; persist()
    }
    func guidedPrimaryAction(language: BibleLanguage) {
        switch guided.state {
        case .idle, .completed: speakCurrent(language: language)
        case .preparing, .speaking: guided.pause()
        case .paused: guided.resume()
        }
    }
    func stopGuided() { guided.invalidateSpeech() }
    func languageDidChange() { if mode == .guided { guided.invalidateSpeech() } }

    func spokenText(for step: RosaryStep, language: BibleLanguage) -> String {
        if step.prayer == .announcement, let mystery = repository.mystery(step.mysteryID) {
            return announcement(for: mystery, set: mysterySetID, language: language) + " " + mystery.meditation.text(for: language)
        }
        return repository.prayer(step.prayer)?.text(for: language) ?? ""
    }

    /// Manual Previous/Next in Guided mode only narrate with Orante+; otherwise the Rosary
    /// falls back to Manual mode at the new position instead of speaking.
    private func speakCurrentIfGuidedAllowed() {
        guard mode == .guided else { return }
        guard Self.canUseGuided(entitlements) else {
            // Visible answer for the tap: paywall or the Orante+ notice. A purchase resumes guided mode here.
            mode = .manual; persist()
            premiumGate.gate(.guidedRosary) { [weak self] in
                self?.setMode(.guided)
                self?.speakCurrent()
            }
            return
        }
        speakCurrent()
    }

    private static func canUseGuided(_ entitlements: any EntitlementProviding) -> Bool {
        !PremiumAccessRules.requiresPlus(for: .guidedRosary) || entitlements.hasPlus
    }

    private func speakCurrent(language: BibleLanguage? = nil) {
        guard let step = currentStep else { return }
        let resolvedLanguage = language ?? AppLanguageStore.shared.selection.bibleLanguage
        guided.start(stepID: step.id, text: spokenText(for: step, language: resolvedLanguage), language: resolvedLanguage)
    }
    private func guidedDidFinish(stepID: String) {
        guard currentStep?.id == stepID else { return }
        recordPrayed()
        guard let next = RosaryNavigationRules.nextIndex(current: currentIndex, count: steps.count) else { complete(); return }
        currentIndex = next; persist(); speakCurrent()
    }
    /// Advancing a bead puts this set of mysteries at the top of Search → Recent.
    private func recordPrayed() { recordRecent(.mysteries(mysterySetID)) }
    private func complete() { guided.complete(); isCompleted = true; progressStore.clear() }
    private func persist() {
        guard !isCompleted, let step = currentStep else { return }
        progressStore.save(set: mysterySetID, stepID: step.id, mode: mode, includeFatima: includeFatimaPrayer)
    }

    private func announcement(for mystery: RosaryMystery, set: RosaryMysterySetID, language: BibleLanguage) -> String {
        let ptOrdinals = ["Primeiro", "Segundo", "Terceiro", "Quarto", "Quinto"]
        let enOrdinals = ["First", "Second", "Third", "Fourth", "Fifth"]
        let index = max(0, min(mystery.number - 1, 4))
        if language == .pt {
            let adjective: [RosaryMysterySetID: String] = [.joyful: "Gozoso", .luminous: "Luminoso", .sorrowful: "Doloroso", .glorious: "Glorioso"]
            return "\(ptOrdinals[index]) Mistério \(adjective[set] ?? ""): \(mystery.name.pt)."
        }
        let adjective: [RosaryMysterySetID: String] = [.joyful: "Joyful", .luminous: "Luminous", .sorrowful: "Sorrowful", .glorious: "Glorious"]
        return "The \(enOrdinals[index]) \(adjective[set] ?? "") Mystery: \(mystery.name.en)."
    }
}
