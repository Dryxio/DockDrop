import AppKit

final class ShelfView: NSVisualEffectView {
    var onHoverItemChanged: ((ShelfItem?) -> Void)?

    var items: [ShelfItem] = [] {
        didSet { rebuild() }
    }

    var iconSize: CGFloat = Constants.mediumIconSize {
        didSet { rebuild() }
    }

    var labelDisplayMode: LabelDisplayMode = .hover {
        didSet { updateLabelVisibility() }
    }

    var shelfPosition: ShelfPosition = .bottom {
        didSet { layoutItems() }
    }

    private var itemViews: [ShelfItemView] = []
    private var hoveredItemID: String?
    private var currentCursorInView: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .menu
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = isVertical ? bounds.width / 2 : bounds.height / 2
        layoutItems()
    }

    func updateHover(screenPoint: NSPoint) {
        guard let window else { return }

        let pointInWindow = window.convertPoint(fromScreen: screenPoint)
        let pointInView = convert(pointInWindow, from: nil)

        currentCursorInView = pointInView
        layoutItems()

        let hovered = itemViews.first { $0.frame.contains(pointInView) }
        let hoveredID = hovered?.item.id

        guard hoveredID != hoveredItemID else { return }
        hoveredItemID = hoveredID

        updateLabelVisibility()
        onHoverItemChanged?(hovered?.item)
    }

    func clearHover() {
        hoveredItemID = nil
        currentCursorInView = nil

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            for view in itemViews {
                view.scale = 1.0
            }
            layoutItems()
        }

        updateLabelVisibility()
        onHoverItemChanged?(nil)
    }

    /// Returns the intrinsic content width/height for the current items at base scale.
    func baseShelfSize() -> NSSize {
        let count = CGFloat(max(items.count, 1))
        let itemDim = iconSize + Constants.shelfItemSpacing
        let totalItems = count * itemDim - Constants.shelfItemSpacing
        let padding = Constants.shelfSidePadding * 2

        if isVertical {
            return NSSize(width: iconSize + padding, height: totalItems + padding)
        } else {
            return NSSize(width: totalItems + padding, height: iconSize + padding)
        }
    }

    // MARK: - Private

    private var isVertical: Bool {
        shelfPosition == .left || shelfPosition == .right
    }

    private func rebuild() {
        for view in itemViews {
            view.removeFromSuperview()
        }

        itemViews = items.map { item in
            let view = ShelfItemView(item: item, baseIconSize: iconSize)
            addSubview(view)
            return view
        }

        layoutItems()
        updateLabelVisibility()
    }

    private func layoutItems() {
        guard !itemViews.isEmpty else { return }

        let maxScale = Constants.magnificationMaxScale
        let radius = Constants.magnificationEffectRadius

        // Compute scales based on cursor distance
        var scales = [CGFloat](repeating: 1.0, count: itemViews.count)

        if let cursor = currentCursorInView {
            // Compute base center positions first (at scale 1.0) to get cursor distance
            let baseCenters = computeBaseCenters()

            for (i, center) in baseCenters.enumerated() {
                let distance: CGFloat
                if isVertical {
                    distance = abs(cursor.y - center)
                } else {
                    distance = abs(cursor.x - center)
                }

                if distance < radius {
                    let ratio = distance / radius
                    scales[i] = 1.0 + (maxScale - 1.0) * 0.5 * (1.0 + cos(ratio * .pi))
                }
            }
        }

        // Apply scales
        for (i, view) in itemViews.enumerated() {
            view.scale = scales[i]
        }

        // Layout items along the primary axis
        if isVertical {
            layoutVertical(scales: scales)
        } else {
            layoutHorizontal(scales: scales)
        }
    }

    private func computeBaseCenters() -> [CGFloat] {
        let spacing = Constants.shelfItemSpacing
        let padding = Constants.shelfSidePadding

        if isVertical {
            // Top to bottom
            var y = bounds.height - padding - iconSize / 2
            var centers = [CGFloat]()
            for _ in itemViews {
                centers.append(y)
                y -= iconSize + spacing
            }
            return centers
        } else {
            // Left to right
            var x = padding + iconSize / 2
            var centers = [CGFloat]()
            for _ in itemViews {
                centers.append(x)
                x += iconSize + spacing
            }
            return centers
        }
    }

    private func layoutHorizontal(scales: [CGFloat]) {
        let spacing = Constants.shelfItemSpacing
        let padding = Constants.shelfSidePadding

        // Calculate total width of magnified items
        var totalWidth: CGFloat = padding
        for (i, _) in itemViews.enumerated() {
            let scaledSize = iconSize * scales[i]
            if i > 0 { totalWidth += spacing }
            totalWidth += scaledSize
        }
        totalWidth += padding

        // Center the items in the view (the window will adjust width)
        var x: CGFloat = (bounds.width - totalWidth) / 2 + padding

        for (i, view) in itemViews.enumerated() {
            let scaledSize = iconSize * scales[i]

            // Anchor at bottom for bottom shelf, at top for top shelf
            let y: CGFloat
            switch shelfPosition {
            case .bottom:
                y = Constants.shelfSidePadding / 2
            case .top:
                y = bounds.height - scaledSize - Constants.shelfSidePadding / 2
            default:
                y = (bounds.height - scaledSize) / 2
            }

            view.frame = NSRect(x: x, y: y, width: scaledSize, height: scaledSize)
            x += scaledSize + spacing
        }
    }

    private func layoutVertical(scales: [CGFloat]) {
        let spacing = Constants.shelfItemSpacing
        let padding = Constants.shelfSidePadding

        // Calculate total height
        var totalHeight: CGFloat = padding
        for (i, _) in itemViews.enumerated() {
            let scaledSize = iconSize * scales[i]
            if i > 0 { totalHeight += spacing }
            totalHeight += scaledSize
        }
        totalHeight += padding

        // Start from top
        var y: CGFloat = bounds.height - (bounds.height - totalHeight) / 2 - padding

        for (i, view) in itemViews.enumerated() {
            let scaledSize = iconSize * scales[i]
            y -= scaledSize

            // Anchor at the shelf edge
            let x: CGFloat
            switch shelfPosition {
            case .left:
                x = Constants.shelfSidePadding / 2
            case .right:
                x = bounds.width - scaledSize - Constants.shelfSidePadding / 2
            default:
                x = (bounds.width - scaledSize) / 2
            }

            view.frame = NSRect(x: x, y: y, width: scaledSize, height: scaledSize)
            y -= spacing
        }
    }

    private func updateLabelVisibility() {
        for view in itemViews {
            let isHovered = view.item.id == hoveredItemID

            switch labelDisplayMode {
            case .always:
                view.showLabel(true)
            case .never:
                view.showLabel(false)
            case .hover:
                view.showLabel(isHovered)
            }
        }
    }
}

// MARK: - ShelfItemView

private final class ShelfItemView: NSView {
    let item: ShelfItem
    let baseIconSize: CGFloat

    var scale: CGFloat = 1.0

    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init(item: ShelfItem, baseIconSize: CGFloat) {
        self.item = item
        self.baseIconSize = baseIconSize
        super.init(frame: NSRect(x: 0, y: 0, width: baseIconSize, height: baseIconSize))

        wantsLayer = true

        imageView.image = item.icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.frame = bounds

        label.stringValue = item.name
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isHidden = true
        label.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85)
        label.isBezeled = false
        label.drawsBackground = true
        label.layer?.cornerRadius = 4
        label.wantsLayer = true
        label.layer?.masksToBounds = true

        addSubview(imageView)
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds

        // Position label centered above the icon
        let labelWidth: CGFloat = max(baseIconSize + 20, 80)
        let labelHeight: CGFloat = 18
        let labelX = bounds.midX - labelWidth / 2
        let labelY = bounds.maxY + 4
        label.frame = NSRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
    }

    func showLabel(_ show: Bool) {
        label.isHidden = !show
    }
}
