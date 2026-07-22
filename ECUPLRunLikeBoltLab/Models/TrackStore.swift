import Foundation

@MainActor
final class TrackStore: ObservableObject {
    @Published var presets: [TrackConfiguration] = [] { didSet { save() } }
    private let key = "ecupl.runLikeBolt.presets.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let loaded = try? JSONDecoder().decode([TrackConfiguration].self, from: data) else {
            presets = [TrackConfiguration(name: "示例操场（请改为实际坐标）", corners: [
                Coordinate(latitude: 31.230000, longitude: 121.470000),
                Coordinate(latitude: 31.230000, longitude: 121.470800),
                Coordinate(latitude: 31.230400, longitude: 121.470800),
                Coordinate(latitude: 31.230400, longitude: 121.470000)
            ])]
            return
        }
        presets = loaded
    }

    func save(_ item: TrackConfiguration) {
        if let index = presets.firstIndex(where: { $0.name == item.name }) { presets[index] = item }
        else { presets.append(item) }
    }

    func delete(_ item: TrackConfiguration) { presets.removeAll { $0.id == item.id } }

    private func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
