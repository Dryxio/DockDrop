import Foundation

final class DockOrderProvider {
    private let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
    private var indexByBundleIdentifier: [String: Int] = [:]

    init() {
        refresh()
    }

    func refresh() {
        let entries = dockDefaults?.array(forKey: "persistent-apps") as? [[String: Any]] ?? []
        var order: [String] = []

        for entry in entries {
            guard let tileData = entry["tile-data"] as? [String: Any] else { continue }

            if let bundleIdentifier = tileData["bundle-identifier"] as? String,
               !bundleIdentifier.isEmpty {
                order.append(bundleIdentifier)
                continue
            }

            if let fileData = tileData["file-data"] as? [String: Any],
               let urlString = fileData["_CFURLString"] as? String,
               let appURL = URL(string: urlString),
               let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier,
               !bundleIdentifier.isEmpty {
                order.append(bundleIdentifier)
            }
        }

        var seen: Set<String> = []
        let uniqueOrder = order.filter { seen.insert($0).inserted }
        indexByBundleIdentifier = Dictionary(uniqueKeysWithValues: uniqueOrder.enumerated().map { ($1, $0) })
    }

    func order(items: [ShelfItem]) -> [ShelfItem] {
        guard !indexByBundleIdentifier.isEmpty else { return items }

        return items.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = rank(for: lhs.element)
                let rhsRank = rank(for: rhs.element)

                switch (lhsRank, rhsRank) {
                case let (l?, r?):
                    if l != r { return l < r }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func rank(for item: ShelfItem) -> Int? {
        guard let bundleIdentifier = item.bundleIdentifier else { return nil }
        return indexByBundleIdentifier[bundleIdentifier]
    }
}
