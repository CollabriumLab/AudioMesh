import CoreAudio

struct AudioDeviceInfo: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    var sampleRate: Float64
    let transportType: TransportType
    let hasOutput: Bool

    var isBluetooth: Bool {
        transportType == .bluetooth || transportType == .bluetoothLE
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AudioDeviceInfo, rhs: AudioDeviceInfo) -> Bool {
        lhs.id == rhs.id
    }

    enum TransportType: CaseIterable {
        case builtIn
        case usb
        case bluetooth
        case bluetoothLE
        case airPlay
        case thunderbolt
        case hdmi
        case displayPort
        case virtual
        case unknown

        static func from(_ code: UInt32) -> TransportType {
            switch code {
            case kAudioDeviceTransportTypeBuiltIn:     return .builtIn
            case kAudioDeviceTransportTypeUSB:         return .usb
            case kAudioDeviceTransportTypeBluetooth:   return .bluetooth
            case kAudioDeviceTransportTypeBluetoothLE: return .bluetoothLE
            case kAudioDeviceTransportTypeAirPlay:     return .airPlay
            case kAudioDeviceTransportTypeDisplayPort: return .displayPort
            case kAudioDeviceTransportTypeHDMI:        return .hdmi
            case 0x74686274 /* 'thbt' */:              return .thunderbolt
            case 0x76697274 /* 'virt' */:              return .virtual
            default:                                   return .unknown
            }
        }

        var description: String {
            switch self {
            case .builtIn:     return "Built-in"
            case .usb:         return "USB"
            case .bluetooth:   return "Bluetooth"
            case .bluetoothLE: return "Bluetooth LE"
            case .airPlay:     return "AirPlay"
            case .thunderbolt: return "Thunderbolt"
            case .hdmi:        return "HDMI"
            case .displayPort: return "DisplayPort"
            case .virtual:     return "Virtual"
            case .unknown:     return "Unknown"
            }
        }
    }
}
