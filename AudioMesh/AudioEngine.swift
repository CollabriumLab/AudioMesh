import CoreAudio
import Foundation
import os.log

private let _oslog = OSLog(subsystem: "com.collabrium.audiomesh", category: "AudioEngine")
private func debugLog(_ msg: String) {
    os_log("%{public}@", log: _oslog, type: .default, msg)
}

private let sysObject = AudioObjectID(kAudioObjectSystemObject)

class AudioEngine {
    static let shared = AudioEngine()

    // Multi-output device
    private var multiDeviceID: AudioObjectID = 0
    private var originalDefaultDeviceID: AudioDeviceID?
    private var listenerBlock: (@convention(block) (UInt32, UnsafePointer<AudioObjectPropertyAddress>) -> Void)?
    var onDeviceListChanged: (() -> Void)?

    deinit {
        stopMonitoring()
        stopGraph()
    }

    var isRunning: Bool { multiDeviceID != 0 }

    // Sub-device tracking for per-device volume control
    private var subDeviceIDs: [AudioDeviceID] = []

    // MARK: - Public API

    func startGraph(devices: [AudioDeviceInfo]) throws {
        debugLog("startGraph called with \(devices.count) devices")
        guard !devices.isEmpty else {
            debugLog("No devices provided")
            throw AudioError.invalidDevice
        }
        if isRunning {
            debugLog("Already running, stopping first")
            stopGraph()
        }

        // Destroy any stale device from a previous crash
        destroyStaleDevice()

        originalDefaultDeviceID = getSystemDefaultOutputDevice()
        subDeviceIDs = devices.map { $0.id }

        for d in devices {
            debugLog("Selected device: ID=\(d.id) name='\(d.name)'")
        }

        let uid = "com.collabrium.audiomesh.\(UUID().uuidString)"
        let name = "AudioMesh Multi-Output"

        guard let masterUID = getDeviceUID(id: devices[0].id) else { throw AudioError.invalidDevice }

        let subDevices: [[String: Any]] = devices.compactMap { d in
            guard let uid = getDeviceUID(id: d.id) else { return nil }
            return [
                kAudioSubDeviceUIDKey: uid,
                kAudioSubDeviceDriftCompensationKey: kCFBooleanTrue as Any
            ]
        }
        guard subDevices.count == devices.count else { throw AudioError.invalidDevice }

        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: name,
            kAudioAggregateDeviceUIDKey: uid,
            kAudioAggregateDeviceSubDeviceListKey: subDevices,
            kAudioAggregateDeviceMasterSubDeviceKey: masterUID,
            kAudioAggregateDeviceIsStackedKey: kCFBooleanTrue as Any,
            kAudioAggregateDeviceIsPrivateKey: kCFBooleanFalse as Any,
        ]

        var deviceID: AudioObjectID = 0
        let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &deviceID)
        guard status == noErr else {
            debugLog("AudioHardwareCreateAggregateDevice failed: \(status)")
            throw AudioError.setupFailed
        }

        multiDeviceID = deviceID
        debugLog("Multi-output device created: \(deviceID)")

        // Set as default output
        if setSystemDefaultOutput(deviceID: deviceID) {
            debugLog("Multi-output device set as default")
        } else {
            debugLog("FAILED to set multi-output device as default")
        }

        // Save UID so we can destroy it later
        multiDeviceUID = uid
    }

    private var multiDeviceUID: String?

    func stopGraph() {
        guard multiDeviceID != 0 else {
            debugLog("stopGraph called but not running")
            return
        }
        debugLog("Stopping graph, deviceID=\(multiDeviceID)")

        let origID = originalDefaultDeviceID

        // Destroy the aggregate device first so CoreAudio reverts routing
        AudioHardwareDestroyAggregateDevice(multiDeviceID)
        debugLog("Multi-output device destroyed")

        // Now restore original default output
        if let id = origID {
            Thread.sleep(forTimeInterval: 0.2)
            _ = setSystemDefaultOutput(deviceID: id)
        }
        multiDeviceID = 0
        multiDeviceUID = nil
        originalDefaultDeviceID = nil
        subDeviceIDs = []
    }

    private func destroyStaleDevice() {
        guard let ids = getDeviceIDs() else {
            debugLog("destroyStaleDevice: couldn't get device IDs")
            return
        }
        debugLog("destroyStaleDevice: checking \(ids.count) devices")
        for d in ids {
            if let uid = getDeviceUID(id: d), uid.hasPrefix("com.collabrium.audiomesh.") {
                AudioHardwareDestroyAggregateDevice(d)
                debugLog("Stale device \(uid) destroyed")
            }
        }
    }

    func setVolume(deviceIndex: Int, volume: Float) {
        let clamped = min(max(volume, 0), 1)
        guard deviceIndex < subDeviceIDs.count else { return }
        setDeviceVolume(deviceID: subDeviceIDs[deviceIndex], volume: clamped)
    }

    func setMasterVolume(volume: Float) {
        let clamped = min(max(volume, 0), 1)
        if multiDeviceID != 0 {
            setDeviceVolume(deviceID: multiDeviceID, volume: clamped)
        }
        for id in subDeviceIDs {
            setDeviceVolume(deviceID: id, volume: clamped)
        }
    }

    private func setDeviceVolume(deviceID: AudioDeviceID, volume: Float32) {
        let clamped = min(max(volume, 0), 1)
        debugLog("setDeviceVolume id=\(deviceID) vol=\(clamped)")

        for elem: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: elem
            )
            if AudioObjectHasProperty(deviceID, &addr) {
                var cv = clamped
                AudioObjectSetPropertyData(deviceID, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &cv)
            }
        }
    }

    // MARK: - Device Enumeration

    func getAllOutputDevices() -> [AudioDeviceInfo] {
        guard let ids = getDeviceIDs() else { return [] }
        return ids.compactMap { getDeviceInfo(id: $0) }.filter { $0.hasOutput && !$0.name.isEmpty }
    }

    private func getDeviceIDs() -> [AudioDeviceID]? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(sysObject, &address, 0, nil, &size)
        guard status == noErr else { return nil }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(sysObject, &address, 0, nil, &size, &devices)
        guard status == noErr else { return nil }
        return devices
    }

    private func getDeviceInfo(id: AudioDeviceID) -> AudioDeviceInfo? {
        guard let name = getDeviceName(id: id), let uid = getDeviceUID(id: id) else { return nil }
        let rate = getDeviceSampleRate(id: id) ?? 0
        let transport = getDeviceTransportType(id: id)
        let hasOutput = deviceHasOutput(id: id)
        return AudioDeviceInfo(id: id, name: name, uid: uid, sampleRate: rate, transportType: transport, hasOutput: hasOutput)
    }

    private func getDeviceName(id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceNameCFString, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name)
        guard status == noErr, let cf = name else { return nil }
        return cf.takeRetainedValue() as String
    }

    private func getDeviceUID(id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &uid)
        guard status == noErr, let cf = uid else { return nil }
        return cf.takeRetainedValue() as String
    }

    private func getDeviceSampleRate(id: AudioDeviceID) -> Float64? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyNominalSampleRate, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &rate)
        return status == noErr ? rate : nil
    }

    private func getDeviceTransportType(id: AudioDeviceID) -> AudioDeviceInfo.TransportType {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var type: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &type)
        guard status == noErr else { return .unknown }
        return AudioDeviceInfo.TransportType.from(type)
    }

    private func deviceHasOutput(id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
        guard status == noErr, size > 0 else { return false }
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { ptr.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr) == noErr else { return false }
        for i in 0..<UnsafeMutableAudioBufferListPointer(ptr.assumingMemoryBound(to: AudioBufferList.self)).count {
            if UnsafeMutableAudioBufferListPointer(ptr.assumingMemoryBound(to: AudioBufferList.self))[i].mNumberChannels > 0 { return true }
        }
        return false
    }

    // MARK: - System Default

    private func setSystemDefaultOutput(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id = deviceID
        for attempt in 0..<30 {
            let status = AudioObjectSetPropertyData(sysObject, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
            if status == noErr {
                if getSystemDefaultOutputDevice() == deviceID { return true }
            } else {
                debugLog("setSystemDefaultOutput attempt \(attempt): \(status)")
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        debugLog("setSystemDefaultOutput failed after 30 attempts")
        return false
    }

    private func getSystemDefaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(sysObject, &address, 0, nil, &size, &id)
        return status == noErr ? id : nil
    }

    // MARK: - Monitoring

    func startMonitoring() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let block: (@convention(block) (UInt32, UnsafePointer<AudioObjectPropertyAddress>) -> Void) = { [weak self] _, _ in
            DispatchQueue.main.async { self?.onDeviceListChanged?() }
        }
        listenerBlock = block
        AudioObjectAddPropertyListenerBlock(sysObject, &address, .main, block)
    }

    func stopMonitoring() {
        guard let block = listenerBlock else { return }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectRemovePropertyListenerBlock(sysObject, &address, .main, block)
        listenerBlock = nil
    }
}

enum AudioError: Error, LocalizedError {
    case invalidDevice
    case noCommonSampleRate
    case apiNotAvailable
    case setupFailed
    case blackholeNotInstalled

    var errorDescription: String? {
        switch self {
        case .invalidDevice: return "Invalid or missing audio device"
        case .noCommonSampleRate: return "No compatible sample rate found"
        case .apiNotAvailable: return "CoreAudio API not available"
        case .setupFailed: return "Audio setup failed"
        case .blackholeNotInstalled:
            return "BlackHole not found. Install BlackHole from https://github.com/ExistentialAudio/BlackHole and ensure it's enabled in Audio MIDI Setup."
        }
    }
}
