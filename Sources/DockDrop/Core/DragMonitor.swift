import AppKit

final class DragMonitor {
    var onDragStarted: ((NSPoint) -> Void)?
    var onDragMoved: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?

    private let preferences: UserPreferences

    private var globalMonitor: Any?
    private var keyMonitor: Any?
    private var localMonitor: Any?

    private var isMouseDown = false
    private var dragActive = false
    private var mouseDownPoint: NSPoint?
    private var dragPasteboardChangeCountAtMouseDown: Int = NSPasteboard(name: .drag).changeCount

    init(preferences: UserPreferences = .shared) {
        self.preferences = preferences
    }

    deinit {
        stop()
    }

    func start() {
        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event)
        }

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKey(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKey(event)
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            isMouseDown = true
            dragActive = false
            mouseDownPoint = NSEvent.mouseLocation
            dragPasteboardChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount

        case .leftMouseDragged:
            let location = NSEvent.mouseLocation

            if !dragActive,
               isMouseDown,
               let start = mouseDownPoint,
               distance(from: start, to: location) >= Constants.dragThreshold,
               shouldTreatAsActiveDrag() {
                dragActive = true
                onDragStarted?(location)
            }

            if dragActive {
                onDragMoved?(location)
            }

        case .leftMouseUp:
            if dragActive {
                onDragEnded?()
            }
            resetState()

        default:
            break
        }
    }

    private func handleKey(_ event: NSEvent) {
        // Escape
        guard event.keyCode == 53 else { return }

        if dragActive {
            onDragEnded?()
        }
        resetState()
    }

    private func shouldTreatAsActiveDrag() -> Bool {
        if preferences.dragVisibilityMode == .all {
            return true
        }

        let dragPboard = NSPasteboard(name: .drag)
        // Avoid false positives from stale drag-pasteboard content from a previous drag session.
        guard dragPboard.changeCount != dragPasteboardChangeCountAtMouseDown else {
            return false
        }

        if let items = dragPboard.pasteboardItems {
            for item in items {
                if let raw = item.string(forType: .fileURL),
                   let url = URL(string: raw),
                   url.isFileURL {
                    return true
                }
            }
        }

        let urls = dragPboard.readObjects(
            forClasses: [NSURL.self],
            options: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true]
        ) as? [URL]

        return !(urls?.isEmpty ?? true)
    }

    private func resetState() {
        isMouseDown = false
        dragActive = false
        mouseDownPoint = nil
    }

    private func distance(from a: NSPoint, to b: NSPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
