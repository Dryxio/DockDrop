import AppKit

final class ShelfView: NSView {
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
        didSet {
            layoutPill()
            _ = layoutItems(animated: false)
        }
    }

    private let backgroundPill = NSVisualEffectView()
    private var itemViews: [ShelfItemView] = []
    private var hoveredItemID: String?
    private var hoverPointInView: NSPoint?
    private var isLayingOut = false

    /// The thickness of the glass pill (base icon + padding).
    var pillThickness: CGFloat {
        iconSize + Constants.shelfHeightPadding
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        backgroundPill.material = .menu
        backgroundPill.blendingMode = .behindWindow
        backgroundPill.state = .active
        backgroundPill.wantsLayer = true
        addSubview(backgroundPill)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutPill()
        guard !isLayingOut else { return }
        isLayingOut = true
        _ = layoutItems(animated: false)
        isLayingOut = false
    }

    func updateHover(screenPoint: NSPoint) {
        guard let window else { return }

        let pointInWindow = window.convertPoint(fromScreen: screenPoint)
        let pointInView = convert(pointInWindow, from: nil)

        if interactiveRegionContains(pointInView) {
            setHover(pointInView, animated: true)
        } else {
            setHover(nil, animated: true)
        }
    }

    func clearHover() {
        setHover(nil, animated: true)
    }

    /// Window size — pre-allocates room for one magnified icon and label overhead.
    func baseShelfSize() -> NSSize {
        let count = CGFloat(max(items.count, 1))
        let itemDim = iconSize + Constants.shelfItemSpacing
        let totalItems = count * itemDim - Constants.shelfItemSpacing
        let sidePadding = Constants.shelfSidePadding * 2
        let magnificationExtra = iconSize * (Constants.magnificationMaxScale - 1)
        let labelOverhead: CGFloat = 24
        let maxCrossDim = iconSize * Constants.magnificationMaxScale + Constants.shelfHeightPadding + labelOverhead

        if isVertical {
            return NSSize(width: maxCrossDim, height: totalItems + sidePadding + magnificationExtra)
        } else {
            return NSSize(width: totalItems + sidePadding + magnificationExtra, height: maxCrossDim)
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

        _ = layoutItems(animated: false)
        updateLabelVisibility()
    }

    private func layoutPill() {
        let thickness = pillThickness

        switch shelfPosition {
        case .bottom:
            backgroundPill.frame = NSRect(x: 0, y: 0, width: bounds.width, height: thickness)
        case .top:
            backgroundPill.frame = NSRect(x: 0, y: bounds.height - thickness, width: bounds.width, height: thickness)
        case .left:
            backgroundPill.frame = NSRect(x: 0, y: 0, width: thickness, height: bounds.height)
        case .right:
            backgroundPill.frame = NSRect(x: bounds.width - thickness, y: 0, width: thickness, height: bounds.height)
        }

        backgroundPill.layer?.cornerRadius = thickness / 2
    }

    private func setHover(_ pointInView: NSPoint?, animated: Bool) {
        if pointInView == nil, hoverPointInView == nil, hoveredItemID == nil {
            return
        }

        if let pointInView {
            if let existing = hoverPointInView {
                let factor = Constants.hoverSmoothingFactor
                hoverPointInView = NSPoint(
                    x: existing.x + (pointInView.x - existing.x) * factor,
                    y: existing.y + (pointInView.y - existing.y) * factor
                )
            } else {
                hoverPointInView = pointInView
            }
        } else {
            hoverPointInView = nil
        }

        let hoverChanged = layoutItems(animated: animated)
        updateLabelVisibility()

        if hoverChanged {
            onHoverItemChanged?(item(for: hoveredItemID))
        }
    }

    private func layoutItems(animated: Bool) -> Bool {
        let previousHoveredID = hoveredItemID

        guard !itemViews.isEmpty else {
            hoveredItemID = nil
            return previousHoveredID != nil
        }

        let interaction = interactionState()
        let scales = interaction.scales
        hoveredItemID = interaction.hoveredIndex.map { itemViews[$0].item.id }

        for (i, view) in itemViews.enumerated() {
            view.scale = scales[i]
        }

        let shouldAnimate = animated && (previousHoveredID != hoveredItemID || hoverPointInView == nil)
        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Constants.hoverAnimationDuration
                context.allowsImplicitAnimation = true
                applyLayout(scales: scales, animated: true)
            }
        } else {
            applyLayout(scales: scales, animated: false)
        }

        return previousHoveredID != hoveredItemID
    }

    private func applyLayout(scales: [CGFloat], animated: Bool) {
        if isVertical {
            layoutVertical(scales: scales, animated: animated)
        } else {
            layoutHorizontal(scales: scales, animated: animated)
        }
    }

    private func layoutHorizontal(scales: [CGFloat], animated: Bool) {
        let spacing = Constants.shelfItemSpacing
        let padding = Constants.shelfSidePadding

        var totalWidth: CGFloat = padding
        for (i, _) in itemViews.enumerated() {
            if i > 0 { totalWidth += spacing }
            totalWidth += iconSize * scales[i]
        }
        totalWidth += padding

        var x: CGFloat = (bounds.width - totalWidth) / 2 + padding
        let pillInset = Constants.shelfHeightPadding / 2

        for (i, view) in itemViews.enumerated() {
            let scaledSize = iconSize * scales[i]

            let y: CGFloat
            switch shelfPosition {
            case .bottom:
                y = pillInset
            case .top:
                y = bounds.height - scaledSize - pillInset
            default:
                y = (bounds.height - scaledSize) / 2
            }

            setFrame(NSRect(x: x, y: y, width: scaledSize, height: scaledSize), for: view, animated: animated)
            x += scaledSize + spacing
        }
    }

    private func layoutVertical(scales: [CGFloat], animated: Bool) {
        let spacing = Constants.shelfItemSpacing
        let padding = Constants.shelfSidePadding

        var totalHeight: CGFloat = padding
        for (i, _) in itemViews.enumerated() {
            if i > 0 { totalHeight += spacing }
            totalHeight += iconSize * scales[i]
        }
        totalHeight += padding

        var y: CGFloat = bounds.height - (bounds.height - totalHeight) / 2 - padding
        let pillInset = Constants.shelfHeightPadding / 2

        for (i, view) in itemViews.enumerated() {
            let scaledSize = iconSize * scales[i]
            y -= scaledSize

            let x: CGFloat
            switch shelfPosition {
            case .left:
                x = pillInset
            case .right:
                x = bounds.width - scaledSize - pillInset
            default:
                x = (bounds.width - scaledSize) / 2
            }

            setFrame(NSRect(x: x, y: y, width: scaledSize, height: scaledSize), for: view, animated: animated)
            y -= spacing
        }
    }

    private func setFrame(_ frame: NSRect, for view: ShelfItemView, animated: Bool) {
        if animated {
            view.animator().frame = frame
        } else {
            view.frame = frame
        }
    }

    private func interactionState() -> (scales: [CGFloat], hoveredIndex: Int?) {
        guard let hoverPointInView else {
            return ([CGFloat](repeating: 1.0, count: itemViews.count), nil)
        }

        let axisPoint = isVertical ? hoverPointInView.y : hoverPointInView.x
        let baseCenters = baseItemCenters()
        let maxScale = Constants.magnificationMaxScale
        let influenceRadius = iconSize * Constants.hoverInfluenceRadiusMultiplier

        var scales = [CGFloat](repeating: 1.0, count: itemViews.count)
        var hoveredIndex: Int?
        var strongestInfluence: CGFloat = 0

        for (i, center) in baseCenters.enumerated() {
            let distance = abs(axisPoint - center)
            let influence = max(0, 1 - (distance / influenceRadius))
            let easedInfluence = influence * influence
            scales[i] = 1 + (maxScale - 1) * easedInfluence

            if easedInfluence > strongestInfluence {
                strongestInfluence = easedInfluence
                hoveredIndex = i
            }
        }

        if strongestInfluence < Constants.hoverSelectionThreshold {
            hoveredIndex = nil
        }

        return (scales, hoveredIndex)
    }

    private func baseItemCenters() -> [CGFloat] {
        let spacing = Constants.shelfItemSpacing
        let count = CGFloat(itemViews.count)
        let totalItems = (count * iconSize) + max(0, count - 1) * spacing

        if isVertical {
            let topCenter = bounds.midY + (totalItems / 2) - (iconSize / 2)
            return (0..<itemViews.count).map { index in
                topCenter - CGFloat(index) * (iconSize + spacing)
            }
        } else {
            let leftCenter = bounds.midX - (totalItems / 2) + (iconSize / 2)
            return (0..<itemViews.count).map { index in
                leftCenter + CGFloat(index) * (iconSize + spacing)
            }
        }
    }

    private func interactiveRegionContains(_ pointInView: NSPoint) -> Bool {
        let hitSlop = iconSize * Constants.hoverHitSlopMultiplier
        return backgroundPill.frame.insetBy(dx: -hitSlop, dy: -hitSlop).contains(pointInView)
    }

    private func item(for id: String?) -> ShelfItem? {
        guard let id else { return nil }
        return itemViews.first(where: { $0.item.id == id })?.item
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
