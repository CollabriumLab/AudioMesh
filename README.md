# AudioMesh

Route macOS system audio to multiple Bluetooth headphones simultaneously using a CoreAudio multi-output aggregate device.

## How it works

Creates a stacked multi-output device via `AudioHardwareCreateAggregateDevice` and sets it as the system default output. Audio is cloned to all connected Bluetooth devices with per-device and master volume control.

## Usage

1. Connect two or more Bluetooth headphones/speakers
2. Select them in the device slots
3. Click **Sync** — a multi-output device is created and set as default
4. Adjust master or per-device volume with the sliders
5. Click **Stop** to restore the original output device

Volumes are persisted per-device by UID — swapping devices between slots preserves their saved levels.

## Requirements

- macOS 14+
- Two or more Bluetooth audio output devices
