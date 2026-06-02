import SwiftUI
import Combine

struct DeviceSlot: Identifiable {
    let id: UUID
    var device: AudioDeviceInfo?
    var volume: Float
}

class AudioMeshManager: ObservableObject {
    @Published var availableDevices: [AudioDeviceInfo] = []
    @Published var deviceSlots: [DeviceSlot] = []
    @Published var isActive: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var isError: Bool = false
    @Published var masterVolume: Float = 0.5
    @Published var isMuted: Bool = false

    let engine = AudioEngine.shared
    private let defaults = UserDefaults.standard
    private let devVolsKey = "deviceVolumes"
    private let slotOrderKey = "slotOrder"
    private let masterVolKey = "masterVolume"
    private var preMuteVolume: Float = 0.5
    private var devVols: [String: Float] = [:]

    init() {
        engine.onDeviceListChanged = { [weak self] in
            guard let self else { return }
            self.refreshDevices()
        }
        engine.startMonitoring()
        refreshDevices()
        loadSaved()
    }

    // MARK: - Device Slots

    func addSlot() {
        deviceSlots.append(DeviceSlot(id: UUID(), device: nil, volume: masterVolume))
    }

    func removeSlot(at index: Int) {
        guard deviceSlots.count > 2, index < deviceSlots.count else { return }
        deviceSlots.remove(at: index)
    }

    // MARK: - Refresh

    func refreshDevices() {
        let all = engine.getAllOutputDevices()
        availableDevices = all
        for i in deviceSlots.indices {
            if let d = deviceSlots[i].device, !all.contains(d) {
                deviceSlots[i].device = all.first { $0.uid == d.uid }
            }
        }
    }

    // MARK: - Sync / Stop

    func sync() {
        let devices = deviceSlots.compactMap { $0.device }
        guard devices.count >= 2 else {
            statusMessage = "Select at least 2 devices"
            isError = true
            return
        }
        let unique = Set(devices.map(\.id))
        guard unique.count == devices.count else {
            statusMessage = "All devices must be different"
            isError = true
            return
        }

        do {
            try engine.startGraph(devices: devices)
            statusMessage = "Syncing..."
            isError = false
            // Let CoreAudio settle the aggregate device before setting volumes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                applyAllVolumes()
                isActive = true
                let rate = devices[0].sampleRate
                statusMessage = "Synced (\(Int(rate)) Hz)"
                saveDevices()
            }
        } catch {
            engine.stopGraph()
            isActive = false
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func stop() {
        engine.stopGraph()
        isActive = false
        statusMessage = "Ready"
        isError = false
        saveDevices()
    }

    // MARK: - Volume

    func updateVolume(at index: Int, _ v: Float) {
        guard index < deviceSlots.count else { return }
        deviceSlots[index].volume = v
        if isActive {
            engine.setVolume(deviceIndex: index, volume: v)
        }
    }

    func toggleMute() {
        if isMuted {
            isMuted = false
            updateMasterVolume(preMuteVolume)
        } else {
            preMuteVolume = masterVolume
            isMuted = true
            updateMasterVolume(0)
        }
    }

    func updateMasterVolume(_ v: Float) {
        masterVolume = v
        for i in deviceSlots.indices {
            deviceSlots[i].volume = v
        }
        if isActive {
            engine.setMasterVolume(volume: v)
        }
    }

    private func applyAllVolumes() {
        engine.setMasterVolume(volume: masterVolume)
        for i in deviceSlots.indices {
            if deviceSlots[i].device != nil {
                engine.setVolume(deviceIndex: i, volume: deviceSlots[i].volume)
            }
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        if isActive { stop() }
        engine.stopMonitoring()
    }

    // MARK: - Persistence

    private func saveDevices() {
        // Save volumes by device UID
        for slot in deviceSlots {
            if let uid = slot.device?.uid {
                devVols[uid] = slot.volume
            }
        }
        let saved: [String: Double] = devVols.mapValues { Double($0) }
        defaults.set(saved, forKey: devVolsKey)

        // Save slot order
        let uids = deviceSlots.map { $0.device?.uid ?? "" }
        defaults.set(uids, forKey: slotOrderKey)

        defaults.set(Double(masterVolume), forKey: masterVolKey)
    }

    private func loadSaved() {
        let saved = defaults.dictionary(forKey: devVolsKey) as? [String: Double] ?? [:]
        devVols = saved.mapValues { Float($0) }

        if defaults.object(forKey: masterVolKey) != nil {
            let saved = Float(defaults.double(forKey: masterVolKey))
            masterVolume = saved > 0 ? saved : 0.5
        } else {
            masterVolume = 0.5
        }

        let savedUIDs = defaults.array(forKey: slotOrderKey) as? [String] ?? []
        if savedUIDs.isEmpty {
            deviceSlots = [
                DeviceSlot(id: UUID(), device: nil, volume: masterVolume),
                DeviceSlot(id: UUID(), device: nil, volume: masterVolume),
            ]
            return
        }

        deviceSlots = []
        for uid in savedUIDs where !uid.isEmpty {
            let device = availableDevices.first(where: { $0.uid == uid })
            let vol = devVols[uid] ?? masterVolume
            deviceSlots.append(DeviceSlot(id: UUID(), device: device, volume: vol > 0 ? vol : masterVolume))
        }
        while deviceSlots.count < 2 {
            deviceSlots.append(DeviceSlot(id: UUID(), device: nil, volume: masterVolume))
        }
    }

    func selectDeviceForSlot(at index: Int, device: AudioDeviceInfo?) {
        guard index < deviceSlots.count else { return }
        deviceSlots[index].device = device
        if let uid = device?.uid, let saved = devVols[uid] {
            deviceSlots[index].volume = saved
        } else if device != nil {
            deviceSlots[index].volume = masterVolume
        }
    }
}
