import SwiftUI
import CoreAudio

struct DeviceSlot: Identifiable {
    let id: UUID
    var device: AudioDeviceInfo?
    var volume: Float
    var latencyOffset: Int // milliseconds, -1000 to +1000
}

@Observable
@MainActor
final class AudioMeshManager {
    var availableDevices: [AudioDeviceInfo] = []
    var deviceSlots: [DeviceSlot] = []
    var isActive: Bool = false
    var statusMessage: String = "Ready"
    var isError: Bool = false
    var masterVolume: Float = 0.5
    var isMuted: Bool = false
    var isDucking: Bool = false
    var duckLevel: Float = 0.3
    var duckingEnabled: Bool = false
    var duckDuration: TimeInterval = 3.0
    var autoDuckingEnabled: Bool = false

    let engine = AudioEngine.shared
    let batteryMonitor = BluetoothBatteryMonitor()
    let presetManager = PresetManager()
    private let defaults = UserDefaults.standard
    private let devVolsKey = "deviceVolumes"
    private let slotOrderKey = "slotOrder"
    private let masterVolKey = "masterVolume"
    private let duckEnabledKey = "duckingEnabled"
    private let duckLevelKey = "duckLevel"
    private let duckDurationKey = "duckDuration"
    private let duckAutoKey = "autoDuckingEnabled"
    private let latencyOffsetKey = "latencyOffsets"
    @ObservationIgnored private var preMuteVolume: Float = 0.5
    @ObservationIgnored private var devVols: [String: Float] = [:]
    @ObservationIgnored private var lastConnectedDeviceUIDs: Set<String> = []
    @ObservationIgnored private var userStoppedSync = false
    var latencyOffsets: [String: Int] = [:]

    init() {
        engine.onDeviceListChanged = { [weak self] in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }
        engine.startMonitoring()
        batteryMonitor.startMonitoring()
        refreshDevices()
        loadSaved()
        setupDucking()
    }

    // MARK: - Device Slots

    func addSlot() {
        deviceSlots.append(DeviceSlot(id: UUID(), device: nil, volume: masterVolume, latencyOffset: 0))
    }

    func removeSlot(at index: Int) {
        guard index < deviceSlots.count else { return }
        if isActive { stop() }
        deviceSlots.remove(at: index)
    }

    // MARK: - Refresh

    func refreshDevices() {
        let all = engine.getAllOutputDevices()
        let newUIDs = Set(all.map(\.uid))
        let devicesChanged = newUIDs != lastConnectedDeviceUIDs
        lastConnectedDeviceUIDs = newUIDs
        availableDevices = all

        for i in deviceSlots.indices {
            if let d = deviceSlots[i].device, !all.contains(d) {
                deviceSlots[i].device = all.first { $0.uid == d.uid }
            }
        }

        if isActive {
            let missing = deviceSlots.filter { $0.device == nil }
            if !missing.isEmpty {
                statusMessage = "Device disconnected"
                stop()
                return
            }
        }

        if devicesChanged {
            userStoppedSync = false
            checkAutoPresets()
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
                guard let self, engine.isRunning else { return }
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
        userStoppedSync = true
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

    // MARK: - Ducking

    @ObservationIgnored private var preDuckVolume: Float = 0.5
    @ObservationIgnored private var duckRestoreTimer: Timer?

    func startDucking() {
        guard !isDucking, duckingEnabled else { return }
        preDuckVolume = masterVolume
        isDucking = true
        let target = min(masterVolume, duckLevel)
        updateMasterVolume(target)

        duckRestoreTimer?.invalidate()
        duckRestoreTimer = Timer.scheduledTimer(withTimeInterval: duckDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.stopDucking()
            }
        }
    }

    func stopDucking() {
        guard isDucking else { return }
        isDucking = false
        duckRestoreTimer?.invalidate()
        duckRestoreTimer = nil
        updateMasterVolume(preDuckVolume)
    }

    private func setupDucking() {
        engine.onAlertDeviceActivityChanged = { [weak self] running in
            guard let self else { return }
            Task { @MainActor in
                guard self.autoDuckingEnabled, self.duckingEnabled else { return }
                if running {
                    self.startDucking()
                }
            }
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        if isActive { stop() }
        duckRestoreTimer?.invalidate()
        duckRestoreTimer = nil
        batteryMonitor.stopMonitoring()
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
        defaults.set(duckingEnabled, forKey: duckEnabledKey)
        defaults.set(Double(duckLevel), forKey: duckLevelKey)
        defaults.set(duckDuration, forKey: duckDurationKey)
        defaults.set(autoDuckingEnabled, forKey: duckAutoKey)

        for slot in deviceSlots {
            if let uid = slot.device?.uid {
                latencyOffsets[uid] = slot.latencyOffset
            }
        }
        defaults.set(latencyOffsets, forKey: latencyOffsetKey)
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

        duckingEnabled = defaults.bool(forKey: duckEnabledKey)
        if defaults.object(forKey: duckLevelKey) != nil {
            duckLevel = Float(defaults.double(forKey: duckLevelKey))
        }
        if defaults.object(forKey: duckDurationKey) != nil {
            duckDuration = defaults.double(forKey: duckDurationKey)
        }
        autoDuckingEnabled = defaults.bool(forKey: duckAutoKey)
        if let saved = defaults.dictionary(forKey: latencyOffsetKey) as? [String: Int] {
            latencyOffsets = saved
        }

        let savedUIDs = defaults.array(forKey: slotOrderKey) as? [String] ?? []
        if savedUIDs.isEmpty {
            deviceSlots = [
                DeviceSlot(id: UUID(), device: nil, volume: masterVolume, latencyOffset: 0),
                DeviceSlot(id: UUID(), device: nil, volume: masterVolume, latencyOffset: 0),
            ]
            return
        }

        deviceSlots = []
        for uid in savedUIDs where !uid.isEmpty {
            let device = availableDevices.first(where: { $0.uid == uid })
            let vol = devVols[uid] ?? masterVolume
            let lat = latencyOffsets[uid] ?? 0
            deviceSlots.append(DeviceSlot(id: UUID(), device: device, volume: vol > 0 ? vol : masterVolume, latencyOffset: lat))
        }
        while deviceSlots.count < 2 {
            deviceSlots.append(DeviceSlot(id: UUID(), device: nil, volume: masterVolume, latencyOffset: 0))
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

    // MARK: - Battery

    func battery(for deviceName: String, uid: String? = nil) -> DeviceBatteryInfo? {
        if let uid {
            let btAddress = uid
                .replacingOccurrences(of: "MAC:", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "BT:", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Bluetooth_", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            let isMac = btAddress.range(of: #"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"#, options: .regularExpression) != nil
            if isMac, let match = batteryMonitor.deviceBatteries[btAddress] {
                return match
            }
        }
        return batteryMonitor.deviceBatteries.first { k, _ in
            k.caseInsensitiveCompare(deviceName) == .orderedSame
        }?.value
    }

    // MARK: - Presets

    func saveCurrentPreset(name: String, autoSync: Bool = false) {
        let uids = deviceSlots.compactMap { $0.device?.uid }
        guard uids.count >= 2 else { return }
        var vols: [String: Float] = [:]
        var lats: [String: Int] = [:]
        for slot in deviceSlots {
            if let uid = slot.device?.uid {
                vols[uid] = slot.volume
                lats[uid] = slot.latencyOffset
            }
        }
        presetManager.saveCurrent(name: name, deviceUIDs: uids, volumes: vols, latencyOffsets: lats, masterVolume: masterVolume, autoSync: autoSync)
    }

    func applyPreset(_ preset: Preset) {
        var slots: [DeviceSlot] = []

        // Try to find each device in the preset by UID
        for uid in preset.deviceUIDs {
            if let device = availableDevices.first(where: { $0.uid == uid }) {
                let vol = preset.volumes[uid] ?? preset.masterVolume
                let lat = preset.latencyOffsets[uid] ?? 0
                slots.append(DeviceSlot(id: UUID(), device: device, volume: vol, latencyOffset: lat))
                // Also update caches
                devVols[uid] = vol
                latencyOffsets[uid] = lat
            }
        }

        // Fill remaining slots with empty ones (minimum 2)
        while slots.count < 2 {
            slots.append(DeviceSlot(id: UUID(), device: nil, volume: preset.masterVolume, latencyOffset: 0))
        }

        deviceSlots = slots
        masterVolume = preset.masterVolume

        if preset.autoSync && slots.allSatisfy({ $0.device != nil }) {
            sync()
        }
    }

    private func checkAutoPresets() {
        guard !isActive, !userStoppedSync else { return }
        guard presetManager.presets.contains(where: { $0.autoSync }) else { return }
        let connectedUIDs = Set(availableDevices.map(\.uid))
        guard let preset = presetManager.matchingPreset(for: connectedUIDs) else { return }
        applyPreset(preset)
    }
}
