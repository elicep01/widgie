import AppKit
import SwiftUI

@MainActor
final class SettingsWindow {
    private let window: NSWindow

    init(settingsStore: SettingsStore, onApplyTheme: ((WidgetTheme) -> Void)? = nil) {
        let rootView = SettingsRootView(settingsStore: settingsStore, onApplyTheme: onApplyTheme)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "widgie Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrame(NSRect(x: 0, y: 0, width: 680, height: 520), display: false)
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsRootView: View {
    @ObservedObject var settingsStore: SettingsStore
    let onApplyTheme: ((WidgetTheme) -> Void)?

    var body: some View {
        TabView {
            GeneralSettingsView(settingsStore: settingsStore)
                .tabItem {
                    Label("General", systemImage: "slider.horizontal.3")
                }

            APISettingsView(settingsStore: settingsStore)
                .tabItem {
                    Label("AI", systemImage: "brain")
                }

            WidgetDefaultsView(settingsStore: settingsStore, onApplyTheme: onApplyTheme)
                .tabItem {
                    Label("Widgets", systemImage: "square.grid.2x2")
                }

            DataSettingsView(settingsStore: settingsStore)
                .tabItem {
                    Label("Data", systemImage: "cloud.sun")
                }
        }
        .padding(18)
        .frame(minWidth: 680, minHeight: 520)
    }
}
