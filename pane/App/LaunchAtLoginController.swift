import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    static let shared = LaunchAtLoginController()

    private init() {}

    func apply(enabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if enabled {
                guard service.status != .enabled else {
                    return
                }
                try service.register()
            } else {
                guard service.status == .enabled else {
                    return
                }
                try service.unregister()
            }
        } catch {
            // Keep app runtime resilient. Settings still persist; registration can be retried.
            NSLog("widgie launch-at-login update failed: %@", error.localizedDescription)
        }
    }
}
