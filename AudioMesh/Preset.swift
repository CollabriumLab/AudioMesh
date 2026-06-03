import Foundation

struct Preset: Identifiable, Codable {
    let id: UUID
    var name: String
    var deviceUIDs: [String]
    var volumes: [String: Float]
    var latencyOffsets: [String: Int]
    var masterVolume: Float
    var autoSync: Bool

    init(id: UUID = UUID(), name: String, deviceUIDs: [String], volumes: [String: Float], latencyOffsets: [String: Int] = [:], masterVolume: Float, autoSync: Bool = false) {
        self.id = id
        self.name = name
        self.deviceUIDs = deviceUIDs
        self.volumes = volumes
        self.latencyOffsets = latencyOffsets
        self.masterVolume = masterVolume
        self.autoSync = autoSync
    }
}

@Observable
final class PresetManager {
    var presets: [Preset] = []

    private let defaults = UserDefaults.standard
    private let presetsKey = "savedPresets"

    init() {
        load()
    }

    // MARK: - Save Current

    func saveCurrent(name: String, deviceUIDs: [String], volumes: [String: Float], latencyOffsets: [String: Int], masterVolume: Float, autoSync: Bool) {
        let preset = Preset(
            name: name,
            deviceUIDs: deviceUIDs,
            volumes: volumes,
            latencyOffsets: latencyOffsets,
            masterVolume: masterVolume,
            autoSync: autoSync
        )
        presets.append(preset)
        save()
    }

    func update(_ preset: Preset) {
        guard let i = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[i] = preset
        save()
    }

    func delete(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        save()
    }

    // MARK: - Auto-detect

    func matchingPreset(for deviceUIDs: Set<String>) -> Preset? {
        presets.first { $0.autoSync && Set($0.deviceUIDs).isSubset(of: deviceUIDs) }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: presetsKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: presetsKey),
              let decoded = try? JSONDecoder().decode([Preset].self, from: data) else {
            return
        }
        presets = decoded
    }
}
