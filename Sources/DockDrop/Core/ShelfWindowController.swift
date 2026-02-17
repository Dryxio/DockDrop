import AppKit

final class ShelfWindowController {
    var onHoverItemChanged: ((ShelfItem?) -> Void)? {
        didSet { shelfView.onHoverItemChanged = onHoverItemChanged }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    private let preferences: UserPreferences
    private let panel: ShelfPanel
    private let shelfView: ShelfView

    private var items: [ShelfItem] = []
    private var activeScreen: NSScreen?

    init(preferences: UserPreferences = .shared) {
        self.preferences = preferences
        self.shelfView = ShelfView(frame: .zero)
        self.panel = ShelfPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 100),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        configurePanel()
        applyPreferences()
    }

    func updateItems(_ items: [ShelfItem]) {
        self.items = items
        shelfView.items = items
        relayoutIfNeeded()
    }

    func show(at dragLocation: NSPoint) {
        activeScreen = screen(containing: dragLocation) ?? NSScreen.main
        applyPreferences()
        relayoutIfNeeded()

        guard !panel.isVisible else {
            handleDragLocation(dragLocation)
            return
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }

        shelfView.clearHover()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: {
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        })
    }

    func handleDragLocation(_ dragLocation: NSPoint) {
        if let screen = screen(containing: dragLocation), screen != activeScreen {
            activeScreen = screen
            relayoutIfNeeded()
        }

        shelfView.updateHover(screenPoint: dragLocation)
    }

    func applyPreferences() {
        shelfView.iconSize = CGFloat(preferences.iconSize.rawValue)
        shelfView.labelDisplayMode = preferences.labelDisplayMode
        shelfView.shelfPosition = preferences.shelfPosition

        switch preferences.appearance {
        case .auto:
            panel.appearance = nil
        case .light:
            panel.appearance = NSAppearance(named: .aqua)
        case .dark:
            panel.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func configurePanel() {
        panel.contentView = shelfView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
    }

    private func relayoutIfNeeded() {
        guard let screen = activeScreen ?? NSScreen.main else { return }

        let frame = frameForShelf(on: screen)
        panel.setFrame(frame, display: true)
    }

    private func frameForShelf(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let baseIconSize = CGFloat(preferences.iconSize.rawValue)
        let maxIconSize = baseIconSize * Constants.magnificationMaxScale
        let isVertical = preferences.shelfPosition == .left || preferences.shelfPosition == .right

        let baseSize = shelfView.baseShelfSize()

        // Pre-allocate the cross-axis dimension for max magnification so icons aren't clipped
        let width: CGFloat
        let height: CGFloat

        if isVertical {
            width = maxIconSize + Constants.shelfSidePadding * 2
            height = baseSize.height
        } else {
            width = baseSize.width
            height = maxIconSize + Constants.shelfSidePadding * 2
        }

        let xCentered = visible.midX - width / 2
        let yBottom = visible.minY + Constants.shelfScreenMargin
        let yTop = visible.maxY - height - Constants.shelfScreenMargin
        let xLeft = visible.minX + Constants.shelfScreenMargin
        let xRight = visible.maxX - width - Constants.shelfScreenMargin
        let yCentered = visible.midY - height / 2

        switch preferences.shelfPosition {
        case .bottom:
            return NSRect(x: xCentered, y: yBottom, width: width, height: height)
        case .top:
            return NSRect(x: xCentered, y: yTop, width: width, height: height)
        case .left:
            return NSRect(x: xLeft, y: yCentered, width: width, height: height)
        case .right:
            return NSRect(x: xRight, y: yCentered, width: width, height: height)
        }
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(point)
        }
    }
}

private final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
