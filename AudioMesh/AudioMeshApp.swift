import SwiftUI

@main
struct AudioMeshApp: App {
    @StateObject private var manager = AudioMeshManager()

    var body: some Scene {
        WindowGroup("AudioMesh", id: "main") {
            ContentView()
                .environmentObject(manager)
                .onAppear { NSWindow.allowsAutomaticWindowTabbing = false }
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(manager)
        } label: {
            Image(systemName: manager.isActive ? "headphones.circle.fill" : "headphones")
                .foregroundStyle(manager.isActive ? Color.blue : .white)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar

private struct MenuBarContentView: View {
    @EnvironmentObject var manager: AudioMeshManager
    @Environment(\.openWindow) private var openWindow

    private var connectedCount: Int {
        manager.deviceSlots.compactMap(\.device).count
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
            }

            syncRow

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(spacing: 8) {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open", systemImage: "macwindow")
                }

                Spacer()

                Button {
                    manager.cleanup()
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q")
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 318)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: manager.isActive ? "waveform.circle.fill" : "waveform.circle")
                .font(.title3)
                .foregroundStyle(manager.isActive ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text("AudioMesh")
                    .font(.subheadline.weight(.semibold))
                Text(manager.isActive ? manager.statusMessage : "\(connectedCount) of \(manager.deviceSlots.count) outputs ready")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(manager.isActive ? "Live" : "Idle")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(manager.isActive ? .green : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.07), in: Capsule())
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
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                            Text(device.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(round(slot.volume * 100)))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
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
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 9) {
            Image(systemName: "headphones")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text("Choose at least two outputs in the app window.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Master Volume

    private var masterVolumeRow: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "speaker.wave.3")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text("Master")
                    .font(.caption)

                Spacer()

                Text(manager.isMuted ? "Muted" : "\(Int(round(manager.masterVolume * 100)))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(manager.isMuted ? .red : .secondary)
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
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Sync

    private var syncRow: some View {
        Button(action: manager.isActive ? manager.stop : manager.sync) {
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
        .disabled(!canSync && !manager.isActive)
    }
}
