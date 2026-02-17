import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class CommandBarWindow {
    private let panel: CommandBarPanel
    private let viewModel = CommandBarViewModel()

    var isVisible: Bool { panel.isVisible }

    init() {
        panel = CommandBarPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 380),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .statusBar
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = true
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false

        let rootView = CommandBarView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: rootView)
    }

    func show(
        prefill: String?,
        editing: Bool,
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        viewModel.onSubmit = onSubmit
        viewModel.onCancel = { [weak self] in
            onCancel()
            self?.hide()
        }
        viewModel.prepare(prefill: prefill, editing: editing)

        positionPanel()
        NSApp.activate(ignoringOtherApps: true)

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func setLoading(_ loading: Bool, message: String?) {
        viewModel.setLoading(loading, message: message)
    }

    func setStatus(_ message: String, isError: Bool = false) {
        viewModel.setStatus(message, isError: isError)
    }

    private func positionPanel() {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }

        let width = min(1180, max(840, screenFrame.width - 96))
        let height: CGFloat = 380
        let x = screenFrame.midX - (width / 2)
        let y = screenFrame.maxY - (screenFrame.height * 0.22)

        panel.setFrame(NSRect(x: x, y: y - height / 2, width: width, height: height), display: false)
    }
}

private final class CommandBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
