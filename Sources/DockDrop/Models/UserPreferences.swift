import Foundation
import Combine

enum ShelfPosition: String, CaseIterable, Identifiable {
    case bottom
    case top
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottom: return "Bottom"
        case .top: return "Top"
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

enum DragVisibilityMode: String, CaseIterable, Identifiable {
    case fileOnly
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fileOnly: return "File Drags Only"
        case .all: return "All Drags"
        }
    }
}

enum LabelDisplayMode: String, CaseIterable, Identifiable {
    case hover
    case always
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hover: return "On Hover"
        case .always: return "Always"
        case .never: return "Never"
        }
    }
}

enum ShelfAppearance: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum ShelfIconSize: Int, CaseIterable, Identifiable {
    case small = 32
    case medium = 48
    case large = 64

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @Published var shelfPosition: ShelfPosition {
        didSet { defaults.set(shelfPosition.rawValue, forKey: Key.shelfPosition) }
    }

    @Published var activationDelayMs: Double {
        didSet { defaults.set(activationDelayMs, forKey: Key.activationDelayMs) }
    }

    @Published var dragVisibilityMode: DragVisibilityMode {
        didSet { defaults.set(dragVisibilityMode.rawValue, forKey: Key.dragVisibilityMode) }
    }

    @Published var iconSize: ShelfIconSize {
        didSet { defaults.set(iconSize.rawValue, forKey: Key.iconSize) }
    }

    @Published var labelDisplayMode: LabelDisplayMode {
        didSet { defaults.set(labelDisplayMode.rawValue, forKey: Key.labelDisplayMode) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    @Published var appearance: ShelfAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    @Published var pinnedBundleIdentifiers: [String] {
        didSet { defaults.set(pinnedBundleIdentifiers, forKey: Key.pinnedBundleIdentifiers) }
    }

    private let defaults: UserDefaults

    private enum Key {
        static let shelfPosition = "shelfPosition"
        static let activationDelayMs = "activationDelayMs"
        static let dragVisibilityMode = "dragVisibilityMode"
        static let iconSize = "iconSize"
        static let labelDisplayMode = "labelDisplayMode"
        static let launchAtLogin = "launchAtLogin"
        static let appearance = "appearance"
        static let pinnedBundleIdentifiers = "pinnedBundleIdentifiers"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        shelfPosition = ShelfPosition(rawValue: defaults.string(forKey: Key.shelfPosition) ?? "") ?? .bottom

        let savedDelay = defaults.object(forKey: Key.activationDelayMs) as? Double
        activationDelayMs = savedDelay ?? Constants.defaultActivationDelayMs

        dragVisibilityMode = DragVisibilityMode(rawValue: defaults.string(forKey: Key.dragVisibilityMode) ?? "") ?? .fileOnly

        let savedIconSize = defaults.integer(forKey: Key.iconSize)
        iconSize = ShelfIconSize(rawValue: savedIconSize) ?? .medium

        labelDisplayMode = LabelDisplayMode(rawValue: defaults.string(forKey: Key.labelDisplayMode) ?? "") ?? .hover

        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)

        appearance = ShelfAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .auto

        pinnedBundleIdentifiers = defaults.array(forKey: Key.pinnedBundleIdentifiers) as? [String] ?? []
    }
}
