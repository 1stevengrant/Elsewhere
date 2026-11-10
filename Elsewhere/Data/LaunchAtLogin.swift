import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()

                return
            }

            try SMAppService.mainApp.unregister()
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}
