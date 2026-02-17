import Foundation
import IOKit.ps

struct BatteryProvider {
    func fetch() -> BatterySnapshot {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return BatterySnapshot(percentage: nil, isCharging: false, isLowPower: false, updatedAt: Date())
        }

        var percentages: [Double] = []
        var isCharging = false

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let current = description[kIOPSCurrentCapacityKey as String] as? Double,
               let max = description[kIOPSMaxCapacityKey as String] as? Double,
               max > 0 {
                percentages.append((current / max) * 100)
            }

            if let state = description[kIOPSPowerSourceStateKey as String] as? String,
               state == kIOPSACPowerValue {
                isCharging = true
            }
        }

        let average = percentages.isEmpty ? nil : percentages.reduce(0, +) / Double(percentages.count)

        return BatterySnapshot(
            percentage: average,
            isCharging: isCharging,
            isLowPower: (average ?? 100) < 20,
            updatedAt: Date()
        )
    }
}
