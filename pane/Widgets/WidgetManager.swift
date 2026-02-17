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
    private let interactionController = WidgetInteractionController()
    private let positionManager = WidgetPositionManager()
    private let alignmentGuideOverlay = AlignmentGuideOverlayWindow()
    private var windows: [UUID: WidgetWindow] = [:]

    init(store: WidgetStore, settingsStore: SettingsStore) {
        self.store = store
        self.settingsStore = settingsStore
    }

    func createOrUpdateWidget(_ config: WidgetConfig, isLocked: Bool? = nil) {
        if let window = windows[config.id] {
            window.update(config: config)
            if let isLocked {
                window.setLocked(isLocked)
            }
            store.save(window.config, isLocked: window.isPositionLocked)
            notifyWidgetListChanged()
            return
        }

        let shouldAutoArrange = config.position == nil
        let window = WidgetWindow(
            config: config,
            settingsStore: settingsStore,
            shouldAutoSizeOnInitialRender: shouldAutoArrange
        )
        if let isLocked {
            window.setLocked(isLocked)
        }

        if shouldAutoArrange {
            // Use the post-render fitted size to pick a clean non-overlapping first placement.
            let origin = nextAutoOrigin(for: window.frame.size)
            window.setFrameOrigin(origin)
            window.updatePosition(WidgetPosition(x: origin.x.double, y: origin.y.double))
        } else {
            let origin = window.frame.origin
            window.updatePosition(WidgetPosition(x: origin.x.double, y: origin.y.double))
        }

        interactionController.attach(to: window)
        wireCallbacks(for: window)
        windows[config.id] = window
        window.orderFrontRegardless()

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
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            return
        }

        let sortedIDs = windows.keys.sorted { lhs, rhs in
            let left = windows[lhs]?.config.name ?? ""
            let right = windows[rhs]?.config.name ?? ""
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }

        let sizes = sortedIDs.compactMap { id -> CGSize? in
            guard let window = windows[id] else { return nil }
            return CGSize(width: window.config.size.width.cgFloat, height: window.config.size.height.cgFloat)
        }
        let origins = positionManager.gridOrigins(for: sizes, in: screenFrame)

        for (index, id) in sortedIDs.enumerated() {
            guard let window = windows[id] else { continue }
            guard origins.indices.contains(index) else { continue }
            window.setFrameOrigin(origins[index])

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
        window.update(config: updated)
        store.save(updated, isLocked: window.isPositionLocked)
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
            self.store.save(window.config, isLocked: window.isPositionLocked)
            self.notifyWidgetListChanged()
        }

        window.onSizeChanged = { [weak self, weak window] _ in
            guard let self, let window else { return }
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
            let feedback = self.positionManager.dragFeedback(for: proposedFrame, against: frames)
            self.alignmentGuideOverlay.show(guides: feedback.guides, in: screenFrame)
            return feedback
        }

        window.onDragEnded = { [weak self] in
            self?.alignmentGuideOverlay.hide()
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

    private func nextAutoOrigin(for size: CGSize) -> CGPoint {
        guard let frame = NSScreen.main?.visibleFrame else {
            return CGPoint(x: 80, y: 420)
        }

        let margin: CGFloat = 40
        let spacing: CGFloat = 20
        let occupied = windows.values.map { $0.frame.insetBy(dx: -12, dy: -12) }

        let minX = frame.minX + margin
        let maxX = max(minX, frame.maxX - margin - size.width)
        let minY = frame.minY + margin

        var y = frame.maxY - margin - size.height
        while y >= minY {
            var x = minX
            while x <= maxX {
                let candidate = CGRect(x: x, y: y, width: size.width, height: size.height)
                if occupied.allSatisfy({ !$0.intersects(candidate) }) {
                    return candidate.origin
                }
                x += size.width + spacing
            }
            y -= size.height + spacing
        }

        let existingSizes = windows.values.map {
            CGSize(width: $0.config.size.width.cgFloat, height: $0.config.size.height.cgFloat)
        }
        let fallback = positionManager.gridOrigins(
            for: existingSizes + [size],
            in: frame,
            spacing: spacing,
            margin: margin
        ).last

        return fallback ?? CGPoint(x: minX, y: frame.maxY - margin - size.height)
    }

    private func notifyWidgetListChanged() {
        onWidgetListChanged?(widgetNames())
        onWidgetSummariesChanged?(widgetSummaries())
    }

    private func otherFrames(excluding id: UUID, in screenFrame: CGRect) -> [CGRect] {
        windows
            .filter { $0.key != id }
            .map { $0.value.frame }
            .filter { frame in
                let center = CGPoint(x: frame.midX, y: frame.midY)
                return screenFrame.contains(center)
            }
    }

    private func screenFrame(for frame: CGRect) -> CGRect {
        let center = CGPoint(x: frame.midX, y: frame.midY)

        if let exact = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return exact.frame
        }

        let best = NSScreen.screens.max { lhs, rhs in
            lhs.frame.intersection(frame).area < rhs.frame.intersection(frame).area
        }

        return best?.frame ?? NSScreen.main?.frame ?? frame
    }
}

private extension Double {
    var cgFloat: CGFloat { CGFloat(self) }
}

private extension CGFloat {
    var double: Double { Double(self) }
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
        return min(max(local, 0), width)
    }

    private func clampedY(_ screenY: CGFloat, in height: CGFloat) -> CGFloat {
        let local = screenFrame.maxY - screenY
        return min(max(local, 0), height)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}
