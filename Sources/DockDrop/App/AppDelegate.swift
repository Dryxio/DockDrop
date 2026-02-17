import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = UserPreferences.shared
    private let dragMonitor = DragMonitor()
    private let runningAppsProvider = RunningAppsProvider()
    private let shelfWindowController = ShelfWindowController()
    private let appActivator = AppActivator()
    private lazy var settingsWindowController = SettingsWindowController(preferences: preferences)

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        bindCoreComponents()
        startMonitoring()
        ensureAccessibilityPrompted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.title = "DockDrop"
            button.image = NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: "DockDrop")
            button.imagePosition = .imageLeading
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Check Accessibility", action: #selector(checkAccessibility), keyEquivalent: "a"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DockDrop", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        item.menu = menu
        statusItem = item
    }

    private func bindCoreComponents() {
        shelfWindowController.onHoverItemChanged = { [weak self] item in
            self?.appActivator.handleHover(on: item)
        }

        runningAppsProvider.$shelfItems
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.shelfWindowController.updateItems(items)
            }
            .store(in: &cancellables)

        preferences.$shelfPosition
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.shelfWindowController.applyPreferences() }
            .store(in: &cancellables)

        preferences.$iconSize
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.shelfWindowController.applyPreferences() }
            .store(in: &cancellables)

        preferences.$labelDisplayMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.shelfWindowController.applyPreferences() }
            .store(in: &cancellables)

        preferences.$appearance
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.shelfWindowController.applyPreferences() }
            .store(in: &cancellables)

        preferences.$pinnedBundleIdentifiers
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.runningAppsProvider.refresh() }
            .store(in: &cancellables)
    }

    private func startMonitoring() {
        dragMonitor.onDragStarted = { [weak self] point in
            self?.runningAppsProvider.refresh()
            self?.shelfWindowController.show(at: point)
        }

        dragMonitor.onDragMoved = { [weak self] point in
            self?.shelfWindowController.handleDragLocation(point)
        }

        dragMonitor.onDragEnded = { [weak self] in
            self?.appActivator.cancelPending()
            self?.shelfWindowController.hide()
        }

        dragMonitor.start()
    }

    private func ensureAccessibilityPrompted() {
        guard !AccessibilityHelper.isTrusted() else { return }

        _ = AccessibilityHelper.isTrusted(prompt: true)

        let alert = NSAlert()
        alert.messageText = "Accessibility Access Needed"
        alert.informativeText = "DockDrop needs Accessibility access to monitor drag events globally and bring target apps forward while dragging."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AccessibilityHelper.openSystemSettings()
        }
    }

    @objc
    private func openSettings() {
        settingsWindowController.show()
    }

    @objc
    private func checkAccessibility() {
        if AccessibilityHelper.isTrusted() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Already Enabled"
            alert.informativeText = "DockDrop currently has the required Accessibility permission."
            alert.runModal()
        } else {
            _ = AccessibilityHelper.isTrusted(prompt: true)
            AccessibilityHelper.openSystemSettings()
        }
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
