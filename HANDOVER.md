# AudioMesh — Handover Document

## Project Overview

macOS app that routes system audio to multiple Bluetooth headphones simultaneously via a CoreAudio multi-output aggregate device. SwiftUI + native macOS APIs.

## Architecture

### Files

| File | Role |
|------|------|
| `AudioMeshApp.swift` | App entry, `WindowGroup` (820×650) + `MenuBarExtra` (primary interface with quick controls) |
| `ContentView.swift` | Full window layout: header, grouped settings sections, device rows, master volume, sync button, status bar |
| `AudioMeshManager.swift` | ObservableObject state management: device slots, volume, sync/stop orchestration, persistence |
| `AudioEngine.swift` | CoreAudio layer: create/destroy multi-output aggregate device, set per-device + master volume, device enumeration |
| `AudioDeviceInfo.swift` | Device model: id, name, uid, sampleRate, transportType, isBluetooth |
| `VisualEffectView.swift` | NSViewRepresentable wrapper for NSVisualEffectView (sidebarmaterial for frosted glass sections) |

### Data Flow

```
User taps Sync → AudioMeshManager.sync()
  → AudioEngine.startGraph(devices:) → AudioHardwareCreateAggregateDevice (stacked multi-output)
  → Set as system default output
  → Apply saved volumes → isActive = true

User adjusts volume → AudioMeshManager.updateVolume/setMasterVolume
  → AudioEngine.setVolume/setMasterVolume → kAudioDevicePropertyVolumeScalar on elements 1,2

User taps Stop → AudioMeshManager.stop()
  → AudioEngine.stopGraph() → AudioHardwareDestroyAggregateDevice → restore original default
```

### Volume Architecture

- **Per-device**: Each slot saves volume by device UID (`[String: Float]`)
- **Master volume**: Sets all slots + applies to engine when active
- **Mute**: Saves pre-mute volume, sets to 0, restores on unmute
- **Persistence**: UserDefaults — `deviceVolumes` (per-UID dict), `slotOrder` (array of UIDs), `masterVolume` (Double)

### Key Design Decisions

1. **Multi-output device**: Uses `kAudioAggregateDeviceIsStackedKey=true` — CoreAudio clones audio to all sub-devices at the system level. No audio processing in our app.
2. **Volume on elements 1,2**: Bluetooth headphones don't support element 0 (master). Volume is written to elements 1 and 2 (physical L/R channels).
3. **Sliders aligned**: All use `controlSize(.mini)` with consistent `14pt` icon frame.
4. **Frosted glass sections**: `.sidebar` material with `.withinWindow` blending (same as Finder/System Settings).
5. **Menu bar is primary**: App window is secondary. Menu has quick volume sliders + sync/stop.
6. **Window**: 820×650, native title bar with traffic lights, `.contentSize` resizability.

### Color Palette

- Background: `#101214`
- Sections: `.sidebar` visual effect + `white 4%` overlay
- Row hover: `#26292E`
- Accent: System blue
- Stop: `#FF3B30`
- Text primary: white, secondary: `white 50%`

## Known Issues & Limitations

1. **Bluetooth battery/latency**: CoreAudio doesn't expose these. Would need IOBluetooth framework.
2. **Bluetooth symbol**: `"bluetooth"` SF Symbol not found on macOS 26/Xcode 17 — using text "BT" instead.
3. **Menu label caches**: `Menu` with `.borderlessButton` caches its label. Fixed with `.id(slot?.device?.uid ?? "empty-\(index)")`.
4. **Aggregate device in picker**: Filtered out by UID prefix `com.collabrium.audiomesh.`.
5. **Volume scalar range**: Bluetooth devices have compressed range — slider at 0 doesn't fully mute.
6. **`linkd.autoShortcut` errors**: Harmless Xcode App Intents infrastructure noise.

## Next Steps / Possible Improvements

1. **Persist mute state**: Currently mute resets on app restart. Add `preMuteVolume` to UserDefaults.
2. **Device hotplug handling**: When a synced device disconnects, auto-detect and update UI.
3. **Sample rate negotiation**: Handle mismatched sample rates between devices.
4. **Real battery/latency**: Integrate IOBluetooth framework for real values.
5. **Window title bar**: Could use `.hiddenTitleBar` with custom traffic light handling for a more immersive look.
6. **Keyboard shortcuts**: Add global hotkeys for mute, volume up/down.
7. **Accessibility**: Add accessibility labels to sliders and buttons.
8. **Multiple aggregate devices**: Support running multiple independent sync groups.

## Build & Run

```bash
xcodebuild -project AudioMesh.xcodeproj -scheme AudioMesh -destination 'platform=macOS' build
```

Deployment target: macOS 14+. Requires two Bluetooth headphones with volume scalar support on elements 1/2 (most modern earbuds support this).
