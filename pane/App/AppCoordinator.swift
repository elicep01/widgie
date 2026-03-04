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
    private var agentOrchestrator: AgentOrchestrator

    private lazy var widgetManager = WidgetManager(store: widgetStore, settingsStore: settingsStore)
    private lazy var commandBarWindow = CommandBarWindow()
    private lazy var settingsWindow = SettingsWindow(
        settingsStore: settingsStore,
        onApplyTheme: { [weak self] theme in
            self?.applyTheme(theme)
        }
    )
    private lazy var widgetGalleryWindow = WidgetGalleryWindow(
        onCreateWidget: { [weak self] in self?.openCommandBar() },
        onCreateTemplate: { [weak self] id in self?.createWidgetFromTemplate(id: id) },
        onAddStoreItem: { [weak self] id, theme in self?.addStoreItemToDesktop(id: id, theme: theme) },
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
        self.agentOrchestrator = AppCoordinator.makeAgentOrchestrator(
            enableWebDiscovery: settingsStore.enableWebDiscovery
        )
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
            showUserMessage("widgie requires an OpenAI or Claude API key before creating widgets.", isError: true)
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
        if commandBarWindow.isVisible, editingWidgetID == nil {
            return
        }
        showCommandBar(prefill: nil, editingWidgetID: nil)
        if !settingsStore.hasAnyRemoteAPIKey {
            commandBarWindow.setStatus(
                "Add an OpenAI or Claude API key in Settings > AI to generate widgets.",
                isError: true
            )
        }
    }

    func openSettings() {
        settingsWindow.show()
    }

    func openWidgetGallery() {
        widgetGalleryWindow.show()
    }

    private func wireCallbacks() {
        hotkeyListener.onTrigger = { [weak self] in
            self?.toggleCommandBar()
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
        agentOrchestrator = AppCoordinator.makeAgentOrchestrator(
            enableWebDiscovery: settingsStore.enableWebDiscovery
        )
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

    private func toggleCommandBar() {
        if commandBarWindow.isVisible {
            dismissCommandBar()
            return
        }

        openCommandBar()
    }

    private func dismissCommandBar() {
        editingWidgetID = nil
        commandBarWindow.hide()
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

        // Skip clarification when editing an existing widget — the user knows what they want.
        guard editingWidgetID == nil else {
            proceedWithGeneration(prompt, plan: nil)
            return
        }

        commandBarWindow.setLoading(true, message: "Thinking...")
        commandBarWindow.clearAgentTrace()

        Task {
            // Phase 1: agent planning + clarification.
            let clarificationClient = (aiService as? ProviderBackedAIService).flatMap { try? $0.makeClarificationClient() }
            commandBarWindow.appendAgentTrace("Phase: understand")
            let decision = await agentOrchestrator.plan(
                prompt: prompt,
                clarificationClient: clarificationClient
            )

            if case .needsClarification(let plan, let questions) = decision {
                commandBarWindow.appendAgentTrace("Phase: clarify")
                commandBarWindow.appendAgentTrace("Questions needed: \(questions.count)")
                appendSourceAttributionTrace(for: plan)
                commandBarWindow.setLoading(false, message: nil)
                commandBarWindow.showClarification(
                    questions: questions,
                    originalPrompt: prompt
                ) { [weak self] _, qs, answers in
                    guard let self else { return }
                    let updatedPlan = self.agentOrchestrator.applyClarifications(
                        plan: plan,
                        questions: qs,
                        answers: answers
                    )
                    self.commandBarWindow.clearAgentTrace()
                    self.commandBarWindow.appendAgentTrace("Clarifications applied")
                    self.appendSourceAttributionTrace(for: updatedPlan)
                    self.proceedWithGeneration(
                        self.agentOrchestrator.executionPrompt(for: updatedPlan),
                        plan: updatedPlan
                    )
                }
                return
            }

            // Phase 2a: plan is ready — generate directly from synthesized execution prompt.
            commandBarWindow.setLoading(false, message: nil)
            if case .ready(let plan) = decision {
                commandBarWindow.appendAgentTrace("Phase: plan")
                commandBarWindow.appendAgentTrace("Plan ready for execution")
                appendSourceAttributionTrace(for: plan)
                proceedWithGeneration(
                    agentOrchestrator.executionPrompt(for: plan),
                    plan: plan
                )
            } else {
                proceedWithGeneration(prompt, plan: nil)
            }
        }
    }

    private func proceedWithGeneration(_ prompt: String, plan: AgentBuildPlan?) {
        let isEditing = editingWidgetID != nil
        commandBarWindow.setLoading(true, message: isEditing ? "Updating widget..." : "Creating your widget...")
        let originalPrompt = plan?.originalPrompt ?? prompt

        Task {
            do {
                var config: WidgetConfig
                if let editingWidgetID,
                   let existing = widgetManager.widgetConfig(for: editingWidgetID) {
                    config = try await aiService.editWidget(existingConfig: existing, editPrompt: prompt)
                } else {
                    if let plan {
                        commandBarWindow.setLoading(true, message: "Deliberating and refining...")
                        let outcome = try await agentOrchestrator.executeCritiqueRepair(
                            plan: plan,
                            service: aiService,
                            maxIterations: 3,
                            targetConfidence: 0.82,
                            onTrace: { [weak self] line in
                                Task { @MainActor in
                                    self?.commandBarWindow.appendAgentTrace(line)
                                }
                            }
                        )
                        commandBarWindow.appendAgentTrace("Completed in \(outcome.iterations) iteration(s)")
                        let requiredConfidence = 0.82
                        if outcome.confidence < requiredConfidence {
                            commandBarWindow.appendAgentTrace("Confidence below threshold \(Int(requiredConfidence * 100))%")
                            let followups = agentOrchestrator.lowConfidenceFollowupQuestions(
                                plan: plan,
                                issues: outcome.issues
                            )
                            if !followups.isEmpty {
                                commandBarWindow.setLoading(false, message: nil)
                                commandBarWindow.showClarification(
                                    questions: followups,
                                    originalPrompt: originalPrompt
                                ) { [weak self] _, qs, answers in
                                    guard let self else { return }
                                    let updatedPlan = self.agentOrchestrator.applyClarifications(
                                        plan: plan,
                                        questions: qs,
                                        answers: answers
                                    )
                                    self.commandBarWindow.clearAgentTrace()
                                    self.commandBarWindow.appendAgentTrace("Low-confidence follow-up answered")
                                    self.proceedWithGeneration(
                                        self.agentOrchestrator.executionPrompt(for: updatedPlan),
                                        plan: updatedPlan
                                    )
                                }
                                return
                            }
                            throw AIWidgetServiceError.requestFailed(
                                "I couldn't reach a reliable confidence score for this request. Please add more details and try again."
                            )
                        }
                        config = outcome.config
                    } else {
                        config = try await aiService.generateWidget(prompt: prompt)
                    }
                    // Always stamp the user's chosen default theme onto new widgets so they
                    // match the global theme setting regardless of what the AI generated.
                    let theme = settingsStore.defaultTheme
                    config.theme = theme
                    config.background = BackgroundConfig.default(for: theme)
                }

                widgetManager.createOrUpdateWidget(config)
                refreshMenuState()
                commandBarWindow.setLoading(false, message: nil)

                let createdID = config.id
                editingWidgetID = nil

                if isEditing {
                    // Edits close immediately — no feedback loop.
                    commandBarWindow.hide()
                } else {
                    // New widgets: show a brief "Does this look right?" feedback panel.
                    commandBarWindow.showFeedback(
                        widgetID: createdID,
                        originalPrompt: originalPrompt,
                        onAccepted: { [weak self] in
                            guard let service = self?.aiService as? ProviderBackedAIService else { return }
                            // Record this as a learned few-shot example for future similar prompts.
                            service.learnedExampleStore.record(prompt: originalPrompt, config: config)
                            // Update the aesthetic preference profile.
                            service.userPreferenceStore.learn(prompt: originalPrompt, config: config)
                        },
                        onTweak: { [weak self] widgetID, original in
                            guard let self else { return }
                            self.commandBarWindow.hide()
                            self.showCommandBar(prefill: original, editingWidgetID: widgetID)
                        }
                    )
                }
            } catch {
                commandBarWindow.setLoading(false, message: nil)
                if isTimeoutError(error) {
                    commandBarWindow.setStatus(
                        refinementQuestionsAfterTimeout(for: originalPrompt),
                        isError: true
                    )
                } else if recoverFromSchemaFailure(prompt: originalPrompt, error: error) {
                    // Recovery path handled UI state and widget creation.
                } else {
                    commandBarWindow.setStatus(userFacingErrorMessage(for: error), isError: true)
                }
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
        refreshStoreState()
    }

    private func refreshStoreState() {
        widgetGalleryWindow.setStoreItems(templateStore.storeItems())
        widgetGalleryWindow.setStoreCategories(templateStore.storeCategories())
    }

    @discardableResult
    private func addStoreItemToDesktop(id: String, theme: WidgetTheme) -> Bool {
        guard let config = templateStore.instantiateTemplate(id: id, theme: theme) else {
            return false
        }
        widgetManager.createOrUpdateWidget(config)
        refreshMenuState()
        return true
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
        panel.nameFieldStringValue = "widgie-export-\(exportDateStamp()).json"

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
        alert.messageText = isError ? "widgie" : "Success"
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

    private func appendSourceAttributionTrace(for plan: AgentBuildPlan) {
        let attributions = plan.dataPlan.sourceAttributions
        guard !attributions.isEmpty else { return }

        for source in attributions.prefix(2) {
            commandBarWindow.appendAgentTrace("Resolved from: \(source.provider) - \(source.title)")
            commandBarWindow.appendAgentTrace(source.url)
        }
    }

    private static func makeAgentOrchestrator(enableWebDiscovery: Bool) -> AgentOrchestrator {
        if enableWebDiscovery {
            return AgentOrchestrator(webSearchConnector: LiveAgentWebSearchConnector())
        }
        return AgentOrchestrator(webSearchConnector: NoopAgentWebSearchConnector())
    }

    private func ensureRemoteAIReady(showUIFeedback: Bool) -> Bool {
        if settingsStore.ensureUsableProviderSelection() {
            return true
        }

        guard showUIFeedback else {
            return false
        }

        openSettings()
        let message = "Add an OpenAI or Claude API key in Settings > AI to use widgie."
        if commandBarWindow.isVisible {
            commandBarWindow.setStatus(message, isError: true)
        } else {
            showUserMessage(message, isError: true)
        }
        return false
    }

    private func isTimeoutError(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return true
        }

        if let serviceError = error as? AIWidgetServiceError,
           case .requestFailed(let message) = serviceError {
            let lower = message.lowercased()
            return lower.contains("timed out")
                || lower.contains("request timed out")
                || lower.contains("code=-1001")
        }

        let lower = error.localizedDescription.lowercased()
        return lower.contains("timed out")
            || lower.contains("request timed out")
            || lower.contains("code=-1001")
    }

    private func refinementQuestionsAfterTimeout(for prompt: String) -> String {
        TimeoutRefinementAdvisor.questions(for: prompt)
    }

    private func userFacingErrorMessage(for error: Error) -> String {
        if let serviceError = error as? AIWidgetServiceError {
            switch serviceError {
            case .missingAPIKey:
                return "Missing API key. widgie requires OpenAI or Claude key in Settings > AI."
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
                return "AI output was invalid. widgie created a recovery widget you can edit."
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

    private func recoverFromSchemaFailure(prompt: String, error: Error) -> Bool {
        guard let serviceError = error as? AIWidgetServiceError else {
            return false
        }
        guard case .schemaValidationFailed(let details) = serviceError else {
            return false
        }

        let config = emergencyRecoveryWidget(for: prompt, details: details)
        widgetManager.createOrUpdateWidget(config)
        refreshMenuState()
        commandBarWindow.hide()
        editingWidgetID = nil
        return true
    }

    private struct RecoveryCitySpec {
        let token: String
        let label: String
        let timezone: String
        let weatherLocation: String
        let unit: String
    }

    private func emergencyRecoveryWidget(for prompt: String, details: String) -> WidgetConfig {
        let lower = prompt.lowercased()
        if let timeWeather = emergencyTimeWeatherWidget(for: prompt, normalizedPrompt: lower) {
            return timeWeather
        }

        let title = ComponentConfig(
            type: .text,
            content: "Recovery Widget",
            font: "sf-pro",
            size: 13,
            weight: .semibold,
            color: "secondary"
        )
        let note = ComponentConfig(
            type: .note,
            content: "widgie recovered from an AI schema error and created this editable draft.\n\nPrompt: \(prompt)",
            font: "sf-pro",
            size: 13,
            color: "primary"
        )
        note.editable = true
        let detail = ComponentConfig(
            type: .text,
            content: details,
            font: "sf-mono",
            size: 11,
            color: "muted",
            maxLines: 3
        )
        let root = ComponentConfig(
            type: .vstack,
            alignment: "leading",
            spacing: 8,
            children: [title, note, detail]
        )

        return WidgetConfig(
            name: "Recovery Widget",
            description: prompt,
            size: WidgetSize(width: 420, height: 190),
            minSize: nil,
            maxSize: nil,
            theme: settingsStore.defaultTheme,
            background: BackgroundConfig.default(for: settingsStore.defaultTheme),
            cornerRadius: 20,
            padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
            refreshInterval: 60,
            content: root
        )
    }

    private func emergencyTimeWeatherWidget(for prompt: String, normalizedPrompt: String) -> WidgetConfig? {
        let asksTime = normalizedPrompt.contains("time") || normalizedPrompt.contains("clock")
        let asksWeather = normalizedPrompt.contains("weather") || normalizedPrompt.contains("wether")
        guard asksTime && asksWeather else {
            return nil
        }

        let knownCities: [RecoveryCitySpec] = [
            .init(token: "pune", label: "Pune", timezone: "Asia/Kolkata", weatherLocation: "Pune, Maharashtra, India", unit: "celsius"),
            .init(token: "tempe", label: "Tempe", timezone: "America/Phoenix", weatherLocation: "Tempe, AZ, USA", unit: "fahrenheit"),
            .init(token: "seattle", label: "Seattle", timezone: "America/Los_Angeles", weatherLocation: "Seattle, WA, USA", unit: "fahrenheit"),
            .init(token: "tokyo", label: "Tokyo", timezone: "Asia/Tokyo", weatherLocation: "Tokyo, Japan", unit: "celsius"),
            .init(token: "london", label: "London", timezone: "Europe/London", weatherLocation: "London, UK", unit: "celsius")
        ]

        let cities = knownCities
            .compactMap { city -> (RecoveryCitySpec, Int)? in
                guard let range = normalizedPrompt.range(of: city.token) else {
                    return nil
                }
                let index = normalizedPrompt.distance(from: normalizedPrompt.startIndex, to: range.lowerBound)
                return (city, index)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)

        guard cities.count >= 2 else {
            return nil
        }

        let unit: String? = {
            if normalizedPrompt.contains("celsius") || normalizedPrompt.contains("celcius") || normalizedPrompt.contains("°c") {
                return "celsius"
            }
            if normalizedPrompt.contains("fahrenheit") || normalizedPrompt.contains("fahreneit") || normalizedPrompt.contains("°f") {
                return "fahrenheit"
            }
            return nil
        }()

        let uses12Hour = normalizedPrompt.contains("12 hour")
            || normalizedPrompt.contains("12-hour")
            || normalizedPrompt.contains("12h")
        let format = uses12Hour ? "h:mm a" : "HH:mm"
        let showSeconds = normalizedPrompt.contains("seconds") || normalizedPrompt.contains("sec")

        var rows: [ComponentConfig] = []
        for (index, city) in cities.enumerated() {
            let title = ComponentConfig(
                type: .text,
                content: city.label,
                font: "sf-pro",
                size: 13,
                weight: .semibold,
                color: "secondary"
            )

            let clock = ComponentConfig(type: .clock)
            clock.style = "digital"
            clock.timezone = city.timezone
            clock.format = format
            clock.showSeconds = showSeconds
            clock.font = "sf-mono"
            clock.size = showSeconds ? 24 : 30
            clock.weight = .light
            clock.color = "primary"

            let left = ComponentConfig(
                type: .vstack,
                alignment: "leading",
                spacing: 4,
                children: [title, clock]
            )
            let spacer = ComponentConfig(type: .spacer)

            let weather = ComponentConfig(type: .weather)
            weather.location = city.weatherLocation
            weather.showIcon = true
            weather.showTemperature = true
            weather.showCondition = true
            weather.showHighLow = false
            weather.showHumidity = false
            weather.showWind = false
            weather.showFeelsLike = false
            weather.temperatureUnit = unit ?? city.unit
            weather.style = "compact"
            weather.color = "primary"

            rows.append(
                ComponentConfig(
                    type: .hstack,
                    alignment: "center",
                    spacing: 12,
                    children: [left, spacer, weather]
                )
            )
            if index < cities.count - 1 {
                rows.append(
                    ComponentConfig(
                        type: .divider,
                        color: "muted",
                        direction: "horizontal",
                        thickness: 0.5
                    )
                )
            }
        }

        let root = ComponentConfig(
            type: .vstack,
            alignment: "leading",
            spacing: 10,
            children: rows
        )

        let width = Double(max(440, min(680, 420 + (cities.count - 2) * 40)))
        let height = Double(max(190, min(520, 66 * cities.count + 72)))

        return WidgetConfig(
            name: "Time + Weather",
            description: prompt,
            size: WidgetSize(width: width, height: height),
            minSize: nil,
            maxSize: nil,
            theme: settingsStore.defaultTheme,
            background: BackgroundConfig.default(for: settingsStore.defaultTheme),
            cornerRadius: 20,
            padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 16, trailing: 16),
            refreshInterval: 900,
            content: root
        )
    }
}

private enum TimeoutRefinementAdvisor {
    static func questions(for prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let cityCount = detectedCityCount(in: trimmed)

        if isMultiCityTimeWeatherPrompt(lower: lower, cityCount: cityCount) {
            return """
            AI generation timed out. Quick refine so it can build faster:
            1. Keep exactly \(max(2, cityCount)) cities, or reduce to 2?
            2. Use one weather unit for all cities: celsius or fahrenheit?
            3. Density: compact or detailed?

            Try this prompt:
            "compact 3-row widget: Pune, Tempe, Seattle 12h time on left, weather on right, celsius, no forecast, refresh every 15 minutes"
            """
        }

        if lower.contains("stock") || lower.contains("crypto") || lower.contains("bitcoin") || lower.contains("ethereum") {
            return """
            AI generation timed out. Quick refine so it can build faster:
            1. Which symbols only (max 4)?
            2. Include charts or price + change only?
            3. Refresh speed: 60s, 120s, or 300s?

            Try this prompt:
            "compact wide crypto tracker for BTC and ETH, show price and 24h change only, refresh every 60 seconds"
            """
        }

        if lower.contains("dashboard") || lower.contains("checklist") || lower.contains("calendar") {
            return """
            AI generation timed out. Quick refine so it can build faster:
            1. Pick top 3 sections to include first.
            2. Choose size: medium or large.
            3. Choose style: minimal or detailed.

            Try this prompt:
            "large productivity widget with clock, today's calendar (3 events), and daily checklist (4 items), minimal style"
            """
        }

        return """
        AI generation timed out. Quick refine so it can build faster:
        1. What are the top 1-3 components you want?
        2. Preferred layout: compact wide, medium, or large?
        3. Any must-have details (timezone, unit, symbols)?

        Try this prompt:
        "\(compactPrompt(from: trimmed))"
        """
    }

    private static func isMultiCityTimeWeatherPrompt(lower: String, cityCount: Int) -> Bool {
        let asksTime = lower.contains("time") || lower.contains("clock")
        let asksWeather = lower.contains("weather") || lower.contains("wether")
        return asksTime && asksWeather && cityCount >= 2
    }

    private static func detectedCityCount(in prompt: String) -> Int {
        let split = prompt
            .components(separatedBy: CharacterSet(charactersIn: ",/"))
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // This is intentionally simple: we only need rough complexity signal.
        let likelyCities = split.filter { token in
            let words = token.split(separator: " ")
            return words.count <= 4 && token.range(of: "\\d", options: .regularExpression) == nil
        }

        return min(6, max(1, likelyCities.count))
    }

    private static func compactPrompt(from prompt: String) -> String {
        let cleaned = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count <= 140 {
            return cleaned
        }

        let prefix = cleaned.prefix(140)
        return String(prefix) + "..."
    }
}
