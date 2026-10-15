import CoreGraphics
import Foundation

nonisolated enum RosaryMysterySetID: String, Codable, CaseIterable, Identifiable, Sendable {
    case joyful, luminous, sorrowful, glorious
    var id: String { rawValue }
}

nonisolated struct RosaryLocalizedText: Codable, Equatable, Sendable {
    let pt: String
    let en: String
    func text(for language: BibleLanguage) -> String { language == .pt ? pt : en }
}

nonisolated struct RosaryPrayer: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let pt: String
    let en: String
    let source: String
    func text(for language: BibleLanguage) -> String { language == .pt ? pt : en }
}

nonisolated struct RosaryBibleReference: Codable, Equatable, Sendable {
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int
}

nonisolated struct RosaryMystery: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let number: Int
    let name: RosaryLocalizedText
    let meditation: RosaryLocalizedText
    let reference: RosaryBibleReference?
}

nonisolated struct RosaryMysterySet: Codable, Identifiable, Equatable, Sendable {
    let id: RosaryMysterySetID
    let name: RosaryLocalizedText
    let mysteries: [RosaryMystery]
}

nonisolated enum RosaryStage: String, Codable, Sendable { case opening, decade, closing }
nonisolated enum RosaryPrayerKind: String, Codable, Sendable {
    case signOfCross, creed, ourFather, hailMary, gloryBe, fatima, hailHolyQueen, finalPrayer, announcement
}
nonisolated enum RosaryMode: String, Codable, CaseIterable, Sendable { case manual, guided }

nonisolated struct RosaryStep: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let stage: RosaryStage
    let prayer: RosaryPrayerKind
    let decade: Int?
    let mysteryID: String?
    let position: Int?
    let positionTotal: Int?
    let beadID: String
}

nonisolated struct RosarySequenceOptions: Equatable, Sendable {
    var includeFatimaPrayer = true
}

nonisolated enum RosarySequenceBuilder {
    static func build(set: RosaryMysterySet, options: RosarySequenceOptions = .init()) -> [RosaryStep] {
        var steps: [RosaryStep] = [
            step("opening.signOfCross", .opening, .signOfCross, bead: "crucifix"),
            step("opening.creed", .opening, .creed, bead: "crucifix"),
            step("opening.ourFather", .opening, .ourFather, bead: "pendant.large.1"),
        ]
        for index in 1...3 {
            steps.append(step("opening.hailMary.\(index)", .opening, .hailMary, position: index, total: 3, bead: "pendant.small.\(index)"))
        }
        steps.append(step("opening.gloryBe", .opening, .gloryBe, bead: "pendant.link"))

        for decade in 1...5 {
            let mystery = set.mysteries[decade - 1]
            let largeBead = decade == 1 ? "pendant.large.2" : "loop.large.\(decade)"
            steps.append(step("decade.\(decade).announcement", .decade, .announcement, decade: decade, mystery: mystery.id, bead: largeBead))
            steps.append(step("decade.\(decade).ourFather", .decade, .ourFather, decade: decade, mystery: mystery.id, bead: largeBead))
            for index in 1...10 {
                steps.append(step("decade.\(decade).hailMary.\(index)", .decade, .hailMary, decade: decade, mystery: mystery.id, position: index, total: 10, bead: "loop.\(decade).small.\(index)"))
            }
            steps.append(step("decade.\(decade).gloryBe", .decade, .gloryBe, decade: decade, mystery: mystery.id, bead: "loop.\(decade).link"))
            if options.includeFatimaPrayer {
                steps.append(step("decade.\(decade).fatima", .decade, .fatima, decade: decade, mystery: mystery.id, bead: "loop.\(decade).link"))
            }
        }
        steps += [
            step("closing.hailHolyQueen", .closing, .hailHolyQueen, bead: "medal"),
            step("closing.finalPrayer", .closing, .finalPrayer, bead: "medal"),
            step("closing.signOfCross", .closing, .signOfCross, bead: "crucifix"),
        ]
        return steps
    }

    private static func step(_ id: String, _ stage: RosaryStage, _ prayer: RosaryPrayerKind, decade: Int? = nil, mystery: String? = nil, position: Int? = nil, total: Int? = nil, bead: String) -> RosaryStep {
        RosaryStep(id: id, stage: stage, prayer: prayer, decade: decade, mysteryID: mystery, position: position, positionTotal: total, beadID: bead)
    }
}

nonisolated enum MysterySchedule {
    static func suggestedSet(for date: Date, calendar: Calendar = .current) -> RosaryMysterySetID {
        switch calendar.component(.weekday, from: date) {
        case 2, 7: .joyful
        case 3, 6: .sorrowful
        case 4, 1: .glorious
        default: .luminous
        }
    }
}

nonisolated enum RosaryNavigationRules {
    static func nextIndex(current: Int, count: Int) -> Int? { current + 1 < count ? current + 1 : nil }
    static func previousIndex(current: Int) -> Int? { current > 0 ? current - 1 : nil }
    static func firstIndex(for beadID: String, in steps: [RosaryStep]) -> Int? { steps.firstIndex { $0.beadID == beadID } }
}

nonisolated enum RosaryBeadProgress: Equatable, Sendable {
    case pending
    case completed
    case current
}

nonisolated enum RosaryVisualRules {
    /// The physical loop contains five groups of ten small beads, separated by
    /// the four large beads that begin decades two through five.
    static var loopBeadIDs: [String] {
        var result: [String] = []
        for decade in 1...5 {
            if decade > 1 {
                result.append("loop.large.\(decade)")
            }
            result.append(contentsOf: (1...10).map { "loop.\(decade).small.\($0)" })
        }
        return result
    }

    private static let loopBeadCount = loopBeadIDs.count

    /// Ellipse that carries the loop beads, proportional to the diagram's size so it adapts to every iPhone width.
    static func loopFrame(in size: CGSize) -> CGRect {
        let radiusX = size.width * 0.40, radiusY = size.height * 0.26
        let center = CGPoint(x: size.width / 2, y: size.height * 0.34)
        return CGRect(x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2)
    }

    /// Point on the loop for a (possibly fractional) bead index, starting at the top and going clockwise.
    static func loopPoint(at index: Double, in size: CGSize) -> CGPoint {
        let frame = loopFrame(in: size)
        let angle = index / Double(loopBeadCount) * Double.pi * 2 - Double.pi / 2
        return CGPoint(x: frame.midX + frame.width / 2 * cos(angle), y: frame.midY + frame.height / 2 * sin(angle))
    }

    /// Center of a decade's tap target: the middle of its ten small beads on the loop.
    static func decadeButtonCenter(decade: Int, in size: CGSize) -> CGPoint {
        let firstSmallBead = (decade - 1) * 11
        return loopPoint(at: Double(firstSmallBead) + 4.5, in: size)
    }

    static func progress(for beadID: String, in steps: [RosaryStep], currentIndex: Int) -> RosaryBeadProgress {
        let indexes = steps.indices.filter { steps[$0].beadID == beadID }
        guard !indexes.isEmpty else { return .pending }
        if indexes.contains(currentIndex) { return .current }

        // Some physical pieces carry more than one prayer, and the crucifix is
        // used again at the very end. Once its first prayer was passed it must
        // remain visually completed until it becomes current again.
        if let first = indexes.first, first < currentIndex { return .completed }
        return .pending
    }
}
