import Foundation

@MainActor
final class RosaryRepository {
    static let shared = RosaryRepository()

    let prayers: [RosaryPrayer]
    let mysterySets: [RosaryMysterySet]

    init(bundle: Bundle = .main) {
        prayers = Self.load("rosary_prayers", as: [RosaryPrayer].self, bundle: bundle) ?? []
        mysterySets = Self.load("rosary_mysteries", as: [RosaryMysterySet].self, bundle: bundle) ?? []
    }

    func prayer(_ kind: RosaryPrayerKind) -> RosaryPrayer? {
        guard kind != .announcement else { return nil }
        return prayers.first { $0.id == kind.rawValue }
    }

    func mysterySet(_ id: RosaryMysterySetID) -> RosaryMysterySet? { mysterySets.first { $0.id == id } }
    func mystery(_ id: String?) -> RosaryMystery? {
        guard let id else { return nil }
        return mysterySets.lazy.flatMap(\.mysteries).first { $0.id == id }
    }

    private static func load<T: Decodable>(_ name: String, as type: T.Type, bundle: Bundle) -> T? {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
