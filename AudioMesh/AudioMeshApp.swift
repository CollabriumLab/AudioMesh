import SwiftUI

@main
struct AudioMeshApp: App {
    @State private var manager = AudioMeshManager()

    var body: some Scene {
        WindowGroup("AudioMesh", id: "main") {
            ContentView()
                .environment(manager)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                    if let window = NSApplication.shared.windows.first {
                        window.titlebarAppearsTransparent = true
                        window.titleVisibility = .hidden
                        window.styleMask.insert(.fullSizeContentView)
                        window.isMovableByWindowBackground = true
                        window.backgroundColor = .clear
                    }
                }
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarContentView()
                .environment(manager)
        } label: {
            Image(systemName: manager.isActive ? "headphones.circle.fill" : "headphones")
                .foregroundStyle(manager.isActive ? Color.blue : .white)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar

private struct MenuBarContentView: View {
    @Environment(AudioMeshManager.self) private var manager
    @Environment(\.openWindow) private var openWindow

    private var connectedCount: Int {
        manager.deviceSlots.compactMap { $0.device }.count
    }

    private var canSync: Bool {
        connectedCount >= 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if connectedCount > 0 {
                deviceSliders
            } else {
                emptyState
            }

            if manager.isActive {
                masterVolumeRow
                duckRow
            }

            syncRow

            GlassDivider()

            HStack(spacing: 8) {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open", systemImage: "macwindow")
                }
                .glassButtonPress()

                Spacer()

                Button {
                    manager.cleanup()
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q")
                .glassButtonPress()
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 318)
        .background(GlassMenuBarBackground())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: manager.isActive ? "waveform.circle.fill" : "waveform.circle")
                .font(.title3)
                .foregroundStyle(manager.isActive ? .blue : glassSecondary)

            VStack(alignment: .leading, spacing: 1) {
                Text("AudioMesh")
                    .font(.subheadline.weight(.semibold))
                Text(manager.isActive ? manager.statusMessage : "\(connectedCount) of \(manager.deviceSlots.count) outputs ready")
                    .font(.caption2)
                    .foregroundStyle(glassSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(manager.isActive ? "Live" : "Idle")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(manager.isActive ? .green : glassSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.white.opacity(0.07), in: Capsule())
        }
        .padding(.bottom, 2)
    }

    // MARK: Device Sliders

    private var deviceSliders: some View {
        VStack(spacing: 8) {
            ForEach(Array(manager.deviceSlots.enumerated()), id: \.element.id) { i, slot in
                if let device = slot.device {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "headphones")
                                .font(.caption2)
                                .foregroundStyle(glassSecondary)
                                .frame(width: 14)
                            Text(device.name)
                                .font(.caption)
                                .lineLimit(1)

                            if device.isBluetooth, let battery = manager.battery(for: device.name, uid: device.uid) {
                                batteryIndicator(battery)
                            }

                            Spacer()
                            Text("\(Int(round(slot.volume * 100)))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(glassSecondary)
                        }

                        MeshVolumeControl(
                            icon: "speaker.fill",
                            value: slot.volume,
                            isMuted: false,
                            isCompact: true,
                            onChange: { manager.updateVolume(at: i, $0) },
                            onMuteToggle: nil
                        )
                    }
                    .padding(9)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: Battery Indicator

    @ViewBuilder
    private func batteryIndicator(_ info: DeviceBatteryInfo) -> some View {
        let level = info.single ?? info.combined ?? info.left ?? info.right
        if let l = level, l > 0 {
            let icon: String = {
                if l >= 75 { return "battery.100" }
                if l >= 50 { return "battery.75" }
                if l >= 25 { return "battery.50" }
                return "battery.25"
            }()
            let color: Color = l >= 25 ? glassSecondary : .red

            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text("\(l)%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(color)
            }
            .help("Battery: \(l)%")
        }
    }

    private var emptyState: some View {
        HStack(spacing: 9) {
            Image(systemName: "headphones")
                .font(.caption)
                .foregroundStyle(glassSecondary)
                .frame(width: 18)
            Text("Choose at least two outputs in the app window.")
                .font(.caption)
                .foregroundStyle(glassSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Master Volume

    private var masterVolumeRow: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "speaker.wave.3")
                    .font(.caption2)
                    .foregroundStyle(glassSecondary)
                    .frame(width: 14)
                Text("Master")
                    .font(.caption)

                Spacer()

                Text(manager.isMuted ? "Muted" : "\(Int(round(manager.masterVolume * 100)))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(manager.isMuted ? .red : glassSecondary)
            }

            MeshVolumeControl(
                icon: "speaker.wave.3.fill",
                value: manager.masterVolume,
                isMuted: manager.isMuted,
                isCompact: true,
                onChange: { v in
                    if manager.isMuted && v > 0 {
                        manager.toggleMute()
                        manager.updateMasterVolume(v)
                    } else {
                        manager.updateMasterVolume(v)
                    }
                },
                onMuteToggle: manager.toggleMute
            )
        }
        .padding(9)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Duck Row

    private var duckRow: some View {
        HStack(spacing: 6) {
            Image(systemName: manager.isDucking ? "speaker.wave.2.bubble.fill" : "speaker.wave.2")
                .font(.caption2)
                .foregroundStyle(manager.isDucking ? .orange : glassSecondary)
                .frame(width: 14)

            Toggle(isOn: Bindable(manager).duckingEnabled) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            Text("Ducking")
                .font(.caption)
                .foregroundStyle(manager.duckingEnabled ? .white : glassSecondary)

            Spacer()

            if manager.duckingEnabled {
                Button(manager.isDucking ? "Restore" : "Duck") {
                    manager.isDucking ? manager.stopDucking() : manager.startDucking()
                }
                .font(.caption2.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(manager.isDucking ? .orange : .gray.opacity(0.5))
                .controlSize(.small)

                Text("\(Int(round(manager.duckLevel * 100)))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(glassSecondary)
                    .frame(width: 28, alignment: .trailing)
            }
        }
        .padding(9)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Sync

    private var syncRow: some View {
        Button(action: {
            if canSync || manager.isActive {
                if manager.isActive { manager.stop() } else { manager.sync() }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: manager.isActive ? "stop.fill" : "link")
                    .font(.caption.weight(.semibold))
                Text(manager.isActive ? "Stop Sync" : "Sync Devices")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(manager.isActive ? Color.red : Color.blue.opacity(canSync ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .glassButtonPress()
    }
}
