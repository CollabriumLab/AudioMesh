import SwiftUI

// MARK: - Constants

private let bg = Color(red: 0.063, green: 0.078, blue: 0.102)
private let hoverBg = Color(red: 0.15, green: 0.16, blue: 0.18)
private let accent = Color.blue
private let secondary = Color.white.opacity(0.5)
private let divider = Color.white.opacity(0.06)
private let red = Color(red: 1.0, green: 0.23, blue: 0.19)
private let controlFill = Color.white.opacity(0.055)

// MARK: - Content View

struct ContentView: View {
    @Environment(AudioMeshManager.self) private var manager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HeaderView()

                if !manager.deviceSlots.isEmpty {
                    deviceSection
                }

                AddDeviceRow { manager.addSlot() }

                if manager.deviceSlots.filter({ $0.device != nil }).count >= 2 {
                    SyncSection()
                }

                if manager.isActive {
                    MasterVolumeSection()
                    DuckingSection()
                }

                PresetsSection()

                Divider().overlay(Color.white.opacity(0.06))

                StatusBarView()
            }
            .padding(16)
        }
        .frame(minWidth: 580, idealWidth: 620, maxWidth: 700, minHeight: 500, idealHeight: 650)
        .background(bg)
    }

    private var deviceSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(manager.deviceSlots.enumerated()), id: \.element.id) { i, _ in
                DeviceRow(index: i)
                if i < manager.deviceSlots.count - 1 {
                    Divider().overlay(Color.white.opacity(0.04))
                }
            }
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .overlay(Color.white.opacity(0.04))
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Volume Control

struct MeshVolumeControl: View {
    let icon: String
    let value: Float
    let isMuted: Bool
    let isCompact: Bool
    let onChange: (Float) -> Void
    let onMuteToggle: (() -> Void)?

    private var percentText: String {
        isMuted ? "Muted" : "\(Int(round(value * 100)))%"
    }

    private var controlSize: ControlSize {
        isCompact ? .mini : .small
    }

    var body: some View {
        HStack(spacing: isCompact ? 8 : 10) {
            if let onMuteToggle {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.16)) {
                        onMuteToggle()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: isCompact ? 6 : 7)
                            .fill(isMuted ? red.opacity(0.18) : controlFill)
                        Image(systemName: isMuted ? "speaker.slash.fill" : icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isMuted ? red : secondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: isCompact ? 24 : 28, height: isCompact ? 22 : 26)
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 6 : 7)
                            .strokeBorder(isMuted ? red.opacity(0.28) : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .help(isMuted ? "Unmute" : "Mute")
            } else {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(secondary)
                    .frame(width: isCompact ? 14 : 16)
            }

            Slider(
                value: Binding(
                    get: { value },
                    set: onChange
                ),
                in: 0...1
            )
            .controlSize(controlSize)
            .tint(isMuted ? red.opacity(0.7) : accent)
            .opacity(isMuted ? 0.45 : 1)

            Text(percentText)
                .font((isCompact ? Font.caption2 : Font.caption).monospacedDigit())
                .foregroundStyle(isMuted ? red : secondary)
                .frame(width: isCompact ? 44 : 48, alignment: .trailing)
                .lineLimit(1)
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    @Environment(AudioMeshManager.self) private var manager
    let index: Int
    @State private var isHovered = false
    @State private var hoverRemove = false
    @State private var showLatency = false

    private var slot: DeviceSlot? {
        guard index < manager.deviceSlots.count else { return nil }
        return manager.deviceSlots[index]
    }

    private var connectionSummary: String {
        guard let device = slot?.device else { return "" }
        let type = device.isBluetooth ? "Bluetooth" : "Wired"
        let rate = "\(Int(device.sampleRate / 1000)) kHz"
        return "\(type) output  ·  \(rate)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "headphones")
                    .font(.title3)
                    .foregroundStyle(slot?.device != nil ? .white : .white.opacity(0.25))
                    .frame(width: 40, height: 40)
                    .background(controlFill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Menu {
                        ForEach(availableDevices()) { device in
                            Button {
                                manager.selectDeviceForSlot(at: index, device: device)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(device.name)
                                    Spacer()
                                    if slot?.device?.id == device.id {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(accent)
                                    }
                                }
                            }
                        }
                        if slot?.device != nil {
                            Divider()
                            Button("Remove Device") {
                                manager.selectDeviceForSlot(at: index, device: nil)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(slot?.device?.name ?? "Select Audio Device")
                                .font(.body.weight(.medium))
                                .foregroundStyle(slot?.device != nil ? .white : secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .id(slot?.device?.uid ?? "empty-\(index)")

                    if slot?.device != nil {
                        Text(connectionSummary)
                            .font(.caption)
                            .foregroundStyle(secondary)
                    }
                }

                Spacer()

                if slot?.device != nil {
                    HStack(spacing: 10) {
                        if let device = slot?.device {
                            if device.isBluetooth, let battery = manager.battery(for: device.name, uid: device.uid) {
                                BatteryBadge(info: battery)
                            } else {
                                Text(device.isBluetooth ? "BT" : "OUT")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(controlFill, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }

                        if !manager.isActive && manager.deviceSlots.count > 2 {
                            Button {
                                manager.removeSlot(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(hoverRemove ? 0.7 : 0.35))
                            }
                            .buttonStyle(.plain)
                            .help("Remove slot")
                            .onHover { h in hoverRemove = h }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if slot?.device != nil {
                MeshVolumeControl(
                    icon: "speaker.fill",
                    value: slot?.volume ?? 0.5,
                    isMuted: false,
                    isCompact: false,
                    onChange: { manager.updateVolume(at: index, $0) },
                    onMuteToggle: nil
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .padding(.leading, 52)
                .transition(.opacity.combined(with: .move(edge: .top)))

                // Latency offset: collapsible (wired devices only)
                if let device = slot?.device, !device.isBluetooth {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { showLatency.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(secondary)
                            Text("Latency")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(secondary)
                            Spacer()
                            Text(slot.map { $0.latencyOffset >= 0 ? "+\($0.latencyOffset)" : "\($0.latencyOffset)" } ?? "0")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(slot?.latencyOffset == 0 ? secondary : .white)
                                .frame(minWidth: 32, alignment: .trailing)
                            Text("ms")
                                .font(.caption2)
                                .foregroundStyle(secondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(secondary)
                                .rotationEffect(.degrees(showLatency ? 0 : -90))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, showLatency ? 4 : 14)
                    .padding(.leading, 52)

                    if showLatency {
                        HStack(spacing: 8) {
                        Button {
                            let cur = slot?.latencyOffset ?? 0
                            let new = max(cur - 50, -1000)
                            if index < manager.deviceSlots.count {
                                manager.deviceSlots[index].latencyOffset = new
                                if let uid = manager.deviceSlots[index].device?.uid {
                                    manager.latencyOffsets[uid] = new
                                }
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(secondary)
                                .frame(width: 22, height: 22)
                                .background(controlFill)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("–50 ms")

                        Slider(
                            value: Binding(
                                get: { Double(slot?.latencyOffset ?? 0) },
                                set: { newValue in
                                    let rounded = Int(newValue.rounded())
                                    if index < manager.deviceSlots.count {
                                        manager.deviceSlots[index].latencyOffset = rounded
                                        if let uid = manager.deviceSlots[index].device?.uid {
                                            manager.latencyOffsets[uid] = rounded
                                        }
                                    }
                                }
                            ),
                            in: -1000...1000,
                            step: 10
                        )
                        .controlSize(.small)

                        Button {
                            let cur = slot?.latencyOffset ?? 0
                            let new = min(cur + 50, 1000)
                            if index < manager.deviceSlots.count {
                                manager.deviceSlots[index].latencyOffset = new
                                if let uid = manager.deviceSlots[index].device?.uid {
                                    manager.latencyOffsets[uid] = new
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(secondary)
                                .frame(width: 22, height: 22)
                                .background(controlFill)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("+50 ms")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .padding(.leading, 52)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                }
            }
        }
        .background(isHovered ? hoverBg : Color.clear)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { h in isHovered = h }
    }

    private func availableDevices() -> [AudioDeviceInfo] {
        let taken = Set(
            manager.deviceSlots.enumerated()
                .filter { $0.offset != index }
                .compactMap { $0.element.device?.id }
        )
        return manager.availableDevices.filter { !taken.contains($0.id) }
    }
}

// MARK: - Add Device Row

struct AddDeviceRow: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(isHovered ? 0.8 : 0.5))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Add Audio Device")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(isHovered ? 0.9 : 0.7))
                    Text("Pair headphones, speakers, or phones")
                        .font(.caption)
                        .foregroundStyle(secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                    .overlay(Color.white.opacity(isHovered ? 0.08 : 0.04))
            )
        }
        .buttonStyle(.plain)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(isHovered ? 0.12 : 0.06), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { h in isHovered = h }
    }
}

// MARK: - Sync Section

struct SyncSection: View {
    @Environment(AudioMeshManager.self) private var manager

    private var canSync: Bool {
        manager.deviceSlots.filter { $0.device != nil }.count >= 2
    }

    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                if canSync || manager.isActive {
                    if manager.isActive { manager.stop() } else { manager.sync() }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: manager.isActive ? "stop.fill" : "link.circle.fill")
                        .font(.body)
                    Text(manager.isActive ? "Stop" : "Sync Devices")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    manager.isActive
                        ? red
                        : accent.opacity(canSync ? 1 : 0.3)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .animation(.easeOut(duration: 0.15), value: manager.isActive)

            Text("Synchronize audio playback across all connected outputs")
                .font(.caption)
                .foregroundStyle(secondary)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Master Volume Section

struct MasterVolumeSection: View {
    @Environment(AudioMeshManager.self) private var manager

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.3")
                    .font(.caption)
                    .foregroundStyle(secondary)
                Text("Master Volume")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            MeshVolumeControl(
                icon: "speaker.wave.3.fill",
                value: manager.masterVolume,
                isMuted: manager.isMuted,
                isCompact: false,
                onChange: { newVal in
                    manager.updateMasterVolume(newVal)
                    if manager.isMuted && newVal > 0 {
                        manager.toggleMute()
                    }
                },
                onMuteToggle: manager.toggleMute
            )
            .padding(.horizontal, 16)
            .padding(.leading, 26)
            .padding(.bottom, 14)
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .overlay(Color.white.opacity(0.04))
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeOut(duration: 0.2), value: manager.isMuted)
    }
}

// MARK: - Ducking Section

struct DuckingSection: View {
    @Environment(AudioMeshManager.self) private var manager

    var body: some View {
        VStack(spacing: 0) {
            duckingHeader
            if manager.duckingEnabled {
                duckingControls
            }
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .overlay { Color.white.opacity(0.04) }
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(white: 1, opacity: 0.06))
        )
        .animation(.easeOut(duration: 0.2), value: manager.duckingEnabled)
    }

    private var duckingHeader: some View {
        HStack {
            Image(systemName: manager.isDucking ? "speaker.wave.2.bubble.fill" : "speaker.wave.2")
                .font(.caption)
                .foregroundStyle(manager.isDucking ? .orange : secondary)
            Text("Audio Ducking")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondary)
            Spacer()

            Toggle(isOn: Bindable(manager).duckingEnabled) {
                Text(manager.duckingEnabled ? "On" : "Off")
                    .font(.caption2)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var duckingControls: some View {
        VStack(spacing: 12) {
            Divider().overlay(Color.white.opacity(0.06))
            duckLevelRow
            autoDetectRow
            duckDurationRow
            duckButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .transition(.opacity)
    }

    private var duckLevelRow: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Duck level")
                    .font(.caption)
                    .foregroundStyle(secondary)
                Spacer()
                Text("\(Int(round(manager.duckLevel * 100)))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(secondary)
            }
            Slider(value: Bindable(manager).duckLevel, in: 0.05...1)
                .controlSize(.small)
                .tint(.orange)
        }
    }

    private var autoDetectRow: some View {
        HStack {
            Toggle(isOn: Bindable(manager).autoDuckingEnabled) {
                Text("Auto-detect alerts")
                    .font(.caption)
                    .foregroundStyle(secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            Spacer()

            if manager.autoDuckingEnabled {
                Text("Restore in \(Int(manager.duckDuration))s")
                    .font(.caption2)
                    .foregroundStyle(secondary)
            }
        }
    }

    private var duckDurationRow: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Restore in")
                    .font(.caption)
                    .foregroundStyle(secondary)
                Spacer()
                Text("\(Int(manager.duckDuration))s")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(secondary)
            }
            Slider(value: Binding(
                get: { Float(manager.duckDuration) },
                set: { manager.duckDuration = Double($0) }
            ), in: 1...10)
                .controlSize(.small)
                .tint(.orange)
        }
    }

    private var duckButton: some View {
        Button(action: { manager.isDucking ? manager.stopDucking() : manager.startDucking() }) {
            HStack(spacing: 6) {
                Image(systemName: manager.isDucking ? "arrow.uturn.backward" : "speaker.wave.2.bubble.fill")
                    .font(.caption)
                Text(manager.isDucking ? "Restore Volume" : "Duck Now")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(manager.isDucking ? Color.orange : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header

private struct HeaderView: View {
    @Environment(AudioMeshManager.self) private var manager

    private var connectedCount: Int {
        manager.deviceSlots.compactMap(\.device).count
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: manager.isActive ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(manager.isActive ? accent : .white.opacity(0.55))

            VStack(alignment: .leading, spacing: 3) {
                Text("AudioMesh")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Route Mac audio to multiple outputs")
                    .font(.subheadline)
                    .foregroundStyle(secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(manager.isActive ? Color.green : Color.white.opacity(0.28))
                    .frame(width: 7, height: 7)
                Text(manager.isActive ? "Syncing" : "\(connectedCount) connected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(manager.isActive ? .white : secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(controlFill, in: Capsule())
        }
    }
}

// MARK: - Status Bar

private struct StatusBarView: View {
    @Environment(AudioMeshManager.self) private var manager

    var body: some View {
        HStack(spacing: 0) {
            let count = manager.deviceSlots.compactMap(\.device).count

            Group {
                Text("\(count) Device\(count != 1 ? "s" : "") Connected")
                Text("  ·  ").foregroundStyle(secondary)
                Text(manager.statusMessage)
            }
            .font(.caption)
            .foregroundStyle(secondary)

            Spacer()
        }
    }
}

// MARK: - Presets Section

struct PresetsSection: View {
    @Environment(AudioMeshManager.self) private var manager
    @State private var showSaveSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "square.on.square")
                    .font(.caption)
                    .foregroundStyle(secondary)
                Text("Presets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondary)
                Spacer()

                Button {
                    showSaveSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("Save current layout as preset")
                .disabled(manager.deviceSlots.compactMap(\.device).count < 2)
                .opacity(manager.deviceSlots.compactMap(\.device).count < 2 ? 0.3 : 1)
            }

            if manager.presetManager.presets.isEmpty {
                Text("Save device combinations for quick switching")
                    .font(.caption)
                    .foregroundStyle(secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(manager.presetManager.presets) { preset in
                    HStack(spacing: 8) {
                        Image(systemName: preset.autoSync ? "play.circle.fill" : "square.on.square")
                            .font(.body)
                            .foregroundStyle(preset.autoSync ? .green : .secondary)

                        Text(preset.name)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)

                        Spacer()

                        Text("\(preset.deviceUIDs.count) devices")
                            .font(.caption2)
                            .foregroundStyle(secondary)

                        Button {
                            manager.applyPreset(preset)
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.body)
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                        .help("Apply preset")

                        Button {
                            manager.presetManager.delete(preset)
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.body)
                                .foregroundStyle(.red.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .help("Delete preset")
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            if manager.presetManager.presets.contains(where: { $0.autoSync }) {
                Text("Auto-sync presets activate when all devices connect")
                    .font(.caption2)
                    .foregroundStyle(secondary)
            }
        }
        .padding(12)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .overlay(Color.white.opacity(0.04))
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.06))
        )
        .sheet(isPresented: $showSaveSheet) {
            SavePresetSheet(showSaveSheet: $showSaveSheet)
                .environment(manager)
        }
    }
}

private struct SavePresetSheet: View {
    @Environment(AudioMeshManager.self) private var manager
    @Binding var showSaveSheet: Bool
    @State private var presetName = ""
    @State private var autoSync = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Save Preset")
                .font(.headline)

            Text("Save current device configuration as a preset")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Preset name", text: $presetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)

            Toggle("Auto-sync when devices connect", isOn: $autoSync)
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.mini)

            HStack(spacing: 12) {
                Button("Cancel") { showSaveSheet = false }
                    .buttonStyle(.bordered)

                Button("Save") {
                    guard !presetName.isEmpty else { return }
                    manager.saveCurrentPreset(name: presetName, autoSync: autoSync)
                    showSaveSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(presetName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}

// MARK: - Battery Badge

struct BatteryBadge: View {
    let info: DeviceBatteryInfo

    private var level: Int? {
        let l = info.single ?? info.combined ?? info.left ?? info.right
        return l.flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        if let l = level {
            let icon: String = {
                if l >= 75 { return "battery.100" }
                if l >= 50 { return "battery.75" }
                if l >= 25 { return "battery.50" }
                return "battery.25"
            }()
            let color: Color = l >= 25 ? .secondary : .red

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text("\(l)%")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(controlFill, in: RoundedRectangle(cornerRadius: 6))
            .help(info.helpText)
        }
    }
}

extension DeviceBatteryInfo {
    var helpText: String {
        if let s = single { return "Battery: \(s)%" }
        if let combined = combined { return "Battery: \(combined)%" }
        if let l = left, let r = right { return "L: \(l)%  R: \(r)%" }
        if let l = left { return "Left: \(l)%" }
        if let r = right { return "Right: \(r)%" }
        return "Battery: Unknown"
    }
}