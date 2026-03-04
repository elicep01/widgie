import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let onNewWidget: () -> Void
    private let onCreateTemplate: (String) -> Void
    private let onImportWidgets: () -> Void
    private let onExportWidgets: () -> Void
    private let onShowGallery: () -> Void
    private let onAutoLayout: () -> Void
    private let onApplyTheme: (WidgetTheme) -> Void
    private let onShowSettings: () -> Void
    private let onQuit: () -> Void

    private var statusItem: NSStatusItem?
    private var widgetNames: [String] = []
    private var templateSummaries: [WidgetTemplateSummary] = []

    init(
        onNewWidget: @escaping () -> Void,
        onCreateTemplate: @escaping (String) -> Void,
        onImportWidgets: @escaping () -> Void,
        onExportWidgets: @escaping () -> Void,
        onShowGallery: @escaping () -> Void,
        onAutoLayout: @escaping () -> Void,
        onApplyTheme: @escaping (WidgetTheme) -> Void,
        onShowSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onNewWidget = onNewWidget
        self.onCreateTemplate = onCreateTemplate
        self.onImportWidgets = onImportWidgets
        self.onExportWidgets = onExportWidgets
        self.onShowGallery = onShowGallery
        self.onAutoLayout = onAutoLayout
        self.onApplyTheme = onApplyTheme
        self.onShowSettings = onShowSettings
        self.onQuit = onQuit
    }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "widgie")
        item.button?.imagePosition = .imageOnly
        item.menu = buildMenu()
        statusItem = item
    }

    func setWidgetNames(_ names: [String]) {
        widgetNames = names
        statusItem?.menu = buildMenu()
    }

    func setTemplateSummaries(_ templates: [WidgetTemplateSummary]) {
        templateSummaries = templates
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let newWidget = NSMenuItem(title: "New Widget", action: #selector(handleNewWidget), keyEquivalent: "")
        newWidget.target = self
        menu.addItem(newWidget)

        let templateItem = NSMenuItem(title: "New From Template", action: nil, keyEquivalent: "")
        let templateMenu = NSMenu()
        if templateSummaries.isEmpty {
            let empty = NSMenuItem(title: "No Templates", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            templateMenu.addItem(empty)
        } else {
            for template in templateSummaries {
                let item = NSMenuItem(title: template.name, action: #selector(handleCreateTemplate(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = template.id
                templateMenu.addItem(item)
            }
        }
        templateItem.submenu = templateMenu
        menu.addItem(templateItem)

        let gallery = NSMenuItem(title: "Widget Gallery...", action: #selector(handleGallery), keyEquivalent: "g")
        gallery.target = self
        menu.addItem(gallery)

        let autoLayout = NSMenuItem(title: "Auto Layout Widgets", action: #selector(handleAutoLayout), keyEquivalent: "l")
        autoLayout.target = self
        autoLayout.isEnabled = !widgetNames.isEmpty
        menu.addItem(autoLayout)

        let themeItem = NSMenuItem(title: "Apply Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for theme in WidgetTheme.allCases where theme != .custom {
            let item = NSMenuItem(title: theme.rawValue.capitalized, action: #selector(handleTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.rawValue
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        menu.addItem(.separator())

        if widgetNames.isEmpty {
            let empty = NSMenuItem(title: "No Widgets", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let header = NSMenuItem(title: "Widgets (\(widgetNames.count))", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for name in widgetNames.prefix(8) {
                let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let importWidgets = NSMenuItem(title: "Import Widgets...", action: #selector(handleImportWidgets), keyEquivalent: "")
        importWidgets.target = self
        menu.addItem(importWidgets)

        let exportWidgets = NSMenuItem(title: "Export Widgets...", action: #selector(handleExportWidgets), keyEquivalent: "")
        exportWidgets.target = self
        exportWidgets.isEnabled = !widgetNames.isEmpty
        menu.addItem(exportWidgets)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings...", action: #selector(handleSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit widgie", action: #selector(handleQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc
    private func handleNewWidget() {
        onNewWidget()
    }

    @objc
    private func handleCreateTemplate(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else {
            return
        }
        onCreateTemplate(id)
    }

    @objc
    private func handleGallery() {
        onShowGallery()
    }

    @objc
    private func handleAutoLayout() {
        onAutoLayout()
    }

    @objc
    private func handleTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let theme = WidgetTheme(rawValue: raw) else {
            return
        }
        onApplyTheme(theme)
    }

    @objc
    private func handleImportWidgets() {
        onImportWidgets()
    }

    @objc
    private func handleExportWidgets() {
        onExportWidgets()
    }

    @objc
    private func handleSettings() {
        onShowSettings()
    }

    @objc
    private func handleQuit() {
        onQuit()
    }
}
