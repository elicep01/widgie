import AppKit
import Foundation
import SwiftUI

struct WidgetSummary: Identifiable {
    let id: UUID
    let name: String
    let theme: WidgetTheme
    let size: WidgetSize
    let isLocked: Bool
    let position: WidgetPosition?
}

@MainActor
final class WidgetManager {
    var onEditRequested: ((WidgetConfig) -> Void)?
    var onWidgetListChanged: (([String]) -> Void)?
    var onWidgetSummariesChanged: (([WidgetSummary]) -> Void)?

    private let store: WidgetStore
    private let settingsStore: SettingsStore
    private let fileManager = FileManager.default
    private let interactionController = WidgetInteractionController()
    private let positionManager = WidgetPositionManager()
    private let alignmentGuideOverlay = AlignmentGuideOverlayWindow()
    private let ownProcessID = Int32(ProcessInfo.processInfo.processIdentifier)
    private var windows: [UUID: WidgetWindow] = [:]

    init(store: WidgetStore, settingsStore: SettingsStore) {
        self.store = store
        self.settingsStore = settingsStore
    }

    func createOrUpdateWidget(_ config: WidgetConfig, isLocked: Bool? = nil) {
        let normalized = normalizedForWallpaper(config)

        if let window = windows[normalized.id] {
            window.update(config: normalized)
            resolveOverlapIfNeeded(for: window)
            if let isLocked {
                window.setLocked(isLocked)
            }
            store.save(window.config, isLocked: window.isPositionLocked)
            notifyWidgetListChanged()
            return
        }

        let shouldAutoArrange = normalized.position == nil
        let window = WidgetWindow(
            config: normalized,
            settingsStore: settingsStore,
            shouldAutoSizeOnInitialRender: shouldAutoArrange
        )
        if let isLocked {
            window.setLocked(isLocked)
        }

        let resolvedOrigin: CGPoint
        if shouldAutoArrange {
            // First-render placement avoids pane widgets, likely native widgets, and desktop icon lanes.
            resolvedOrigin = nextAutoOrigin(for: window.frame.size, excluding: normalized.id)
        } else {
            // Keep restored placement stable, but recover from off-screen or pane-overlap states.
            resolvedOrigin = resolvedStoredOrigin(for: window)
        }
        window.setFrameOrigin(resolvedOrigin)
        window.updatePosition(WidgetPosition(x: resolvedOrigin.x.double, y: resolvedOrigin.y.double))

        interactionController.attach(to: window)
        wireCallbacks(for: window)
        windows[normalized.id] = window
        WidgetAnimator.animateAppearance(of: window)

        // Persist resolved placement/size immediately so relaunch restores exact state.
        store.save(window.config, isLocked: window.isPositionLocked)
        notifyWidgetListChanged()
    }

    @discardableResult
    func removeWidget(id: UUID) -> Bool {
        guard let window = windows.removeValue(forKey: id) else {
            return false
        }

        WidgetAnimator.animateRemoval(of: window) {
            window.orderOut(nil)
            window.close()
        }

        alignmentGuideOverlay.hide()
        store.delete(id: id)
        notifyWidgetListChanged()

        return true
    }

    @discardableResult
    func removeWidget(named name: String) -> Bool {
        guard let config = windows.values
            .map(\.config)
            .first(where: { $0.name.lowercased() == name.lowercased() }) else {
            return false
        }

        return removeWidget(id: config.id)
    }

    func widgetNames() -> [String] {
        windows.values
            .map(\.config.name)
            .sorted()
    }

    func widgetSummaries() -> [WidgetSummary] {
        windows.values
            .map { window in
                WidgetSummary(
                    id: window.config.id,
                    name: window.config.name,
                    theme: window.config.theme,
                    size: window.config.size,
                    isLocked: window.isPositionLocked,
                    position: window.config.position
                )
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func widgetConfig(for id: UUID) -> WidgetConfig? {
        windows[id]?.config
    }

    func restoreWidgets() {
        let envelopes = store.loadAllEnvelopes()
        for envelope in envelopes {
            createOrUpdateWidget(envelope.config, isLocked: envelope.metadata.isLocked)
        }
        notifyWidgetListChanged()
    }

    func reloadFromStore() {
        for window in windows.values {
            window.orderOut(nil)
            window.close()
        }

        windows.removeAll()
        alignmentGuideOverlay.hide()
        restoreWidgets()
    }

    func applyTheme(_ theme: WidgetTheme) {
        for (id, window) in windows {
            var updated = window.config
            updated.theme = theme
            updated.background = BackgroundConfig.default(for: theme)
            windows[id]?.update(config: updated)
            store.save(updated, isLocked: window.isPositionLocked)
        }
        notifyWidgetListChanged()
    }

    func autoLayoutWidgets() {
        let screens = orderedPlacementScreens()
        guard !screens.isEmpty else {
            return
        }

        let sortedIDs = windows.keys.sorted { lhs, rhs in
            let left = windows[lhs]?.config.name ?? ""
            let right = windows[rhs]?.config.name ?? ""
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }

        var states = screens.map { screen in
            ScreenPlacementState(
                frame: screen.visibleFrame,
                occupied: placementObstacles(in: screen.visibleFrame, excluding: nil)
            )
        }

        for id in sortedIDs {
            guard let window = windows[id] else { continue }
            let size = window.frame.size
            guard let choice = bestPlacementChoice(for: size, states: states) else { continue }

            window.setFrameOrigin(choice.origin)
            states[choice.index].occupied.append(
                CGRect(origin: choice.origin, size: size).insetBy(dx: -12, dy: -12)
            )

            var updated = window.config
            updated.position = WidgetPosition(x: window.frame.origin.x.double, y: window.frame.origin.y.double)
            window.update(config: updated)
            store.save(updated, isLocked: window.isPositionLocked)
        }

        notifyWidgetListChanged()
    }

    @discardableResult
    func duplicateWidget(id: UUID) -> UUID? {
        guard let source = windows[id]?.config else { return nil }

        var copy = source
        copy.id = UUID()
        copy.name = uniquedName(from: source.name)

        if let position = source.position {
            copy.position = WidgetPosition(x: position.x + 20, y: position.y - 20)
        } else {
            copy.position = WidgetPosition(x: 80, y: 420)
        }

        createOrUpdateWidget(copy, isLocked: false)
        return copy.id
    }

    @discardableResult
    func resizeWidget(id: UUID, preset: WidgetSizePreset) -> Bool {
        guard let window = windows[id] else { return false }
        var updated = window.config
        updated.size = preset.size
        window.update(config: normalizedForWallpaper(updated))
        resolveOverlapIfNeeded(for: window)
        store.save(window.config, isLocked: window.isPositionLocked)
        notifyWidgetListChanged()
        return true
    }

    @discardableResult
    func setWidgetLocked(id: UUID, isLocked: Bool) -> Bool {
        guard let window = windows[id] else { return false }
        window.setLocked(isLocked)
        store.save(window.config, isLocked: isLocked)
        notifyWidgetListChanged()
        return true
    }

    private func wireCallbacks(for window: WidgetWindow) {
        window.onEditRequested = { [weak self, weak window] in
            guard let self, let config = window?.config else { return }
            self.onEditRequested?(config)
        }

        window.onRemoveRequested = { [weak self, weak window] in
            guard let self, let id = window?.config.id else { return }
            _ = self.removeWidget(id: id)
        }

        window.onPositionChanged = { [weak self, weak window] position in
            guard let self, let window else { return }
            window.updatePosition(position)
            self.resolveOverlapIfNeeded(for: window)
            self.store.save(window.config, isLocked: window.isPositionLocked)
            self.notifyWidgetListChanged()
        }

        window.onSizeChanged = { [weak self, weak window] _ in
            guard let self, let window else { return }
            self.resolveOverlapIfNeeded(for: window)
            self.store.save(window.config, isLocked: window.isPositionLocked)
            self.notifyWidgetListChanged()
        }

        window.onDuplicateRequested = { [weak self, weak window] in
            guard let self, let id = window?.config.id else { return }
            _ = self.duplicateWidget(id: id)
        }

        window.onResizePresetRequested = { [weak self, weak window] preset in
            guard let self, let id = window?.config.id else { return }
            self.resizeWidget(id: id, preset: preset)
        }

        window.onLockPositionChanged = { [weak self, weak window] isLocked in
            guard let self, let id = window?.config.id else { return }
            _ = self.setWidgetLocked(id: id, isLocked: isLocked)
        }

        window.onDragFeedbackRequested = { [weak self, weak window] proposedFrame in
            guard let self, let window else {
                return WidgetDragFeedback(origin: proposedFrame.origin, guides: [])
            }

            let screenFrame = self.screenFrame(for: proposedFrame)
            let frames = self.otherFrames(excluding: window.config.id, in: screenFrame)
            let feedback = self.positionManager.dragFeedback(for: proposedFrame, against: frames, screenFrame: screenFrame)
            self.alignmentGuideOverlay.show(guides: feedback.guides, in: screenFrame)
            return feedback
        }

        window.onDragEnded = { [weak self] in
            self?.alignmentGuideOverlay.hide()
        }

        window.onAutoSizeCompleted = { [weak self, weak window] in
            guard let self, let window else { return }
            // After the deferred auto-size pass the window's actual rendered size is now
            // known. Re-run placement so the widget doesn't overlap obstacles that were
            // fine for the LLM-specified size but conflict with the real rendered size.
            let newOrigin = self.nextAutoOrigin(for: window.frame.size, excluding: window.config.id)
            let current = window.frame.origin
            guard hypot(newOrigin.x - current.x, newOrigin.y - current.y) > 10 else { return }
            window.setFrameOrigin(newOrigin)
            let pos = WidgetPosition(x: newOrigin.x.double, y: newOrigin.y.double)
            window.updatePosition(pos)
            self.store.save(window.config, isLocked: window.isPositionLocked)
        }
    }

    private func uniquedName(from baseName: String) -> String {
        let existing = Set(widgetNames())

        if !existing.contains("\(baseName) Copy") {
            return "\(baseName) Copy"
        }

        for index in 2...999 {
            let candidate = "\(baseName) Copy \(index)"
            if !existing.contains(candidate) {
                return candidate
            }
        }

        return "\(baseName) Copy"
    }

    private func normalizedForWallpaper(_ config: WidgetConfig) -> WidgetConfig {
        var normalized = config
        normalized.size = config.size.snappedToAppleWallpaperPreset()
        return normalized
    }

    private func resolveOverlapIfNeeded(for window: WidgetWindow) {
        let frame = screenFrame(for: window.frame)
        let occupied = placementObstacles(in: frame, excluding: window.config.id)
        let candidate = CGRect(origin: window.frame.origin, size: window.frame.size)
        let collides = occupied.contains { $0.intersects(candidate) }
        guard collides else { return }

        let next = positionManager.firstAvailableOrigin(
            for: window.frame.size,
            in: frame,
            occupied: occupied,
            margin: 28,
            scanStep: 22
        ) ?? positionManager.bestEffortOrigin(
            for: window.frame.size,
            in: frame,
            occupied: occupied,
            margin: 28,
            scanStep: 26
        )

        window.setFrameOrigin(next)
        let position = WidgetPosition(x: next.x.double, y: next.y.double)
        window.updatePosition(position)
    }

    private func nextAutoOrigin(for size: CGSize, excluding id: UUID?) -> CGPoint {
        let screens = orderedPlacementScreens()
        let states = screens.map { screen in
            ScreenPlacementState(
                frame: screen.visibleFrame,
                occupied: placementObstacles(in: screen.visibleFrame, excluding: id)
            )
        }

        if let choice = bestPlacementChoice(for: size, states: states) {
            return choice.origin
        }

        guard let frame = NSScreen.main?.visibleFrame else {
            return CGPoint(x: 80, y: 420)
        }

        return positionManager.clampedOrigin(
            CGPoint(x: frame.minX + 48, y: frame.maxY - size.height - 120),
            size: size,
            in: frame,
            margin: 28
        )
    }

    private func resolvedStoredOrigin(for window: WidgetWindow) -> CGPoint {
        let size = window.frame.size
        let frame = screenFrame(for: window.frame)
        let original = window.frame.origin
        let clamped = positionManager.clampedOrigin(original, size: size, in: frame, margin: 28)
        let offScreenDistance = hypot(original.x - clamped.x, original.y - clamped.y)

        let paneOnlyObstacles = otherFrames(excluding: window.config.id, in: frame)
            .map { $0.insetBy(dx: -12, dy: -12) }
        let collidesWithPane = paneOnlyObstacles.contains {
            $0.intersects(CGRect(origin: clamped, size: size))
        }

        guard offScreenDistance > 0.5 || collidesWithPane else {
            return clamped
        }

        let occupied = placementObstacles(in: frame, excluding: window.config.id)
        if let available = positionManager.firstAvailableOrigin(
            for: size,
            in: frame,
            occupied: occupied,
            margin: 28,
            scanStep: 22
        ) {
            return available
        }

        return positionManager.bestEffortOrigin(
            for: size,
            in: frame,
            occupied: occupied,
            margin: 28,
            scanStep: 26
        )
    }

    private func notifyWidgetListChanged() {
        onWidgetListChanged?(widgetNames())
        onWidgetSummariesChanged?(widgetSummaries())
    }

    private func otherFrames(excluding id: UUID? = nil, in screenFrame: CGRect) -> [CGRect] {
        windows
            .filter { key, _ in
                guard let id else { return true }
                return key != id
            }
            .map { $0.value.frame }
            .filter { frame in
                let center = CGPoint(x: frame.midX, y: frame.midY)
                return screenFrame.contains(center)
            }
    }

    private func screenFrame(for frame: CGRect) -> CGRect {
        let center = CGPoint(x: frame.midX, y: frame.midY)

        if let exact = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return exact.visibleFrame
        }

        let best = NSScreen.screens.max { lhs, rhs in
            lhs.frame.intersection(frame).area < rhs.frame.intersection(frame).area
        }

        return best?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
    }

    private func orderedPlacementScreens() -> [NSScreen] {
        let screens = NSScreen.screens
        guard let main = NSScreen.main else {
            return screens
        }

        return screens.sorted { lhs, rhs in
            if lhs == main { return true }
            if rhs == main { return false }
            if lhs.frame.minY == rhs.frame.minY {
                return lhs.frame.minX < rhs.frame.minX
            }
            return lhs.frame.minY > rhs.frame.minY
        }
    }

    private func bestPlacementChoice(for size: CGSize, states: [ScreenPlacementState]) -> PlacementChoice? {
        var bestFallback: PlacementChoice?

        for (index, state) in states.enumerated() {
            if let available = positionManager.firstAvailableOrigin(
                for: size,
                in: state.frame,
                occupied: state.occupied,
                margin: 28,
                scanStep: 22
            ) {
                return PlacementChoice(index: index, origin: available, overlap: 0)
            }

            let fallback = positionManager.bestEffortOrigin(
                for: size,
                in: state.frame,
                occupied: state.occupied,
                margin: 28,
                scanStep: 26
            )
            let overlap = overlapScore(
                for: CGRect(origin: fallback, size: size),
                against: state.occupied
            )

            if bestFallback == nil || overlap < bestFallback?.overlap ?? .greatestFiniteMagnitude {
                bestFallback = PlacementChoice(index: index, origin: fallback, overlap: overlap)
            }
        }

        return bestFallback
    }

    private func overlapScore(for candidate: CGRect, against obstacles: [CGRect]) -> CGFloat {
        obstacles.reduce(CGFloat(0)) { partial, obstacle in
            partial + candidate.intersection(obstacle).area
        }
    }

    private func placementObstacles(in screenFrame: CGRect, excluding id: UUID?) -> [CGRect] {
        let paneWindows = otherFrames(excluding: id, in: screenFrame).map { $0.insetBy(dx: -20, dy: -20) }
        let nativeWidgets = nativeDesktopWidgetFrames(in: screenFrame).map { $0.insetBy(dx: -16, dy: -16) }
        let desktopIcons = desktopIconReservedFrames(in: screenFrame)

        return (paneWindows + nativeWidgets + desktopIcons)
            .filter { rect in
                !rect.isNull && !rect.isEmpty && rect.intersects(screenFrame)
            }
    }

    private func nativeDesktopWidgetFrames(in screenFrame: CGRect) -> [CGRect] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return info.compactMap { entry in
            guard let pidNumber = entry[kCGWindowOwnerPID as String] as? NSNumber else { return nil }
            guard pidNumber.int32Value != ownProcessID else { return nil }

            let owner = (entry[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            let title = (entry[kCGWindowName as String] as? String ?? "").lowercased()
            let isLikelyDesktopWidgetHost =
                owner.contains("notificationcenter")
                || owner.contains("widgetkit")
                || owner.contains("widget")
                || owner.contains("controlcenter")
                || title.contains("widget")

            guard isLikelyDesktopWidgetHost else { return nil }
            guard let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary else { return nil }
            guard let bounds = CGRect(dictionaryRepresentation: boundsDict) else { return nil }
            guard bounds.intersects(screenFrame) else { return nil }
            guard bounds.area > 3_000 else { return nil }
            guard bounds.area < screenFrame.area * 0.60 else { return nil }
            return bounds
        }
    }

    private func desktopIconReservedFrames(in screenFrame: CGRect) -> [CGRect] {
        let itemCount = desktopVisibleItemCount()
        guard itemCount > 0 else {
            return []
        }

        // Reserve a wider lane so widgets never cover desktop files/folders.
        // Base 160pt + 5pt per icon (up to 30), capped at 320pt.
        let laneWidth = min(320, max(160, 140 + (CGFloat(min(itemCount, 30)) * 5)))
        return [
            CGRect(
                x: screenFrame.minX + 4,
                y: screenFrame.minY + 4,
                width: laneWidth,
                height: max(0, screenFrame.height - 8)
            )
        ]
    }

    private func desktopVisibleItemCount() -> Int {
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            return 0
        }

        guard let items = try? fileManager.contentsOfDirectory(
            at: desktopURL,
            includingPropertiesForKeys: [.isHiddenKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        return items.count
    }
}

private extension Double {
    var cgFloat: CGFloat { CGFloat(self) }
}

private extension CGFloat {
    var double: Double { Double(self) }
}

private struct PlacementChoice {
    let index: Int
    let origin: CGPoint
    let overlap: CGFloat
}

private struct ScreenPlacementState {
    let frame: CGRect
    var occupied: [CGRect]
}

@MainActor
private final class AlignmentGuideOverlayWindow: NSWindow {
    private var hostView: NSHostingView<AlignmentGuideOverlayView>

    init() {
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        hostView = NSHostingView(rootView: AlignmentGuideOverlayView(guides: [], screenFrame: screenFrame))

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 3)
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]

        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = hostView
        orderOut(nil)
    }

    func show(guides: [AlignmentGuide], in screenFrame: CGRect) {
        guard !guides.isEmpty else {
            hide()
            return
        }

        setFrame(screenFrame, display: false)
        hostView.rootView = AlignmentGuideOverlayView(guides: guides, screenFrame: screenFrame)
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }
}

private struct AlignmentGuideOverlayView: View {
    let guides: [AlignmentGuide]
    let screenFrame: CGRect

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(guides.enumerated()), id: \.offset) { _, guide in
                    switch guide.orientation {
                    case .vertical:
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.75))
                            .frame(width: 1, height: geometry.size.height)
                            .position(
                                x: clampedX(guide.position, in: geometry.size.width),
                                y: geometry.size.height / 2
                            )
                            .shadow(color: Color.accentColor.opacity(0.45), radius: 3)
                    case .horizontal:
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.75))
                            .frame(width: geometry.size.width, height: 1)
                            .position(
                                x: geometry.size.width / 2,
                                y: clampedY(guide.position, in: geometry.size.height)
                            )
                            .shadow(color: Color.accentColor.opacity(0.45), radius: 3)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .background(Color.clear)
    }

    private func clampedX(_ screenX: CGFloat, in width: CGFloat) -> CGFloat {
        let local = screenX - screenFrame.minX
        return Swift.min(Swift.max(local, 0), width)
    }

    private func clampedY(_ screenY: CGFloat, in height: CGFloat) -> CGFloat {
        let local = screenFrame.maxY - screenY
        return Swift.min(Swift.max(local, 0), height)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}
