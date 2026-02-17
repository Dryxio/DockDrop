import AppKit
import Combine

final class RunningAppsProvider: ObservableObject {
    @Published private(set) var shelfItems: [ShelfItem] = []

    private let preferences: UserPreferences
    private let dockOrderProvider = DockOrderProvider()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []

    init(preferences: UserPreferences = .shared) {
        self.preferences = preferences
        setupObservers()
        refresh()
    }

    deinit {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            workspaceCenter.removeObserver(observer)
        }

        let distributedCenter = DistributedNotificationCenter.default()
        for observer in distributedObservers {
            distributedCenter.removeObserver(observer)
        }
    }

    func refresh() {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { !$0.isTerminated }
            .filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .map(ShelfItem.init)

        let dockOrdered = dockOrderProvider.order(items: running)
        let pinned = pinnedItems(from: dockOrdered)
        let merged = deduplicate(items: pinned + dockOrdered)
        shelfItems = Array(merged.prefix(Constants.maxVisibleApps))
    }

    private func pinnedItems(from running: [ShelfItem]) -> [ShelfItem] {
        guard !preferences.pinnedBundleIdentifiers.isEmpty else { return [] }

        let map = Dictionary(uniqueKeysWithValues: running.compactMap { item in
            item.bundleIdentifier.map { ($0, item) }
        })

        return preferences.pinnedBundleIdentifiers.compactMap { map[$0] }
    }

    private func deduplicate(items: [ShelfItem]) -> [ShelfItem] {
        var seen: Set<String> = []
        var result: [ShelfItem] = []

        for item in items where !seen.contains(item.id) {
            seen.insert(item.id)
            result.append(item)
        }

        return result
    }

    private func setupObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(workspaceCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })

        workspaceObservers.append(workspaceCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })

        workspaceObservers.append(workspaceCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })

        let distributedCenter = DistributedNotificationCenter.default()
        distributedObservers.append(distributedCenter.addObserver(
            forName: Notification.Name("com.apple.dock.prefchanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dockOrderProvider.refresh()
            self?.refresh()
        })
    }
}
