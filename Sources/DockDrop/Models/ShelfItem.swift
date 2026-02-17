import AppKit

struct ShelfItem: Identifiable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let icon: NSImage

    init(app: NSRunningApplication) {
        id = app.bundleIdentifier ?? "pid-\(app.processIdentifier)"
        name = app.localizedName ?? "Unknown"
        bundleIdentifier = app.bundleIdentifier
        processIdentifier = app.processIdentifier
        icon = app.icon ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    func runningApplication() -> NSRunningApplication? {
        NSRunningApplication(processIdentifier: processIdentifier)
    }
}
