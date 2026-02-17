import AppKit
import SwiftUI

@MainActor
final class WidgetWindow: NSPanel, NSWindowDelegate {
    private(set) var config: WidgetConfig

    var onEditRequested: (() -> Void)?
    var onRemoveRequested: (() -> Void)?
    var onDuplicateRequested: (() -> Void)?
    var onResizePresetRequested: ((WidgetSizePreset) -> Void)?
    var onLockPositionChanged: ((Bool) -> Void)?
    var onPositionChanged: ((WidgetPosition) -> Void)?
    var onSizeChanged: ((WidgetSize) -> Void)?
    var onDragFeedbackRequested: ((CGRect) -> WidgetDragFeedback)?
    var onDragEnded: (() -> Void)?

    var isPositionLocked: Bool { isLocked }

    private let settingsStore: SettingsStore
    private let shouldAutoSizeOnInitialRender: Bool
    private var hostingView: NSHostingView<WidgetPanelContentView>?
    private var isApplyingAutoSize = false

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMoveMonitor: Any?
    private var localMoveMonitor: Any?

    private var dragAnchorScreenPoint: NSPoint?
    private var dragOrigin: NSPoint = .zero
    private var isDragging = false {
        didSet { refreshContent() }
    }

    private var resizeSession: ResizeSession?
    private var isResizing = false {
        didSet { refreshContent() }
    }

    private var isActive = false {
        didSet { refreshContent() }
    }

    private var isLocked = false {
        didSet { refreshContent() }
    }

    private var isPassive = true {
        didSet {
            ignoresMouseEvents = isPassive
            refreshContent()
        }
    }

    private var isHoverEngaged = false {
        didSet { refreshContent() }
    }

    private var isPointerInside = false {
        didSet { refreshContent() }
    }

    private var hoverActivationWorkItem: DispatchWorkItem?
    private var passivationWorkItem: DispatchWorkItem?

    init(
        config: WidgetConfig,
        settingsStore: SettingsStore,
        shouldAutoSizeOnInitialRender: Bool
    ) {
        self.config = config
        self.settingsStore = settingsStore
        self.shouldAutoSizeOnInitialRender = shouldAutoSizeOnInitialRender

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: config.size.width.cgFloat, height: config.size.height.cgFloat),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        installContent(allowAutoSize: shouldAutoSizeOnInitialRender)
        placeInitialPosition()
        installEventMonitors()
        setPassiveMode(enabled: true)
        WidgetAnimator.animateAppearance(of: self)
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }

        if let globalMoveMonitor {
            NSEvent.removeMonitor(globalMoveMonitor)
        }

        if let localMoveMonitor {
            NSEvent.removeMonitor(localMoveMonitor)
        }

        hoverActivationWorkItem?.cancel()
        passivationWorkItem?.cancel()
    }

    override var canBecomeKey: Bool { false }

    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard !isPassive else {
            return
        }

        activate()

        guard !isLocked else {
            super.mouseDown(with: event)
            return
        }

        dragAnchorScreenPoint = NSEvent.mouseLocation
        dragOrigin = frame.origin
        isDragging = false
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isPassive,
              !isLocked,
              !isResizing,
              let dragAnchorScreenPoint else {
            return
        }

        let current = NSEvent.mouseLocation
        let delta = NSPoint(x: current.x - dragAnchorScreenPoint.x, y: current.y - dragAnchorScreenPoint.y)
        let nextOrigin = NSPoint(x: dragOrigin.x + delta.x, y: dragOrigin.y + delta.y)
        var targetOrigin = nextOrigin

        if !isDragging {
            isDragging = true
            WidgetAnimator.animateDragStart(of: self)
        }

        if let feedback = onDragFeedbackRequested?(CGRect(origin: nextOrigin, size: frame.size)) {
            targetOrigin = feedback.origin
        }

        setFrameOrigin(targetOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if isResizing {
            endResizeDrag()
            return
        }

        defer {
            dragAnchorScreenPoint = nil
        }

        guard dragAnchorScreenPoint != nil else {
            if !isPassive {
                activate()
            }
            return
        }

        if isDragging {
            finishDragging()
        } else {
            activate()
        }
    }

    func update(config: WidgetConfig) {
        self.config = config
        setFrame(
            NSRect(
                origin: frame.origin,
                size: NSSize(width: config.size.width.cgFloat, height: config.size.height.cgFloat)
            ),
            display: true,
            animate: true
        )
        installContent(allowAutoSize: false)
    }

    func updatePosition(_ position: WidgetPosition) {
        config.position = position
    }

    func setLocked(_ locked: Bool) {
        isLocked = locked
    }

    private func configureWindow() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        delegate = self

        let desktopLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
        level = NSWindow.Level(rawValue: desktopLevel)

        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
    }

    private func installContent(allowAutoSize: Bool = false) {
        let rootView = WidgetPanelContentView(
            config: config,
            isActive: isActive,
            isDragging: isDragging,
            isResizing: isResizing,
            isLocked: isLocked,
            isPassive: isPassive,
            isHoverEngaged: isHoverEngaged,
            onEdit: { [weak self] in self?.onEditRequested?() },
            onRemove: { [weak self] in self?.onRemoveRequested?() },
            onDuplicate: { [weak self] in self?.onDuplicateRequested?() },
            onResizePreset: { [weak self] preset in self?.onResizePresetRequested?(preset) },
            onToggleLock: { [weak self] in
                guard let self else { return }
                self.isLocked.toggle()
                self.onLockPositionChanged?(self.isLocked)
            },
            onResizeDrag: { [weak self] handle in
                self?.handleResizeDrag(handle)
            },
            onResizeEnd: { [weak self] in
                self?.endResizeDrag()
            }
        )

        if let hostingView {
            hostingView.rootView = rootView
        } else {
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            contentView = hostingView
            self.hostingView = hostingView
        }

        if allowAutoSize {
            applyContentFitIfNeeded()
        }
    }

    private func refreshContent() {
        guard hostingView != nil else { return }
        installContent(allowAutoSize: false)
    }

    private func placeInitialPosition() {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            return
        }

        let targetOrigin: NSPoint

        if let position = config.position {
            targetOrigin = NSPoint(x: position.x.cgFloat, y: position.y.cgFloat)
        } else {
            targetOrigin = NSPoint(
                x: screenFrame.minX + 48,
                y: screenFrame.maxY - config.size.height.cgFloat - 140
            )
        }

        setFrameOrigin(targetOrigin)
        config.position = WidgetPosition(x: targetOrigin.x.double, y: targetOrigin.y.double)
    }

    private func installEventMonitors() {
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.deactivateIfOutside(from: event)
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.deactivateIfOutside(from: event)
        }

        localMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handlePointerMovement(at: NSEvent.mouseLocation)
            return event
        }

        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            self?.handlePointerMovement(at: NSEvent.mouseLocation)
        }
    }

    private func deactivateIfOutside(from event: NSEvent) {
        guard !isDragging, !isResizing else { return }

        let clickPoint: NSPoint
        if let eventWindow = event.window {
            clickPoint = eventWindow.convertPoint(toScreen: event.locationInWindow)
        } else {
            clickPoint = NSEvent.mouseLocation
        }

        if !frame.contains(clickPoint) {
            deactivate()
            setPassiveMode(enabled: true)
        }
    }

    private func activate() {
        cancelPassivation()
        if isPassive {
            setPassiveMode(enabled: false)
        }
        isActive = true
        isHoverEngaged = true
    }

    private func deactivate() {
        isActive = false
    }

    private func finishDragging() {
        let targetOrigin = snappedOriginIfNeeded(frame.origin)
        WidgetAnimator.animateDragEnd(of: self, to: targetOrigin)
        setFrameOrigin(targetOrigin)

        isDragging = false
        let position = WidgetPosition(x: targetOrigin.x.double, y: targetOrigin.y.double)
        config.position = position
        onPositionChanged?(position)
        onDragEnded?()

        if !isPointerInside && !isActive {
            setPassiveMode(enabled: true)
        }
    }

    private func snappedOriginIfNeeded(_ origin: NSPoint) -> NSPoint {
        guard settingsStore.snapToGrid else {
            return origin
        }

        let step = max(4, settingsStore.gridSize).cgFloat
        return NSPoint(
            x: (origin.x / step).rounded() * step,
            y: (origin.y / step).rounded() * step
        )
    }

    private func handlePointerMovement(at point: NSPoint) {
        let inside = frame.contains(point)
        if inside != isPointerInside {
            isPointerInside = inside
        }

        guard !isDragging, !isResizing else { return }

        if inside {
            cancelPassivation()
            if isPassive {
                scheduleHoverActivation()
            } else {
                isHoverEngaged = true
            }
        } else {
            cancelHoverActivation()
            isHoverEngaged = false
            if !isActive {
                schedulePassivation()
            }
        }
    }

    private func scheduleHoverActivation() {
        guard isPassive, isPointerInside, hoverActivationWorkItem == nil else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hoverActivationWorkItem = nil

            guard self.isPassive,
                  self.isPointerInside,
                  !self.isDragging,
                  !self.isResizing else {
                return
            }

            self.setPassiveMode(enabled: false)
            self.isHoverEngaged = true
        }

        hoverActivationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: workItem)
    }

    private func cancelHoverActivation() {
        hoverActivationWorkItem?.cancel()
        hoverActivationWorkItem = nil
    }

    private func schedulePassivation() {
        guard !isPassive, passivationWorkItem == nil else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.passivationWorkItem = nil

            guard !self.isActive,
                  !self.isDragging,
                  !self.isResizing,
                  !self.isPointerInside else {
                return
            }

            self.setPassiveMode(enabled: true)
        }

        passivationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func cancelPassivation() {
        passivationWorkItem?.cancel()
        passivationWorkItem = nil
    }

    private func setPassiveMode(enabled: Bool) {
        cancelHoverActivation()

        guard isPassive != enabled else {
            ignoresMouseEvents = enabled
            if enabled {
                isActive = false
                isHoverEngaged = false
            }
            return
        }

        isPassive = enabled
        if enabled {
            isActive = false
            isHoverEngaged = false
        }
    }

    private func handleResizeDrag(_ handle: ResizeHandle) {
        guard !isLocked else { return }

        cancelPassivation()
        if isPassive {
            setPassiveMode(enabled: false)
        }
        isActive = true
        isHoverEngaged = true

        let currentPoint = NSEvent.mouseLocation
        if resizeSession == nil || resizeSession?.handle != handle {
            resizeSession = ResizeSession(
                handle: handle,
                initialMouseLocation: currentPoint,
                initialFrame: frame,
                aspectRatio: max(frame.width / max(frame.height, 1), 0.1)
            )
            isResizing = true
        }

        guard let resizeSession else {
            return
        }

        let keepAspectRatio = NSEvent.modifierFlags.contains(.shift)
        let resizedFrame = frameForResize(
            session: resizeSession,
            currentPoint: currentPoint,
            keepAspectRatio: keepAspectRatio
        )
        applyResizeFrame(resizedFrame)
    }

    private func endResizeDrag() {
        guard isResizing || resizeSession != nil else {
            return
        }

        resizeSession = nil
        isResizing = false

        config.position = WidgetPosition(x: frame.origin.x.double, y: frame.origin.y.double)
        onPositionChanged?(config.position ?? WidgetPosition(x: frame.origin.x.double, y: frame.origin.y.double))
        onSizeChanged?(config.size)
        WidgetAnimator.animateResizeRelease(of: self)

        if !isPointerInside && !isActive {
            setPassiveMode(enabled: true)
        }
    }

    private func applyResizeFrame(_ resizedFrame: NSRect) {
        setFrame(resizedFrame, display: true)
        config.size = WidgetSize(width: resizedFrame.width.double, height: resizedFrame.height.double)
        config.position = WidgetPosition(x: resizedFrame.origin.x.double, y: resizedFrame.origin.y.double)
    }

    private func frameForResize(
        session: ResizeSession,
        currentPoint: NSPoint,
        keepAspectRatio: Bool
    ) -> NSRect {
        let initialFrame = session.initialFrame
        let dx = currentPoint.x - session.initialMouseLocation.x
        let dy = currentPoint.y - session.initialMouseLocation.y

        var rawMinX = initialFrame.minX
        var rawMaxX = initialFrame.maxX
        var rawMinY = initialFrame.minY
        var rawMaxY = initialFrame.maxY

        if session.handle.affectsLeft {
            rawMinX += dx
        }

        if session.handle.affectsRight {
            rawMaxX += dx
        }

        if session.handle.affectsBottom {
            rawMinY += dy
        }

        if session.handle.affectsTop {
            rawMaxY += dy
        }

        var width = max(1, rawMaxX - rawMinX)
        var height = max(1, rawMaxY - rawMinY)
        let minSize = minimumSize
        let maxSize = maximumSize

        width = width.clamped(minSize.width, maxSize.width)
        height = height.clamped(minSize.height, maxSize.height)

        if keepAspectRatio {
            let widthDelta = abs(width - initialFrame.width)
            let heightDelta = abs(height - initialFrame.height)
            let shouldDriveByWidth: Bool

            if session.handle.affectsLeft || session.handle.affectsRight {
                if session.handle.affectsTop || session.handle.affectsBottom {
                    shouldDriveByWidth = widthDelta >= heightDelta
                } else {
                    shouldDriveByWidth = true
                }
            } else {
                shouldDriveByWidth = false
            }

            if shouldDriveByWidth {
                height = (width / session.aspectRatio).clamped(minSize.height, maxSize.height)
                width = (height * session.aspectRatio).clamped(minSize.width, maxSize.width)
            } else {
                width = (height * session.aspectRatio).clamped(minSize.width, maxSize.width)
                height = (width / session.aspectRatio).clamped(minSize.height, maxSize.height)
            }
        }

        let horizontal = horizontalEdges(
            for: session.handle,
            initialFrame: initialFrame,
            rawMinX: rawMinX,
            rawMaxX: rawMaxX,
            width: width
        )
        let vertical = verticalEdges(
            for: session.handle,
            initialFrame: initialFrame,
            rawMinY: rawMinY,
            rawMaxY: rawMaxY,
            height: height
        )

        return NSRect(
            x: horizontal.min,
            y: vertical.min,
            width: horizontal.max - horizontal.min,
            height: vertical.max - vertical.min
        )
    }

    private func horizontalEdges(
        for handle: ResizeHandle,
        initialFrame: NSRect,
        rawMinX: CGFloat,
        rawMaxX: CGFloat,
        width: CGFloat
    ) -> (min: CGFloat, max: CGFloat) {
        if handle.affectsLeft && !handle.affectsRight {
            let anchoredMaxX = rawMaxX
            return (anchoredMaxX - width, anchoredMaxX)
        }

        if handle.affectsRight && !handle.affectsLeft {
            let anchoredMinX = rawMinX
            return (anchoredMinX, anchoredMinX + width)
        }

        let centerX = initialFrame.midX
        return (centerX - (width / 2), centerX + (width / 2))
    }

    private func verticalEdges(
        for handle: ResizeHandle,
        initialFrame: NSRect,
        rawMinY: CGFloat,
        rawMaxY: CGFloat,
        height: CGFloat
    ) -> (min: CGFloat, max: CGFloat) {
        if handle.affectsBottom && !handle.affectsTop {
            let anchoredMaxY = rawMaxY
            return (anchoredMaxY - height, anchoredMaxY)
        }

        if handle.affectsTop && !handle.affectsBottom {
            let anchoredMinY = rawMinY
            return (anchoredMinY, anchoredMinY + height)
        }

        let centerY = initialFrame.midY
        return (centerY - (height / 2), centerY + (height / 2))
    }

    private var minimumSize: CGSize {
        let configured = config.minSize ?? WidgetSize(width: 96, height: 64)
        return CGSize(
            width: max(80, configured.width.cgFloat),
            height: max(56, configured.height.cgFloat)
        )
    }

    private var maximumSize: CGSize {
        let defaultFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let configured = config.maxSize ?? WidgetSize(
            width: defaultFrame.width.double,
            height: defaultFrame.height.double
        )
        return CGSize(
            width: max(minimumSize.width, configured.width.cgFloat),
            height: max(minimumSize.height, configured.height.cgFloat)
        )
    }

    func windowDidMove(_ notification: Notification) {
        guard !isDragging, !isResizing else {
            return
        }
        let position = WidgetPosition(x: frame.origin.x.double, y: frame.origin.y.double)
        config.position = position
        onPositionChanged?(position)
    }

    private func applyContentFitIfNeeded() {
        guard !isDragging, !isResizing, !isApplyingAutoSize else {
            return
        }

        guard let hostingView else {
            return
        }

        hostingView.layoutSubtreeIfNeeded()
        let fit = hostingView.fittingSize
        guard fit.width.isFinite, fit.height.isFinite else {
            return
        }

        var targetWidth = ceil(fit.width)
        var targetHeight = ceil(fit.height)
        let minSize = minimumSize
        let maxSize = maximumSize

        targetWidth = targetWidth.clamped(minSize.width, maxSize.width)
        targetHeight = targetHeight.clamped(minSize.height, maxSize.height)

        let current = frame
        if abs(current.width - targetWidth) < 8, abs(current.height - targetHeight) < 8 {
            return
        }

        let anchoredTop = current.maxY
        let targetFrame = NSRect(
            x: current.origin.x,
            y: anchoredTop - targetHeight,
            width: targetWidth,
            height: targetHeight
        )

        isApplyingAutoSize = true
        setFrame(targetFrame, display: true, animate: true)
        isApplyingAutoSize = false

        config.size = WidgetSize(width: targetFrame.width.double, height: targetFrame.height.double)
        let position = WidgetPosition(x: targetFrame.origin.x.double, y: targetFrame.origin.y.double)
        config.position = position
        onSizeChanged?(config.size)
        onPositionChanged?(position)
    }
}

private struct WidgetPanelContentView: View {
    let config: WidgetConfig
    let isActive: Bool
    let isDragging: Bool
    let isResizing: Bool
    let isLocked: Bool
    let isPassive: Bool
    let isHoverEngaged: Bool

    let onEdit: () -> Void
    let onRemove: () -> Void
    let onDuplicate: () -> Void
    let onResizePreset: (WidgetSizePreset) -> Void
    let onToggleLock: () -> Void
    let onResizeDrag: (ResizeHandle) -> Void
    let onResizeEnd: () -> Void

    var body: some View {
        WidgetRenderer(config: config)
            .scaleEffect(scale)
            .opacity(isDragging ? 0.60 : 1)
            .brightness(isHoverEngaged ? 0.02 : 0)
            .overlay(
                RoundedRectangle(cornerRadius: config.cornerRadius.cgFloat, style: .continuous)
                    .stroke(Color.accentColor.opacity(isActive ? 0.32 : 0), lineWidth: isActive ? 1 : 0)
            )
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(8)
                }
            }
            .overlay {
                if showsResizeHandles {
                    ResizeHandlesOverlay(
                        onResizeDrag: onResizeDrag,
                        onResizeEnd: onResizeEnd
                    )
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isHoverEngaged)
            .animation(.easeInOut(duration: 0.18), value: isActive)
            .animation(.easeInOut(duration: 0.18), value: isDragging)
            .animation(.spring(response: 0.28, dampingFraction: 0.74, blendDuration: 0.12), value: isResizing)
            .contextMenu {
                Button("Edit Widget") {
                    onEdit()
                }

                Menu("Resize") {
                    ForEach(WidgetSizePreset.allCases) { preset in
                        Button(preset.title) {
                            onResizePreset(preset)
                        }
                    }
                }

                Button("Refresh Data") {}
                    .disabled(true)

                Button("Duplicate") {
                    onDuplicate()
                }

                Button(isLocked ? "Unlock Position" : "Lock Position") {
                    onToggleLock()
                }

                Divider()

                Button("Remove Widget", role: .destructive) {
                    onRemove()
                }
            }
    }

    private var scale: CGFloat {
        if isDragging { return 1.03 }
        if isResizing { return 1.01 }
        if isActive { return 1.01 }
        if isHoverEngaged { return 1.005 }
        return 1
    }

    private var showsResizeHandles: Bool {
        (isActive || isResizing) && !isPassive && !isLocked
    }
}

private struct ResizeHandlesOverlay: View {
    let onResizeDrag: (ResizeHandle) -> Void
    let onResizeEnd: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(ResizeHandle.visibleHandles) { handle in
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 8, height: 8)
                    }
                    .frame(width: 18, height: 18)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                    .position(handle.position(in: geometry.size))
                    .onHover { inside in
                        if inside {
                            handle.cursor.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                onResizeDrag(handle)
                            }
                            .onEnded { _ in
                                onResizeEnd()
                            }
                    )
                }
            }
        }
    }
}

private enum ResizeHandle: String, CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var id: String { rawValue }

    static var visibleHandles: [ResizeHandle] { [.bottomRight] }

    var affectsLeft: Bool {
        self == .topLeft || self == .left || self == .bottomLeft
    }

    var affectsRight: Bool {
        self == .topRight || self == .right || self == .bottomRight
    }

    var affectsTop: Bool {
        self == .topLeft || self == .top || self == .topRight
    }

    var affectsBottom: Bool {
        self == .bottomLeft || self == .bottom || self == .bottomRight
    }

    var cursor: NSCursor {
        switch self {
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        case .topLeft, .bottomRight:
            return .widgetResizeDiagonalNWSE
        case .topRight, .bottomLeft:
            return .widgetResizeDiagonalNESW
        }
    }

    func position(in size: CGSize) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(x: 0, y: 0)
        case .top:
            return CGPoint(x: size.width / 2, y: 0)
        case .topRight:
            return CGPoint(x: size.width, y: 0)
        case .right:
            return CGPoint(x: size.width, y: size.height / 2)
        case .bottomRight:
            return CGPoint(x: max(0, size.width - 9), y: max(0, size.height - 9))
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height)
        case .bottomLeft:
            return CGPoint(x: 0, y: size.height)
        case .left:
            return CGPoint(x: 0, y: size.height / 2)
        }
    }
}

private struct ResizeSession {
    let handle: ResizeHandle
    let initialMouseLocation: NSPoint
    let initialFrame: NSRect
    let aspectRatio: CGFloat
}

private extension Double {
    var cgFloat: CGFloat { CGFloat(self) }
}

private extension CGFloat {
    var double: Double { Double(self) }

    func clamped(_ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, minValue), maxValue)
    }
}

private extension NSCursor {
    static let widgetResizeDiagonalNWSE: NSCursor = {
        let image = diagonalCursorImage(symbol: "arrow.up.left.and.arrow.down.right")
        return NSCursor(image: image, hotSpot: NSPoint(x: image.size.width / 2, y: image.size.height / 2))
    }()

    static let widgetResizeDiagonalNESW: NSCursor = {
        let image = diagonalCursorImage(symbol: "arrow.up.right.and.arrow.down.left")
        return NSCursor(image: image, hotSpot: NSPoint(x: image.size.width / 2, y: image.size.height / 2))
    }()

    private static func diagonalCursorImage(symbol: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let fallback = NSImage(size: size)

        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .semibold)) else {
            return fallback
        }

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        base.draw(in: NSRect(x: 1, y: 1, width: 16, height: 16))
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
