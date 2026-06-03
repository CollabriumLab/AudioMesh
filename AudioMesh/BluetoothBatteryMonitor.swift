import Foundation
import IOBluetooth

struct DeviceBatteryInfo {
    let combined: Int?
    let left: Int?
    let right: Int?
    let case_battery: Int?
    let single: Int?
    let isMultiBattery: Bool
    let address: String?
}

@Observable
final class BluetoothBatteryMonitor {
    var deviceBatteries: [String: DeviceBatteryInfo] = [:]

    private var timer: Timer?

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }

        var result: [String: DeviceBatteryInfo] = [:]
        for device in devices where device.isConnected() {
            let name = device.name ?? ""
            guard !name.isEmpty else { continue }

            // IOBluetoothDevice private KVC keys for battery level access.
            // These are undocumented SPI — may break on macOS updates.
            // Known keys: batteryPercentCombined, batteryPercentLeft,
            // batteryPercentRight, batteryPercentSingle, batteryPercentCase,
            // isMultiBatteryDevice.
            let combined = device.value(forKey: "batteryPercentCombined") as? Int
            let left = device.value(forKey: "batteryPercentLeft") as? Int
            let right = device.value(forKey: "batteryPercentRight") as? Int
            let single = device.value(forKey: "batteryPercentSingle") as? Int
            let caseBattery = device.value(forKey: "batteryPercentCase") as? Int
            let isMulti = device.value(forKey: "isMultiBatteryDevice") as? Bool ?? false
            let btAddress = device.addressString as String?

            let hasValid = [combined, left, right, single].compactMap { $0 }.contains { $0 > 0 }
            guard hasValid else { continue }

            let info = DeviceBatteryInfo(
                combined: combined,
                left: left,
                right: right,
                case_battery: caseBattery,
                single: single,
                isMultiBattery: isMulti,
                address: btAddress
            )
            result[name] = info
            if let addr = btAddress {
                result[addr] = info
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.deviceBatteries = result
        }
    }
}
