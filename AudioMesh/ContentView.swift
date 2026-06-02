import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: AudioMeshManager

    var body: some View {
        VStack(spacing: 16) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(manager.deviceSlots.enumerated()), id: \.element.id) { i, _ in
                        DeviceSlotView(index: i)
                    }
                }
            }
            if !manager.isActive {
                Button(action: manager.addSlot) {
                    Label("Add Device", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            Divider()
            actionButtons
            statusRow
        }
        .padding()
        .frame(width: 420)
        .frame(minHeight: 400)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "headphones.circle.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                Text("AudioMesh")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            if manager.isActive {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary).imageScale(.small)
                    Slider(
                        value: Binding(
                            get: { manager.masterVolume },
                            set: { manager.updateMasterVolume($0) }
                        ),
                        in: 0...1
                    )
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary).imageScale(.small)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: manager.isActive)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if manager.isActive {
                Button(action: manager.stop) {
                    Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            } else {
                Button(action: manager.sync) {
                    Label("Sync", systemImage: "link.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(manager.deviceSlots.filter { $0.device != nil }.count < 2)
            }
        }
    }

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(manager.isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(manager.statusMessage)
                .foregroundStyle(manager.isError ? .red : .secondary)
                .font(.caption)
        }
    }
}

struct DeviceSlotView: View {
    @EnvironmentObject var manager: AudioMeshManager
    let index: Int

    private var deviceBinding: Binding<AudioDeviceInfo?> {
        Binding(
            get: { manager.deviceSlots[index].device },
            set: { manager.selectDeviceForSlot(at: index, device: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Device \(index + 1)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let d = manager.deviceSlots[index].device {
                    Text(d.transportType.description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if !manager.isActive && manager.deviceSlots.count > 2 {
                    Button(action: { manager.removeSlot(at: index) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Picker("", selection: deviceBinding) {
                Text("Select a device").tag(nil as AudioDeviceInfo?)
                ForEach(availableForSlot()) { device in
                    HStack {
                        Text(device.name)
                        if device.isBluetooth { Text("(Bluetooth)").foregroundStyle(.secondary) }
                    }
                    .tag(device as AudioDeviceInfo?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            if manager.deviceSlots[index].device != nil {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary).imageScale(.small)
                    Slider(
                        value: Binding(
                            get: { manager.deviceSlots[index].volume },
                            set: { manager.updateVolume(at: index, $0) }
                        ),
                        in: 0...1
                    )
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary).imageScale(.small)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        .cornerRadius(8)
    }

    private func availableForSlot() -> [AudioDeviceInfo] {
        let taken = Set(
            manager.deviceSlots.enumerated()
                .filter { $0.offset != index }
                .compactMap { $0.element.device?.id }
        )
        return manager.availableDevices.filter { !taken.contains($0.id) }
    }
}
