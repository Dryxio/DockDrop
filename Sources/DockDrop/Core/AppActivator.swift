import AppKit

final class AppActivator {
    private let preferences: UserPreferences
    private var timer: Timer?
    private var pendingItemID: String?
    private var lastActivatedItemID: String?

    init(preferences: UserPreferences = .shared) {
        self.preferences = preferences
    }

    func handleHover(on item: ShelfItem?) {
        guard let item else {
            cancelPending()
            lastActivatedItemID = nil
            return
        }

        if lastActivatedItemID == item.id {
            return
        }

        if pendingItemID == item.id {
            return
        }

        cancelPending()
        pendingItemID = item.id

        timer = Timer.scheduledTimer(withTimeInterval: activationDelay, repeats: false) { [weak self] _ in
            self?.activate(item)
        }
    }

    func cancelPending() {
        timer?.invalidate()
        timer = nil
        pendingItemID = nil
    }

    private var activationDelay: TimeInterval {
        max(Constants.minActivationDelayMs, min(Constants.maxActivationDelayMs, preferences.activationDelayMs)) / 1000
    }

    private func activate(_ item: ShelfItem) {
        defer {
            pendingItemID = nil
            timer = nil
        }

        let app: NSRunningApplication?
        if let running = item.runningApplication() {
            app = running
        } else if let bundleID = item.bundleIdentifier {
            app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        } else {
            app = nil
        }

        guard let app else { return }

        // Keep activation as gentle as possible to avoid breaking the drag session.
        app.activate(options: [])
        lastActivatedItemID = item.id
    }
}
