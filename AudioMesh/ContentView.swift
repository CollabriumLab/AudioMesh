import SwiftUI

// MARK: - Constants

private let bg = LinearGradient(
    stops: [
        .init(color: Color(red: 0.14, green: 0.07, blue: 0.17), location: 0),
        .init(color: Color(red: 0.07, green: 0.06, blue: 0.12), location: 0.45),
        .init(color: Color(red: 0.04, green: 0.05, blue: 0.09), location: 1),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
private let accent = Color.blue
private let red = Color(red: 1.0, green: 0.23, blue: 0.19)
private let glassText = Color.white.opacity(0.7)
let glassSecondary = Color.white.opacity(0.45)
private let secondary = glassSecondary

// MARK: - Content View

struct ContentView: View {
    @Environment(AudioMeshManager.self) private var manager

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
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

                GlassDivider()

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
                    GlassDivider()
                }
            }
        }
        .glassContainer()
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
                    withAnimation(glassSpringFast) { onMuteToggle() }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: isCompact ? 6 : 7)
                            .fill(isMuted ? red.opacity(0.18) : .white.opacity(0.055))
                        Image(systemName: isMuted ? "speaker.slash.fill" : icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isMuted ? red : glassSecondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: isCompact ? 24 : 28, height: isCompact ? 22 : 26)
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 6 : 7)
                            .strokeBorder(isMuted ? red.opacity(0.28) : .white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .glassButtonPress()
                .help(isMuted ? "Unmute" : "Mute")
            } else {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(glassSecondary)
                    .frame(width: isCompact ? 14 : 16)
            }

            Slider(
                value: Binding(get: { value }, set: onChange),
                in: 0...1
            )
            .controlSize(controlSize)
            .tint(isMuted ? red.opacity(0.7) : accent)
            .opacity(isMuted ? 0.45 : 1)

            Text(percentText)
                .font((isCompact ? Font.caption2 : Font.caption).monospacedDigit())
                .foregroundStyle(isMuted ? red : glassSecondary)
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
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Menu {
                        ForEach(availableDevices()) { device in
                            Button {
                                withAnimation(glassSpringFast) {
                                    manager.selectDeviceForSlot(at: index, device: device)
                                }
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
                                withAnimation(glassSpringFast) {
                                    manager.removeSlot(at: index)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(slot?.device?.name ?? "Select Audio Device")
                                .font(.body.weight(.medium))
                                .foregroundStyle(slot?.device != nil ? .white : glassSecondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(glassSecondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .id(slot?.device?.uid ?? "empty-\(index)")

                    if slot?.device != nil {
                        Text(connectionSummary)
                            .font(.caption)
                            .foregroundStyle(glassSecondary)
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
                                    .foregroundStyle(glassSecondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }

                        Button {
                            withAnimation(glassSpringFast) {
                                manager.removeSlot(at: index)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(isHovered ? 0.6 : 0.3))
                        }
                        .buttonStyle(.plain)
                        .glassButtonPress()
                        .help("Remove slot")
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

                if let device = slot?.device, !device.isBluetooth {
                    Button {
                        withAnimation(glassSpring) { showLatency.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(glassSecondary)
                            Text("Latency")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(glassSecondary)
                            Spacer()
                            Text(slot.map { $0.latencyOffset >= 0 ? "+\($0.latencyOffset)" : "\($0.latencyOffset)" } ?? "0")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(slot?.latencyOffset == 0 ? glassSecondary : .white)
                                .frame(minWidth: 32, alignment: .trailing)
                            Text("ms")
                                .font(.caption2)
                                .foregroundStyle(glassSecondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(glassSecondary)
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
                                    .foregroundStyle(glassSecondary)
                                    .frame(width: 22, height: 22)
                                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .glassButtonPress()
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
                                    .foregroundStyle(glassSecondary)
                                    .frame(width: 22, height: 22)
                                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .glassButtonPress()
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
        .background(isHovered ? .white.opacity(0.04) : Color.clear)
        .animation(glassEaseOut, value: isHovered)
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
                        .foregroundStyle(glassSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .overlay(.white.opacity(isHovered ? 0.08 : 0.03))
            )
        }
        .buttonStyle(.plain)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(isHovered ? 0.15 : 0.06), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
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
            }
            .buttonStyle(GlassButtonStyle(tint: manager.isActive ? red : accent, isActive: manager.isActive))

            Text("Synchronize audio playback across all connected outputs")
                .font(.caption)
                .foregroundStyle(glassSecondary)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Master Volume Section

struct MasterVolumeSection: View {
    @Environment(AudioMeshManager.self) private var manager

    var body: some View {
        VStack(spacing: 9) {
            GlassSectionHeader(icon: "speaker.wave.3", title: "Master Volume")

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
        .glassContainer()
        .animation(glassSpring, value: manager.isMuted)
    }
}

// MARK: - Ducking Section

struct DuckingSection: View {
    @Environment(AudioMeshManager.self) private var manager

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: manager.isDucking ? "speaker.wave.2.bubble.fill" : "speaker.wave.2")
                    .font(.caption)
                    .foregroundStyle(manager.isDucking ? .orange : .white.opacity(0.5))

                Text("Audio Ducking")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                Toggle(isOn: Bindable(manager).duckingEnabled) {
                    Text(manager.duckingEnabled ? "On" : "Off")
                        .font(.caption2)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if manager.duckingEnabled {
                duckingControls
            }
        }
        .glassContainer()
        .animation(glassSpring, value: manager.duckingEnabled)
    }

    private var duckingControls: some View {
        VStack(spacing: 12) {
            GlassDivider()

            GlassSliderRow(
                label: "Duck level",
                value: Bindable(manager).duckLevel,
                format: "\(Int(round(manager.duckLevel * 100)))%",
                range: 0.05...1,
                tint: .orange
            )

            autoDetectRow

            GlassSliderRow(
                label: "Restore in",
                value: Binding(
                    get: { Float(manager.duckDuration) },
                    set: { manager.duckDuration = Double($0) }
                ),
                format: "\(Int(manager.duckDuration))s",
                range: 1...10,
                tint: .orange
            )

            Button(action: { manager.isDucking ? manager.stopDucking() : manager.startDucking() }) {
                HStack(spacing: 6) {
                    Image(systemName: manager.isDucking ? "arrow.uturn.backward" : "speaker.wave.2.bubble.fill")
                        .font(.caption)
                    Text(manager.isDucking ? "Restore Volume" : "Duck Now")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(manager.isDucking ? Color.orange : .white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .glassButtonPress()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .transition(.opacity)
    }

    private var autoDetectRow: some View {
        HStack {
            Toggle(isOn: Bindable(manager).autoDuckingEnabled) {
                Text("Auto-detect alerts")
                    .font(.caption)
                    .foregroundStyle(glassSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            Spacer()

            if manager.autoDuckingEnabled {
                Text("Restore in \(Int(manager.duckDuration))s")
                    .font(.caption2)
                    .foregroundStyle(glassSecondary)
            }
        }
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
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(manager.isActive ? accent : .white.opacity(0.5))

            VStack(alignment: .leading, spacing: 3) {
                Text("AudioMesh")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Route Mac audio to multiple outputs")
                    .font(.subheadline)
                    .foregroundStyle(glassSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(manager.isActive ? Color.green : .white.opacity(0.25))
                    .frame(width: 7, height: 7)
                Text(manager.isActive ? "Syncing" : "\(connectedCount) connected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(manager.isActive ? .white : glassSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.055), in: Capsule())
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
                Text("  ·  ").foregroundStyle(glassSecondary)
                Text(manager.statusMessage)
            }
            .font(.caption)
            .foregroundStyle(glassSecondary)

            Spacer()
        }
        .padding(.horizontal, 4)
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
                    .foregroundStyle(glassSecondary)
                Text("Presets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(glassSecondary)
                Spacer()

                Button {
                    showSaveSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .glassButtonPress()
                .help("Save current layout as preset")
                .disabled(manager.deviceSlots.compactMap(\.device).count < 2)
                .opacity(manager.deviceSlots.compactMap(\.device).count < 2 ? 0.3 : 1)
            }

            if manager.presetManager.presets.isEmpty {
                Text("Save device combinations for quick switching")
                    .font(.caption)
                    .foregroundStyle(glassSecondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(manager.presetManager.presets) { preset in
                    HStack(spacing: 8) {
                        Image(systemName: preset.autoSync ? "play.circle.fill" : "square.on.square")
                            .font(.body)
                            .foregroundStyle(preset.autoSync ? .green : glassSecondary)

                        Text(preset.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(glassText)
                            .lineLimit(1)

                        Spacer()

                        Text("\(preset.deviceUIDs.count) devices")
                            .font(.caption2)
                            .foregroundStyle(glassSecondary)

                        Button {
                            withAnimation(glassSpringFast) { manager.applyPreset(preset) }
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.body)
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                        .glassButtonPress()
                        .help("Apply preset")

                        Button {
                            withAnimation(glassSpringFast) { manager.presetManager.delete(preset) }
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.body)
                                .foregroundStyle(.red.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .glassButtonPress()
                        .help("Delete preset")
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            if manager.presetManager.presets.contains(where: { $0.autoSync }) {
                Text("Auto-sync presets activate when all devices connect")
                    .font(.caption2)
                    .foregroundStyle(glassSecondary)
            }
        }
        .padding(12)
        .glassContainer()
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
            let color: Color = l >= 25 ? glassSecondary : .red

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
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
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
