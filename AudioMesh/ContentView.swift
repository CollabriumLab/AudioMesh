import SwiftUI

// MARK: - Constants

private let bg = Color(red: 0.063, green: 0.078, blue: 0.102)
private let hoverBg = Color(red: 0.15, green: 0.16, blue: 0.18)
private let accent = Color.blue
private let secondary = Color.white.opacity(0.5)
private let divider = Color.white.opacity(0.06)
private let red = Color(red: 1.0, green: 0.23, blue: 0.19)
private let controlFill = Color.white.opacity(0.055)

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
    @EnvironmentObject var manager: AudioMeshManager
    let index: Int
    @State private var isHovered = false
    @State private var hoverRemove = false

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
                            Text(device.isBluetooth ? "BT" : "OUT")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(controlFill, in: RoundedRectangle(cornerRadius: 6))
                        }

                        if !manager.isActive && manager.deviceSlots.count > 2 {
                            Button {
                                manager.removeSlot(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(hoverRemove ? 0.5 : 0.2))
                            }
                            .buttonStyle(.plain)
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
                .padding(.bottom, 14)
                .padding(.leading, 52)
                .transition(.opacity.combined(with: .move(edge: .top)))
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(isHovered ? 0.12 : 0.06), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { h in isHovered = h }
        .onTapGesture(perform: action)
    }
}

// MARK: - Sync Section

struct SyncSection: View {
    @EnvironmentObject var manager: AudioMeshManager

    private var canSync: Bool {
        manager.deviceSlots.filter { $0.device != nil }.count >= 2
    }

    var body: some View {
        VStack(spacing: 8) {
            Button(action: manager.isActive ? manager.stop : manager.sync) {
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
            .disabled(!canSync && !manager.isActive)
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
    @EnvironmentObject var manager: AudioMeshManager

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
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeOut(duration: 0.2), value: manager.isMuted)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var manager: AudioMeshManager

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HeaderView()
                    deviceSection
                    if !manager.isActive {
                        AddDeviceRow(action: manager.addSlot)
                    }
                    if manager.isActive {
                        MasterVolumeSection()
                    }
                    SyncSection()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)

            Divider().overlay(divider)
            StatusBarView()
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
        }
        .frame(width: 820, height: 650)
        .background(bg)
    }

    // MARK: Device Section

    private var deviceSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(manager.deviceSlots.enumerated()), id: \.element.id) { i, _ in
                DeviceRow(index: i)
                if i < manager.deviceSlots.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                        .overlay(divider)
                }
            }
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .overlay(Color.white.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Header

private struct HeaderView: View {
    @EnvironmentObject var manager: AudioMeshManager

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
    @EnvironmentObject var manager: AudioMeshManager

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
