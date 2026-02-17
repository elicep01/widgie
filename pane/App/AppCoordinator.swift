import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppCoordinator {
    private let aiService: AIWidgetService
    private let settingsStore: SettingsStore
    private let hotkeyListener: GlobalHotkeyListener
    private let widgetStore = WidgetStore()
    private let templateStore = WidgetTemplateStore()

    private lazy var widgetManager = WidgetManager(store: widgetStore, settingsStore: settingsStore)
    private lazy var commandBarWindow = CommandBarWindow()
    private lazy var settingsWindow = SettingsWindow(settingsStore: settingsStore)
    private lazy var widgetGalleryWindow = WidgetGalleryWindow(
        onCreateWidget: { [weak self] in self?.openCommandBar() },
        onCreateTemplate: { [weak self] id in self?.createWidgetFromTemplate(id: id) },
        onEditWidget: { [weak self] id in self?.openEditor(for: id) },
        onDuplicateWidget: { [weak self] id in
            guard let self else { return }
            _ = self.widgetManager.duplicateWidget(id: id)
            self.refreshMenuState()
        },
        onToggleLock: { [weak self] id, isLocked in
            guard let self else { return }
            _ = self.widgetManager.setWidgetLocked(id: id, isLocked: isLocked)
            self.refreshMenuState()
        },
        onRemoveWidget: { [weak self] id in
            guard let self else { return }
            _ = self.widgetManager.removeWidget(id: id)
            self.refreshMenuState()
        },
        onAutoLayout: { [weak self] in
            self?.widgetManager.autoLayoutWidgets()
            self?.refreshMenuState()
        },
        onApplyTheme: { [weak self] theme in
            self?.applyTheme(theme)
        }
    )
    private lazy var menuBarController = MenuBarController(
        onNewWidget: { [weak self] in self?.openCommandBar() },
        onCreateTemplate: { [weak self] id in self?.createWidgetFromTemplate(id: id) },
        onImportWidgets: { [weak self] in self?.importWidgets() },
        onExportWidgets: { [weak self] in self?.exportWidgets() },
        onShowGallery: { [weak self] in self?.openWidgetGallery() },
        onAutoLayout: { [weak self] in
            self?.widgetManager.autoLayoutWidgets()
            self?.refreshMenuState()
        },
        onApplyTheme: { [weak self] theme in
            self?.applyTheme(theme)
        },
        onShowSettings: { [weak self] in self?.openSettings() },
        onQuit: { NSApp.terminate(nil) }
    )

    private var editingWidgetID: UUID?
    private var settingsObserver: NSObjectProtocol?

    init(
        settingsStore: SettingsStore,
        aiService: AIWidgetService? = nil
    ) {
        self.settingsStore = settingsStore
        self.hotkeyListener = GlobalHotkeyListener(registration: settingsStore.hotkeyPreset.registration)
        self.aiService = aiService ?? ProviderBackedAIService(settingsStore: settingsStore)
    }

    func start() {
        wireCallbacks()
        observeSettings()
        applyRuntimeSettings()

        hotkeyListener.start()
        menuBarController.start()

        widgetManager.restoreWidgets()
        refreshTemplateState()
        refreshMenuState()

        if !settingsStore.hasAnyRemoteAPIKey {
            openSettings()
            showUserMessage("pane requires an OpenAI or Claude API key before creating widgets.", isError: true)
        }
    }

    func stop() {
        hotkeyListener.stop()
        commandBarWindow.hide()

        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
            self.settingsObserver = nil
        }
    }

    func openCommandBar() {
        guard ensureRemoteAIReady(showUIFeedback: true) else {
            return
        }
        showCommandBar(prefill: nil, editingWidgetID: nil)
    }

    func openSettings() {
        settingsWindow.show()
    }

    func openWidgetGallery() {
        widgetGalleryWindow.show()
    }

    private func wireCallbacks() {
        hotkeyListener.onTrigger = { [weak self] in
            self?.openCommandBar()
        }

        widgetManager.onEditRequested = { [weak self] config in
            guard let self else { return }
            self.showCommandBar(prefill: config.description, editingWidgetID: config.id)
        }

        widgetManager.onWidgetListChanged = { [weak self] names in
            self?.menuBarController.setWidgetNames(names)
        }

        widgetManager.onWidgetSummariesChanged = { [weak self] summaries in
            self?.widgetGalleryWindow.setSummaries(summaries)
        }
    }

    private func observeSettings() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: settingsStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyRuntimeSettings()
            }
        }
    }

    private func applyRuntimeSettings() {
        hotkeyListener.updateRegistration(settingsStore.hotkeyPreset.registration)
        LaunchAtLoginController.shared.apply(enabled: settingsStore.launchAtLogin)
    }

    private func showCommandBar(prefill: String?, editingWidgetID: UUID?) {
        self.editingWidgetID = editingWidgetID

        commandBarWindow.show(
            prefill: prefill,
            editing: editingWidgetID != nil,
            onSubmit: { [weak self] prompt in
                self?.handlePrompt(prompt)
            },
            onCancel: { [weak self] in
                self?.editingWidgetID = nil
            }
        )

        let remaining = AIRateLimiter.shared.remainingPipelineRunsToday()
        commandBarWindow.setStatus("Daily runs left: \(remaining)")
    }

    private func handlePrompt(_ rawPrompt: String) {
        let action = CommandParser.parse(rawPrompt)

        switch action {
        case .list:
            let names = widgetManager.widgetNames()
            if names.isEmpty {
                commandBarWindow.setStatus("No widgets yet.")
            } else {
                commandBarWindow.setStatus(names.joined(separator: " • "))
            }
        case .remove(let name):
            if widgetManager.removeWidget(named: name) {
                commandBarWindow.setStatus("Removed \(name).")
                refreshMenuState()
            } else {
                commandBarWindow.setStatus("Couldn't find widget named \(name).", isError: true)
            }
        case .theme(let theme):
            applyTheme(theme)
            commandBarWindow.setStatus("Applied \(theme.rawValue) theme to all widgets.")
        case .layoutAuto:
            widgetManager.autoLayoutWidgets()
            commandBarWindow.setStatus("Auto-layout complete.")
        case .templates:
            let templates = templateStore.availableTemplates()
            if templates.isEmpty {
                commandBarWindow.setStatus("No templates available.", isError: true)
            } else {
                commandBarWindow.setStatus("Templates: " + templates.map(\.name).joined(separator: " • "))
            }
        case .createTemplate(let query):
            guard createWidgetFromTemplate(query: query) else {
                commandBarWindow.setStatus("Template not found. Use /templates.", isError: true)
                return
            }
            commandBarWindow.setStatus("Created template widget.")
        case .exportWidgets:
            exportWidgets()
        case .importWidgets:
            importWidgets()
        case .settings:
            openSettings()
            commandBarWindow.hide()
        case .generate(let prompt):
            generateWidget(from: prompt)
        }
    }

    private func generateWidget(from prompt: String) {
        guard ensureRemoteAIReady(showUIFeedback: true) else {
            commandBarWindow.setLoading(false, message: nil)
            return
        }

        commandBarWindow.setLoading(true, message: editingWidgetID == nil ? "Creating your widget..." : "Updating widget...")

        Task {
            do {
                let config: WidgetConfig
                if let editingWidgetID,
                   let existing = widgetManager.widgetConfig(for: editingWidgetID) {
                    config = try await aiService.editWidget(existingConfig: existing, editPrompt: prompt)
                } else {
                    config = try await aiService.generateWidget(prompt: prompt)
                }

                widgetManager.createOrUpdateWidget(config)
                refreshMenuState()

                commandBarWindow.setLoading(false, message: nil)
                commandBarWindow.hide()
                editingWidgetID = nil
            } catch {
                commandBarWindow.setLoading(false, message: nil)
                commandBarWindow.setStatus(userFacingErrorMessage(for: error), isError: true)
            }
        }
    }

    private func refreshMenuState() {
        menuBarController.setWidgetNames(widgetManager.widgetNames())
        widgetGalleryWindow.setSummaries(widgetManager.widgetSummaries())
    }

    private func refreshTemplateState() {
        let templates = templateStore.availableTemplates()
        menuBarController.setTemplateSummaries(templates)
        widgetGalleryWindow.setTemplates(templates)
    }

    private func openEditor(for id: UUID) {
        guard let config = widgetManager.widgetConfig(for: id) else {
            return
        }
        showCommandBar(prefill: config.description, editingWidgetID: config.id)
    }

    private func applyTheme(_ theme: WidgetTheme) {
        widgetManager.applyTheme(theme)
        settingsStore.defaultTheme = theme
        refreshMenuState()
    }

    @discardableResult
    private func createWidgetFromTemplate(id: String) -> Bool {
        guard let config = templateStore.instantiateTemplate(id: id) else {
            return false
        }
        widgetManager.createOrUpdateWidget(config)
        refreshMenuState()
        return true
    }

    @discardableResult
    private func createWidgetFromTemplate(query: String) -> Bool {
        guard let config = templateStore.instantiateTemplate(matching: query) else {
            return false
        }
        widgetManager.createOrUpdateWidget(config)
        refreshMenuState()
        return true
    }

    private func exportWidgets() {
        let panel = NSSavePanel()
        panel.title = "Export Widgets"
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "pane-export-\(exportDateStamp()).json"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try widgetStore.exportAll(to: url)
            showUserMessage("Widgets exported to \(url.lastPathComponent).")
        } catch {
            showUserMessage("Export failed: \(error.localizedDescription)", isError: true)
        }
    }

    private func importWidgets() {
        let panel = NSOpenPanel()
        panel.title = "Import Widgets"
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let hadAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hadAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let imported = try widgetStore.importFrom(url: url)
            widgetManager.reloadFromStore()
            refreshMenuState()
            showUserMessage("Imported \(imported) widget\(imported == 1 ? "" : "s").")
        } catch {
            showUserMessage("Import failed: \(error.localizedDescription)", isError: true)
        }
    }

    private func showUserMessage(_ message: String, isError: Bool = false) {
        if commandBarWindow.isVisible {
            commandBarWindow.setStatus(message, isError: isError)
            return
        }

        let alert = NSAlert()
        alert.messageText = isError ? "pane" : "Success"
        alert.informativeText = message
        alert.alertStyle = isError ? .warning : .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func exportDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: Date())
    }

    private func ensureRemoteAIReady(showUIFeedback: Bool) -> Bool {
        if settingsStore.ensureUsableProviderSelection() {
            return true
        }

        guard showUIFeedback else {
            return false
        }

        openSettings()
        let message = "Add an OpenAI or Claude API key in Settings > AI to use pane."
        if commandBarWindow.isVisible {
            commandBarWindow.setStatus(message, isError: true)
        } else {
            showUserMessage(message, isError: true)
        }
        return false
    }

    private func userFacingErrorMessage(for error: Error) -> String {
        if let serviceError = error as? AIWidgetServiceError {
            switch serviceError {
            case .missingAPIKey:
                return "Missing API key. pane requires OpenAI or Claude key in Settings > AI."
            case .requestFailed(let message):
                if message.contains("HTTP 400") {
                    return "Provider rejected the request (HTTP 400). Check provider, model, and API key in Settings > AI."
                }
                if message.contains("HTTP 401") {
                    return "API key is invalid or unauthorized (HTTP 401)."
                }
                if message.contains("HTTP 429") {
                    return "Rate limited by provider (HTTP 429). Try again shortly."
                }
                if message.contains("HTTP 500")
                    || message.contains("HTTP 502")
                    || message.contains("HTTP 503")
                    || message.contains("HTTP 504") {
                    return "AI service is temporarily unavailable. Try again in a moment."
                }
                if message.contains("Timed out") {
                    return "AI is taking longer than usual. Try again?"
                }
                return "Provider request failed. Check AI settings and network, then retry."
            case .schemaValidationFailed:
                return "I couldn't build that widget. Try rephrasing?"
            case .providerReturnedNoContent:
                return "Provider returned no content. Try again with a simpler prompt."
            case .responseParsingFailed:
                return "Couldn't parse provider response. Try again."
            case .invalidPrompt:
                return "Prompt is empty."
            }
        }
        return error.localizedDescription
    }
}
