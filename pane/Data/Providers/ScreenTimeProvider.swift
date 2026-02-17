import AppKit
import Foundation

struct ScreenTimeProvider {
    func fetch(maxApps: Int) -> ScreenTimeSnapshot {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
            .sorted()
            .prefix(max(1, maxApps))
            .enumerated()
            .map { index, name in
                ScreenTimeAppSnapshot(
                    id: "\(name)-\(index)",
                    name: name,
                    durationText: "Unavailable"
                )
            }

        return ScreenTimeSnapshot(
            total: "Unavailable",
            topApps: Array(running),
            isAvailable: false,
            updatedAt: Date()
        )
    }
}
