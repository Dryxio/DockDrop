import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("DockDrop: failed to update launch-at-login state: \(error.localizedDescription)")
        }
    }
}
