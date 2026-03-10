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
    var onAutoSizeCompleted: (() -> Void)?
    var onThemeChanged: ((WidgetTheme) -> Void)?

    var isPositionLocked: Bool { isLocked }

    private let settingsStore: SettingsStore
    private let shouldAutoSizeOnInitialRender: Bool
    private var hostingView: NSHostingView<WidgetPanelContentView>?
    private var isApplyingAutoSize = false
    private var autoFitRevision = 0
    private var suppressAutoFitUntil: Date = .distantPast

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMoveMonitor: Any?
    private var localMoveMonitor: Any?

    private var dragAnchorScreenPoint: NSPoint?
    private var dragOrigin: NSPoint = .zero
    private var pendingMouseDownEvent: NSEvent?
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

    /// Height of the top strip that acts as the drag handle for moving the widget.
    private let dragHandleHeight: CGFloat = 18

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

    override var canBecomeKey: Bool { hasEditableContent(config.content) }

    override var canBecomeMain: Bool { false }

    // Override sendEvent so our drag/resize/context-menu logic fires BEFORE
    // the event reaches any child view (e.g. NSTextView inside TextEditor).
    // Without this, NSTextView absorbs all mouse events and blocks drag + right-click.
    override func sendEvent(_ event: NSEvent) {
        guard !isPassive else {
            super.sendEvent(event)
            return
        }

        switch event.type {
        case .leftMouseDown:
            if isClickOnResizeHandle(event) {
                // Resize handle area — let SwiftUI's DragGesture own this event.
                super.sendEvent(event)
            } else if isClickInDragZone(event) {
                mouseDown(with: event)
                if pendingMouseDownEvent == nil {
                    // mouseDown short-circuited (locked, etc.) — forward normally.
                    super.sendEvent(event)
                }
                // Otherwise pendingMouseDownEvent is set; we suppress the event from
                // the view hierarchy and will re-dispatch it in mouseUp if it's a click.
            } else {
                // Not in drag zone — forward directly to content for interaction.
                mouseDown(with: event)
                super.sendEvent(event)
            }

        case .leftMouseDragged:
            mouseDragged(with: event)
            if !isDragging {
                // Haven't committed to a window drag yet — let views handle it too
                // (e.g. SwiftUI DragGesture on the resize handle, or small cursor movement).
                super.sendEvent(event)
            }

        case .leftMouseUp:
            let wasResizing = isResizing
            // Content-area clicks have no dragAnchorScreenPoint; they need mouseUp
            // forwarded to SwiftUI so buttons (shortcut launcher, playback controls, etc.) fire.
            // Drag-zone clicks forward the full cycle inside mouseUp itself.
            let hadDragAnchor = dragAnchorScreenPoint != nil
            mouseUp(with: event)
            if !hadDragAnchor || wasResizing {
                super.sendEvent(event)
            }

        case .rightMouseDown:
            // Forward directly to the hosting view so SwiftUI's .contextMenu fires
            // instead of NSTextView's built-in editing menu.
            if let hostingView {
                hostingView.rightMouseDown(with: event)
            } else {
                super.sendEvent(event)
            }

        default:
            super.sendEvent(event)
        }
    }

    // Returns true when a left-mouse-down event lands on the resize corner zone.
    private func isClickOnResizeHandle(_ event: NSEvent) -> Bool {
        resizeHandle(atWindowPoint: event.locationInWindow) != nil
    }

    // Returns true when a left-mouse-down event lands in the top drag handle strip.
    private func isClickInDragZone(_ event: NSEvent) -> Bool {
        guard !isLocked else { return false }
        return event.locationInWindow.y >= frame.height - dragHandleHeight
    }

    private func resizeHandle(atWindowPoint point: NSPoint) -> ResizeHandle? {
        guard !isLocked, !isPassive, (isActive || isResizing) else {
            return nil
        }

        // Only bottom-right corner is a resize zone.
        let edgeHit: CGFloat = 14
        let nearRight = point.x >= frame.width - edgeHit
        let nearBottom = point.y <= edgeHit

        if nearBottom && nearRight { return .bottomRight }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        guard !isPassive else {
            return
        }

        activate()

        // Locked widgets don't move.
        guard !isLocked else {
            super.mouseDown(with: event)
            return
        }

        // Only the top drag handle strip initiates window dragging.
        // Clicks elsewhere pass through to interactive content (buttons, text fields, etc.).
        let localPoint = event.locationInWindow
        let inDragZone = localPoint.y >= frame.height - dragHandleHeight

        guard inDragZone else {
            super.mouseDown(with: event)
            return
        }

        // Store event but DO NOT forward to SwiftUI yet.
        // We can't know at mouseDown time whether this is a click or a drag.
        // Forwarding now would fire overlay buttons (e.g. Duplicate) the moment
        // the user begins a drag gesture. Instead, forward the full click cycle
        // in mouseUp only if no drag occurred.
        pendingMouseDownEvent = event
        dragAnchorScreenPoint = NSEvent.mouseLocation
        dragOrigin = frame.origin
        isDragging = false
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
            // Require a minimum movement before committing to a window drag.
            // This prevents accidental drags and lets small movements fall
            // through to the view hierarchy (text cursor, resize gesture, etc.).
            guard hypot(delta.x, delta.y) >= 5 else { return }
            isDragging = true
            NSCursor.closedHand.set()
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
            pendingMouseDownEvent = nil
            finishDragging()
        } else {
            // It was a click, not a drag — now forward the full click cycle to SwiftUI
            // so buttons (Edit, Duplicate, Lock, Remove) fire on release, not press.
            if let pending = pendingMouseDownEvent {
                // Become key before forwarding so TextEditor can become first responder.
                if canBecomeKey, !isKeyWindow {
                    makeKey()
                }
                super.mouseDown(with: pending)
                pendingMouseDownEvent = nil
            }
            super.mouseUp(with: event)
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

    func forceAutoSizeToContent() {
        scheduleInitialAutoSizePasses()
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
            },
            onThemeChanged: { [weak self] theme in
                self?.onThemeChanged?(theme)
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
            scheduleInitialAutoSizePasses()
        }
    }

    private func scheduleInitialAutoSizePasses() {
        autoFitRevision += 1
        let revision = autoFitRevision
        // Multiple passes absorb async data arriving after first paint (network/provider fetches).
        // Late passes compact widgets after real data replaces placeholders.
        let delays: [TimeInterval] = [0.04, 0.18, 0.42, 0.95, 1.8, 3.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.autoFitRevision == revision else { return }
                self.applyContentFitIfNeeded()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { [weak self] in
            guard let self, self.autoFitRevision == revision else { return }
            self.onAutoSizeCompleted?()
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

        // Clamp widget size to fit within screen if it's too large
        let maxWidth = screenFrame.width - 56
        let maxHeight = screenFrame.height - 56
        if config.size.width.cgFloat > maxWidth || config.size.height.cgFloat > maxHeight {
            let clampedWidth = min(config.size.width.cgFloat, maxWidth)
            let clampedHeight = min(config.size.height.cgFloat, maxHeight)
            config.size = WidgetSize(width: clampedWidth.double, height: clampedHeight.double)
            setContentSize(NSSize(width: clampedWidth, height: clampedHeight))
        }

        let targetOrigin: NSPoint

        if let position = config.position {
            targetOrigin = NSPoint(x: position.x.cgFloat, y: position.y.cgFloat)
        } else {
            // Default: top-right area, snapped to 40pt grid for clean alignment.
            let gridStep: CGFloat = 40
            let rawX = screenFrame.maxX - config.size.width.cgFloat - 40
            let rawY = screenFrame.maxY - config.size.height.cgFloat - 40
            targetOrigin = NSPoint(
                x: screenFrame.minX + ((rawX - screenFrame.minX) / gridStep).rounded() * gridStep,
                y: screenFrame.minY + ((rawY - screenFrame.minY) / gridStep).rounded() * gridStep
            )
        }

        // Always clamp to visible screen area
        let clampedOrigin = NSPoint(
            x: min(max(targetOrigin.x, screenFrame.minX + 8), screenFrame.maxX - frame.width - 8),
            y: min(max(targetOrigin.y, screenFrame.minY + 8), screenFrame.maxY - frame.height - 8)
        )

        setFrameOrigin(clampedOrigin)
        config.position = WidgetPosition(x: clampedOrigin.x.double, y: clampedOrigin.y.double)
    }

    private func installEventMonitors() {
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.deactivateIfOutside(from: event)
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            // If click lands inside a passive widget, activate immediately so the
            // very next click is received. This prevents "click twice to interact".
            let clickPoint = NSEvent.mouseLocation
            if self.isPassive, self.frame.contains(clickPoint) {
                self.setPassiveMode(enabled: false)
                self.activate()
            } else {
                self.deactivateIfOutside(from: event)
            }
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
        // Restore cursor to contextual move/resize cursor if still hovering.
        updateCursor(forScreenPoint: NSEvent.mouseLocation)
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

        updateCursor(forScreenPoint: point)
    }

    private func updateCursor(forScreenPoint point: NSPoint) {
        guard !isDragging else {
            NSCursor.closedHand.set()
            return
        }

        guard isPointerInside else {
            NSCursor.arrow.set()
            return
        }

        guard !isLocked else {
            NSCursor.arrow.set()
            return
        }

        let localPoint = convertPoint(fromScreen: point)
        if let handle = resizeHandle(atWindowPoint: localPoint) {
            handle.cursor.set()
            return
        }

        // Show move cursor only in the top drag handle strip.
        if localPoint.y >= frame.height - dragHandleHeight {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func scheduleHoverActivation() {
        guard isPassive, isPointerInside, hoverActivationWorkItem == nil else {
            return
        }

        // Activate immediately — no delay. The mouseMoved event always fires before
        // a click, so by the time the user clicks, ignoresMouseEvents is already false.
        hoverActivationWorkItem = nil
        setPassiveMode(enabled: false)
        isHoverEngaged = true
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
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
        updateCursor(forScreenPoint: NSEvent.mouseLocation)
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
            // User is explicitly taking control of size; cancel pending auto-fit passes
            // and temporarily suppress auto-fit so manual resize does not jump/reset.
            autoFitRevision += 1
            suppressAutoFitUntil = Date().addingTimeInterval(1.2)
            resizeSession = ResizeSession(
                handle: handle,
                initialMouseLocation: currentPoint,
                initialFrame: frame
            )
            isResizing = true
        }

        guard let resizeSession else {
            return
        }

        let targetFrame = frameForResize(session: resizeSession, currentPoint: currentPoint)

        if abs(frame.width - targetFrame.width) < 0.5,
           abs(frame.height - targetFrame.height) < 0.5,
           abs(frame.origin.x - targetFrame.origin.x) < 0.5,
           abs(frame.origin.y - targetFrame.origin.y) < 0.5 {
            return
        }

        applyResizeFrame(targetFrame)
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
        updateCursor(forScreenPoint: NSEvent.mouseLocation)

        if !isPointerInside && !isActive {
            setPassiveMode(enabled: true)
        }
    }

    private func frameForResize(session: ResizeSession, currentPoint: NSPoint) -> NSRect {
        let initialFrame = session.initialFrame
        let dx = currentPoint.x - session.initialMouseLocation.x
        let dy = currentPoint.y - session.initialMouseLocation.y

        var rawMinX = initialFrame.minX
        var rawMaxX = initialFrame.maxX
        var rawMinY = initialFrame.minY
        var rawMaxY = initialFrame.maxY

        if session.handle.affectsLeft { rawMinX += dx }
        if session.handle.affectsRight { rawMaxX += dx }
        if session.handle.affectsBottom { rawMinY += dy }
        if session.handle.affectsTop { rawMaxY += dy }

        var width = max(1, rawMaxX - rawMinX)
        var height = max(1, rawMaxY - rawMinY)
        let minSize = minimumSize
        let maxSize = maximumSize
        width = width.clamped(minSize.width, maxSize.width)
        height = height.clamped(minSize.height, maxSize.height)

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

    private func applyPresetResize(size: WidgetSize, anchoredTop: CGFloat, anchoredLeft: CGFloat) {
        let proposedFrame = NSRect(
            x: anchoredLeft,
            y: anchoredTop - size.height.cgFloat,
            width: size.width.cgFloat,
            height: size.height.cgFloat
        )
        let targetFrame = frameClampedToVisibleDesktop(proposedFrame)
        setFrame(targetFrame, display: true)
        config.size = size
        config.position = WidgetPosition(x: targetFrame.origin.x.double, y: targetFrame.origin.y.double)
        installContent(allowAutoSize: false)
    }

    private func applyResizeFrame(_ resizedFrame: NSRect) {
        let clampedFrame = frameClampedToVisibleDesktop(resizedFrame)
        setFrame(clampedFrame, display: true)
        config.size = WidgetSize(width: clampedFrame.width.double, height: clampedFrame.height.double)
        config.position = WidgetPosition(x: clampedFrame.origin.x.double, y: clampedFrame.origin.y.double)
        // Refresh content so WidgetRenderer's scaleFactor adapts during drag.
        installContent(allowAutoSize: false)
    }

    private func applyWallpaperSizeSnap() {
        let snappedSize = config.size.snappedToAppleWallpaperPreset()
        let targetWidth = snappedSize.width.cgFloat
        let targetHeight = snappedSize.height.cgFloat

        if abs(frame.width - targetWidth) < 0.5, abs(frame.height - targetHeight) < 0.5 {
            return
        }

        let anchoredTop = frame.maxY
        let snappedFrame = NSRect(
            x: frame.origin.x,
            y: anchoredTop - targetHeight,
            width: targetWidth,
            height: targetHeight
        )
        let clampedFrame = frameClampedToVisibleDesktop(snappedFrame)
        setFrame(clampedFrame, display: true)
        config.size = snappedSize
        config.position = WidgetPosition(x: clampedFrame.origin.x.double, y: clampedFrame.origin.y.double)
    }

    private var minimumSize: CGSize {
        return inferredMinimumSize()
    }

    private var maximumSize: CGSize {
        let defaultFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1600, height: 1000)
        // Widgets should never consume more than ~65% of screen in either dimension.
        let screenCap = WidgetSize(
            width: (defaultFrame.width * 0.65).double,
            height: (defaultFrame.height * 0.65).double
        )
        let configured = config.maxSize ?? screenCap
        return CGSize(
            width: max(minimumSize.width, min(configured.width.cgFloat, screenCap.width.cgFloat)),
            height: max(minimumSize.height, min(configured.height.cgFloat, screenCap.height.cgFloat))
        )
    }

    private func inferredMinimumSize() -> CGSize {
        let preferred = inferredPreferredContentSize(for: config.content)
        let floorSize = minimumSizeFloor(for: config.content)
        return CGSize(
            width: max(floorSize.width, floor(preferred.width * 0.52)),
            height: max(floorSize.height, floor(preferred.height * 0.52))
        )
    }

    private func minimumSizeFloor(for component: ComponentConfig) -> CGSize {
        switch component.type {
        case .analogClock, .progressRing, .pomodoro:
            return CGSize(width: 118, height: 118)
        case .githubRepoStats, .stock, .crypto, .weather, .clock, .date, .countdown, .timer, .stopwatch, .dayProgress, .yearProgress:
            return CGSize(width: 144, height: 82)
        case .note, .quote, .text, .newsHeadlines, .calendarNext, .reminders, .checklist, .habitTracker:
            return CGSize(width: 156, height: 96)
        case .vstack, .hstack, .container:
            return CGSize(width: 152, height: 88)
        default:
            return CGSize(width: 148, height: 86)
        }
    }

    private func inferredPreferredContentSize(for component: ComponentConfig) -> CGSize {
        if component.type == .spacer {
            return CGSize(width: 0, height: 0)
        }

        if component.type == .divider {
            if (component.direction ?? "horizontal").lowercased() == "vertical" {
                return CGSize(width: max(1, CGFloat(component.thickness ?? 1)), height: 1)
            }
            return CGSize(width: 1, height: max(1, CGFloat(component.thickness ?? 1)))
        }

        if component.type == .vstack {
            let children = (component.children ?? (component.child.map { [$0] } ?? []))
                .filter { $0.type != .spacer }
            guard !children.isEmpty else { return CGSize(width: 0, height: 0) }
            let spacing = CGFloat(component.spacing ?? 6)
            let childSizes = children.map(inferredPreferredContentSize(for:))
            let width = childSizes.map(\.width).max() ?? 260
            let height = childSizes.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, childSizes.count - 1))
            return CGSize(width: width + 8, height: height + 8)
        }

        if component.type == .hstack {
            let children = component.children ?? (component.child.map { [$0] } ?? [])
            let meaningful = children.filter { $0.type != .divider && $0.type != .spacer }
            guard !meaningful.isEmpty else { return CGSize(width: 260, height: 120) }
            let spacing = CGFloat(component.spacing ?? 8)
            let childSizes = meaningful.map(inferredPreferredContentSize(for:))
            let maxColumns = min(meaningful.count, 4)
            var best: CGSize?
            var bestArea = CGFloat.greatestFiniteMagnitude
            let screenWidth = NSScreen.main?.visibleFrame.width ?? 1440
            let hardWidthCap = max(CGFloat(420), screenWidth * 0.55)

            for columns in 1...maxColumns {
                var rowWidths: [CGFloat] = []
                var rowHeights: [CGFloat] = []

                var index = 0
                while index < childSizes.count {
                    let end = min(index + columns, childSizes.count)
                    let row = childSizes[index..<end]
                    let rowWidth = row.map(\.width).reduce(0, +) + spacing * CGFloat(max(0, row.count - 1))
                    let rowHeight = row.map(\.height).max() ?? 0
                    rowWidths.append(rowWidth)
                    rowHeights.append(rowHeight)
                    index = end
                }

                var width = (rowWidths.max() ?? 0) + 12
                let height = rowHeights.reduce(0, +) + spacing * CGFloat(max(0, rowHeights.count - 1)) + 12

                // Penalize overly wide layouts so compactness wins in practice.
                if width > hardWidthCap {
                    width += (width - hardWidthCap) * 2
                }

                let area = width * height
                if area < bestArea {
                    bestArea = area
                    best = CGSize(width: width, height: height)
                }
            }

            if let best {
                return best
            }
            return CGSize(width: 260, height: 120)
        }

        if component.type == .container {
            let child = component.child ?? component.children?.first
            let childSize = child.map(inferredPreferredContentSize(for:)) ?? CGSize(width: 220, height: 120)
            let edgeInsets = component.padding ?? .medium
            return CGSize(
                width: childSize.width + edgeInsets.leading + edgeInsets.trailing,
                height: childSize.height + edgeInsets.top + edgeInsets.bottom
            )
        }

        return inferredPreferredSizeForLeaf(component)
    }

    private func inferredPreferredSizeForLeaf(_ component: ComponentConfig) -> CGSize {
        switch component.type {
        case .analogClock:
            return CGSize(width: 140, height: 140)
        case .githubRepoStats:
            if component.showComponents?.contains("description") == true {
                return CGSize(width: 296, height: 92)
            }
            return CGSize(width: 280, height: 62)
        case .timer:
            if component.style?.lowercased() == "ring" {
                return CGSize(width: 150, height: 150)
            }
            return CGSize(width: 210, height: 86)
        case .progressRing, .pomodoro:
            return CGSize(width: 150, height: 150)
        case .battery:
            if component.style?.lowercased() == "ring" {
                return CGSize(width: 140, height: 140)
            }
            return CGSize(width: 180, height: 80)
        case .weather:
            if component.style?.lowercased() == "compact" {
                return CGSize(width: 170, height: 70)
            }
            return CGSize(width: 190, height: 100)
        case .clock:
            return CGSize(width: 165, height: 62)
        case .worldClocks:
            let count = max(1, component.clocks?.count ?? 1)
            return CGSize(width: 240, height: CGFloat(42 + (count * 26)))
        case .text:
            let text = component.content ?? ""
            let count = text.count
            let width = min(320, max(110, 64 + (count * 4)))
            let lineCount = max(1, min(4, Int(ceil(Double(max(1, count)) / 28.0))))
            let fontSize = CGFloat(component.size ?? 13)
            let lineHeight = max(12, fontSize * 1.22)
            let height = (CGFloat(lineCount) * lineHeight) + 8
            return CGSize(width: CGFloat(width), height: height)
        case .checklist:
            let itemCount = max(1, min(component.items?.count ?? 3, component.maxItems ?? 6))
            return CGSize(width: 160, height: CGFloat(28 + itemCount * 22))
        case .calendarNext, .reminders, .newsHeadlines, .habitTracker:
            let itemCount = max(1, min(component.maxItems ?? 4, 6))
            return CGSize(width: 200, height: CGFloat(28 + itemCount * 24))
        case .quote:
            return CGSize(width: 160, height: 60)
        case .virtualPet:
            return CGSize(width: 280, height: 320)
        case .countdown, .date, .stock, .crypto, .dayProgress, .yearProgress, .systemStats:
            return CGSize(width: 185, height: 82)
        default:
            return CGSize(width: 160, height: 92)
        }
    }

    private func hasEditableContent(_ component: ComponentConfig) -> Bool {
        if component.type == .note && component.editable == true {
            return true
        }
        if component.type == .checklist {
            return true
        }
        if component.type == .virtualPet {
            return true
        }
        if let children = component.children, children.contains(where: { hasEditableContent($0) }) {
            return true
        }
        if let child = component.child {
            return hasEditableContent(child)
        }
        return false
    }

    private func flattenedComponents(from component: ComponentConfig) -> [ComponentConfig] {
        var items: [ComponentConfig] = [component]

        if let child = component.child {
            items.append(contentsOf: flattenedComponents(from: child))
        }

        if let children = component.children {
            for nested in children {
                items.append(contentsOf: flattenedComponents(from: nested))
            }
        }

        return items
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
        guard Date() >= suppressAutoFitUntil else {
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

        let minSize = minimumSize
        let maxSize = maximumSize
        let preferred = inferredPreferredContentSize(for: config.content)
        let estimatedOuter = estimatedOuterSize(for: preferred)

        // The hosting view can report inflated fittingSize because the root renderer uses
        // maxWidth/maxHeight frames. Detect and correct those cases with content heuristics
        // so widgets don't keep large empty tails.
        let preferredWidth = preferred.width.isFinite ? preferred.width : fit.width
        let preferredHeight = preferred.height.isFinite ? preferred.height : fit.height

        let widthLooksInflated = fit.width > preferredWidth * 1.15
        let heightLooksInflated = fit.height > preferredHeight * 1.15

        var targetWidth: CGFloat
        if widthLooksInflated {
            targetWidth = ceil(preferredWidth)
        } else {
            // Tight fit — widgets should be compact, no wasted space
            let softCap = preferredWidth * 1.03
            targetWidth = ceil(max(min(fit.width, softCap), preferredWidth * 0.92))
        }

        var targetHeight: CGFloat
        if heightLooksInflated {
            targetHeight = ceil(preferredHeight)
        } else {
            let softCap = preferredHeight * 1.03
            targetHeight = ceil(max(min(fit.height, softCap), preferredHeight * 0.92))
        }

        targetWidth = targetWidth.clamped(minSize.width, maxSize.width)
        targetHeight = targetHeight.clamped(minSize.height, maxSize.height)

        // Hard compactness cap: widgets are compact by nature — no dead space allowed.
        targetWidth = min(targetWidth, ceil(estimatedOuter.width * 1.04))
        targetHeight = min(targetHeight, ceil(estimatedOuter.height * 1.04))
        targetWidth = targetWidth.clamped(minSize.width, maxSize.width)
        targetHeight = targetHeight.clamped(minSize.height, maxSize.height)

        let current = frame
        if abs(current.width - targetWidth) < 4, abs(current.height - targetHeight) < 4 {
            return
        }

        let anchoredTop = current.maxY
        let proposedFrame = NSRect(
            x: current.origin.x,
            y: anchoredTop - targetHeight,
            width: targetWidth,
            height: targetHeight
        )
        let targetFrame = frameClampedToVisibleDesktop(proposedFrame)

        // Use immediate (non-animated) resize so windowDidMove doesn't fire
        // with stale isApplyingAutoSize=false during an async animation.
        isApplyingAutoSize = true
        setFrame(targetFrame, display: true)
        isApplyingAutoSize = false

        config.size = WidgetSize(width: targetFrame.width.double, height: targetFrame.height.double)
        let position = WidgetPosition(x: targetFrame.origin.x.double, y: targetFrame.origin.y.double)
        config.position = position
        onSizeChanged?(config.size)
        onPositionChanged?(position)
    }

    private func estimatedOuterSize(for preferredContent: CGSize) -> CGSize {
        let insets = config.padding
        let estimatedWidth = preferredContent.width + insets.leading.cgFloat + insets.trailing.cgFloat
        let estimatedHeight = preferredContent.height + insets.top.cgFloat + insets.bottom.cgFloat
        return CGSize(width: max(estimatedWidth, 1), height: max(estimatedHeight, 1))
    }

    private func frameClampedToVisibleDesktop(_ input: NSRect) -> NSRect {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            return input
        }

        let width = min(input.width, screenFrame.width)
        let height = min(input.height, screenFrame.height)
        let minX = screenFrame.minX
        let maxX = screenFrame.maxX - width
        let minY = screenFrame.minY
        let maxY = screenFrame.maxY - height

        let x = input.origin.x.clamped(minX, maxX)
        let y = input.origin.y.clamped(minY, maxY)
        return NSRect(x: x, y: y, width: width, height: height)
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
    let onThemeChanged: (WidgetTheme) -> Void

    var body: some View {
        WidgetRenderer(config: config)
            .scaleEffect(scale)
            .opacity(isDragging ? 0.60 : 1)
            .brightness(isHoverEngaged ? 0.02 : 0)
            .overlay(
                RoundedRectangle(cornerRadius: config.cornerRadius.cgFloat, style: .continuous)
                    .stroke(Color.accentColor.opacity(isActive ? 0.32 : 0), lineWidth: isActive ? 1 : 0)
            )
            .onHover { _ in }
            .overlay(alignment: .top) {
                if isHoverEngaged && !isPassive {
                    WidgetHoverToolbar(
                        isLocked: isLocked,
                        onToggleLock: onToggleLock,
                        onEdit: onEdit,
                        onRemove: onRemove
                    )
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
                    ForEach(WidgetSizePreset.nativeResizeOrder) { preset in
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

                Menu("Theme") {
                    ForEach(WidgetTheme.activeThemes, id: \.rawValue) { theme in
                        Button {
                            onThemeChanged(theme)
                        } label: {
                            HStack {
                                Text(theme.displayName)
                                if theme == config.theme.canonical {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
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

private extension ComponentType {
    var isLayoutType: Bool {
        self == .vstack || self == .hstack || self == .container
    }
}

// MARK: - Hover Toolbar

private struct WidgetHoverToolbar: View {
    let isLocked: Bool
    let onToggleLock: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            toolbarButton(
                icon: isLocked ? "lock.fill" : "arrow.up.and.down.and.arrow.left.and.right",
                tooltip: isLocked ? "Unlock to Move" : "Move (Drag to Reposition)",
                isHighlighted: !isLocked
            ) {
                onToggleLock()
            }

            toolbarButton(
                icon: "pencil",
                tooltip: "Edit Widget"
            ) {
                onEdit()
            }

            toolbarButton(
                icon: "xmark",
                tooltip: "Remove Widget",
                isDestructive: true
            ) {
                onRemove()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func toolbarButton(
        icon: String,
        tooltip: String,
        isHighlighted: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(
                    isDestructive ? Color.red.opacity(0.85) :
                    isHighlighted ? Color.accentColor :
                    Color.primary.opacity(0.75)
                )
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Resize Handles

private struct ResizeHandlesOverlay: View {
    let onResizeDrag: (ResizeHandle) -> Void
    let onResizeEnd: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(ResizeHandle.visibleHandles) { handle in
                    ZStack {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 0.5)
                    }
                    .frame(width: 20, height: 20)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                    .position(handle.position(in: geometry.size))
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

    static var visibleHandles: [ResizeHandle] {
        [.bottomRight]
    }

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
        let inset: CGFloat = 9
        switch self {
        case .topLeft:
            return CGPoint(x: inset, y: inset)
        case .top:
            return CGPoint(x: size.width / 2, y: inset)
        case .topRight:
            return CGPoint(x: size.width - inset, y: inset)
        case .right:
            return CGPoint(x: size.width - inset, y: size.height / 2)
        case .bottomRight:
            return CGPoint(x: size.width - inset, y: size.height - inset)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height - inset)
        case .bottomLeft:
            return CGPoint(x: inset, y: size.height - inset)
        case .left:
            return CGPoint(x: inset, y: size.height / 2)
        }
    }
}

private struct ResizeSession {
    let handle: ResizeHandle
    let initialMouseLocation: NSPoint
    let initialFrame: NSRect
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
