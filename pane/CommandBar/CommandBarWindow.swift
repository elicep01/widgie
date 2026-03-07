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
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
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
        panel.onEscape = { [weak self] in
            self?.viewModel.cancel()
        }
        viewModel.onSubmit = onSubmit
        viewModel.onCancel = { [weak self] in
            onCancel()
            self?.hide()
        }
        viewModel.prepare(prefill: prefill, editing: editing)

        positionPanel(expanded: false)
        NSApp.activate(ignoringOtherApps: true)

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func showClarification(
        questions: [ClarificationQuestion],
        originalPrompt: String,
        onSubmit: @escaping (String, [ClarificationQuestion], [String: [String]]) -> Void
    ) {
        viewModel.onClarificationSubmit = onSubmit
        viewModel.showClarification(questions: questions, originalPrompt: originalPrompt)
        expandForClarification()
    }

    func showFeedback(
        widgetID: UUID,
        originalPrompt: String,
        onAccepted: @escaping () -> Void,
        onTweak: @escaping (UUID, String) -> Void
    ) {
        viewModel.onFeedbackAccepted = { [weak self] in
            onAccepted()
            self?.hide()
        }
        viewModel.onFeedbackTweak = onTweak
        viewModel.showFeedback(widgetID: widgetID, originalPrompt: originalPrompt)
        contractToFeedbackSize()
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

    func clearAgentTrace() {
        viewModel.clearAgentTrace()
    }

    func appendAgentTrace(_ line: String) {
        viewModel.appendAgentTrace(line)
    }

    func setBuildChecklist(_ items: [BuildChecklistItem]) {
        viewModel.setBuildChecklist(items)
    }

    func completeChecklistItem(id: String) {
        viewModel.completeChecklistItem(id: id)
    }

    func clearBuildChecklist() {
        viewModel.clearBuildChecklist()
    }

    private func positionPanel(expanded: Bool) {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }

        // Match Spotlight's feel: centered horizontally, ~35% from top of visible area.
        let width = min(860, max(680, screenFrame.width - 160))
        let height: CGFloat = expanded ? 520 : 380
        let x = screenFrame.midX - (width / 2)
        let panelCenterY = screenFrame.maxY - (screenFrame.height * 0.35)

        panel.setFrame(NSRect(x: x, y: panelCenterY - height / 2, width: width, height: height), display: false)
    }

    private func expandForClarification() {
        animatePanelHeight(520)
    }

    private func contractToFeedbackSize() {
        animatePanelHeight(200)
    }

    private func animatePanelHeight(_ height: CGFloat) {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }

        let width = min(860, max(680, screenFrame.width - 160))
        let x = screenFrame.midX - (width / 2)
        let panelCenterY = screenFrame.maxY - (screenFrame.height * 0.35)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(
                NSRect(x: x, y: panelCenterY - height / 2, width: width, height: height),
                display: true
            )
        }
    }
}

private final class CommandBarPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }

        super.keyDown(with: event)
    }
}
