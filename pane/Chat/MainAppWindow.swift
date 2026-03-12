import AppKit
import SwiftUI

@MainActor
final class MainAppWindow {
    private let window: NSWindow
    let viewModel: ChatViewModel

    var isVisible: Bool { window.isVisible }

    init(
        viewModel: ChatViewModel,
        templateStore: WidgetTemplateStore,
        settingsStore: SettingsStore,
        onAddWidget: @escaping (String, WidgetTheme) -> Void
    ) {
        self.viewModel = viewModel

        let rootView = MainChatView(
            viewModel: viewModel,
            templateStore: templateStore,
            settingsStore: settingsStore,
            onAddWidget: onAddWidget
        )

        let hostingController = NSHostingController(rootView: rootView)
        let win = NSWindow(contentViewController: hostingController)
        win.title = "widgie"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.setFrame(NSRect(x: 0, y: 0, width: 900, height: 640), display: false)
        win.minSize = NSSize(width: 680, height: 460)
        win.center()
        win.isReleasedWhenClosed = false
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.toolbar = NSToolbar()
        win.toolbarStyle = .unifiedCompact
        win.backgroundColor = .windowBackgroundColor

        self.window = win
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window.orderOut(nil)
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func showGallery() {
        viewModel.sidebarTab = .gallery
        show()
    }

    func openConversationForWidget(_ widgetID: UUID, widgetName: String) {
        // Switch to My Widgets tab so the chat is visible
        viewModel.sidebarTab = .myWidgets
        if let existing = viewModel.conversationStore.conversationForWidget(widgetID) {
            viewModel.selectConversation(existing.id)
        } else {
            let conv = viewModel.conversationStore.create(title: widgetName, widgetID: widgetID)
            viewModel.refreshConversations()
            viewModel.selectConversation(conv.id)
        }
        show()
    }
}
