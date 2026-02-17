import AppKit

enum WindowManager {
    static func topWindowNumber(for app: NSRunningApplication) -> Int? {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for info in infoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == app.processIdentifier,
                  let number = info[kCGWindowNumber as String] as? Int,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            return number
        }

        return nil
    }
}
