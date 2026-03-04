import Foundation

enum AgentPhase: String, Codable {
    case understand
    case clarify
    case plan
    case execute
    case critique
    case repair
    case done
}

enum AgentInteractionMode: String, Codable {
    case staticDisplay
    case autoRefreshing
    case userEditable
    case launcher
}

struct AgentSourceAttribution: Codable {
    var provider: String
    var title: String
    var url: String
}

struct AgentDataPlan: Codable {
    var requestedSources: [String]
    var supportedSources: [String]
    var unsupportedSources: [String]
    var missingRequirements: [String]
    var refreshHintSeconds: Int?
    var sourceAttributions: [AgentSourceAttribution]
}

struct AgentBuildPlan: Codable {
    var originalPrompt: String
    var synthesizedPrompt: String
    var phase: AgentPhase
    var interactionMode: AgentInteractionMode
    var dataPlan: AgentDataPlan
    var openQuestions: [ClarificationQuestion]
    var assumptions: [String]
}

struct AgentCritique {
    let issues: [String]
    let confidence: Double
}

struct AgentExecutionOutcome {
    let config: WidgetConfig
    let iterations: Int
    let confidence: Double
    let issues: [String]
}

enum AgentPlanningDecision {
    case needsClarification(plan: AgentBuildPlan, questions: [ClarificationQuestion])
    case ready(plan: AgentBuildPlan)
}

@MainActor
final class AgentOrchestrator {
    private let promptClarifier: PromptClarifier
    private let webSearchConnector: AgentWebSearchConnector

    init(
        promptClarifier: PromptClarifier = PromptClarifier(),
        webSearchConnector: AgentWebSearchConnector = NoopAgentWebSearchConnector()
    ) {
        self.promptClarifier = promptClarifier
        self.webSearchConnector = webSearchConnector
    }

    func plan(
        prompt: String,
        clarificationClient: AIProviderClient?
    ) async -> AgentPlanningDecision {
        let lower = prompt.lowercased()
        let interaction = inferInteractionMode(from: lower)
        let dataPlan = inferDataPlan(from: lower)
        let deterministicQuestions = deterministicClarificationQuestions(
            prompt: prompt,
            lowerPrompt: lower,
            interaction: interaction,
            dataPlan: dataPlan
        )
        let webResolution = await webLookupResolutionIfNeeded(prompt: prompt, dataPlan: dataPlan)

        var plan = AgentBuildPlan(
            originalPrompt: prompt,
            synthesizedPrompt: prompt,
            phase: .understand,
            interactionMode: interaction,
            dataPlan: AgentDataPlan(
                requestedSources: dataPlan.requestedSources,
                supportedSources: dataPlan.supportedSources,
                unsupportedSources: dataPlan.unsupportedSources,
                missingRequirements: dataPlan.missingRequirements,
                refreshHintSeconds: dataPlan.refreshHintSeconds,
                sourceAttributions: webResolution.attributions
            ),
            openQuestions: [],
            assumptions: defaultAssumptions(for: interaction, dataPlan: dataPlan) + webResolution.assumptions
        )

        if !deterministicQuestions.isEmpty {
            plan.phase = .clarify
            plan.openQuestions = deterministicQuestions
            return .needsClarification(plan: plan, questions: deterministicQuestions)
        }

        guard let clarificationClient else {
            plan.phase = .plan
            return .ready(plan: plan)
        }

        let clarification = await promptClarifier.analyze(prompt: prompt, client: clarificationClient)
        switch clarification {
        case .clear:
            plan.phase = .plan
            return .ready(plan: plan)
        case .needsQuestions(let questions):
            let merged = mergeClarificationQuestions(primary: deterministicQuestions, secondary: questions)
            plan.phase = .clarify
            plan.openQuestions = merged
            return .needsClarification(plan: plan, questions: merged)
        }
    }

    func applyClarifications(
        plan: AgentBuildPlan,
        questions: [ClarificationQuestion],
        answers: [String: [String]]
    ) -> AgentBuildPlan {
        var updated = plan
        let enriched = promptClarifier.synthesizePrompt(
            original: plan.originalPrompt,
            questions: questions,
            answers: answers
        )
        updated.synthesizedPrompt = enriched
        updated.openQuestions = []
        updated.phase = .plan
        return updated
    }

    func executionPrompt(for plan: AgentBuildPlan) -> String {
        let interactionLine = "Interaction mode: \(plan.interactionMode.rawValue)."
        let sources = plan.dataPlan.supportedSources.joined(separator: ", ")
        let unsupported = plan.dataPlan.unsupportedSources.joined(separator: ", ")
        let supportedLine = sources.isEmpty ? "Supported data sources: none explicitly requested." : "Supported data sources: \(sources)."
        let unsupportedLine = unsupported.isEmpty ? "" : "Unsupported sources: \(unsupported). Use graceful fallback behavior."
        let assumptionsLine: String
        if plan.assumptions.isEmpty {
            assumptionsLine = ""
        } else {
            assumptionsLine = "Assumptions: " + plan.assumptions.joined(separator: " ")
        }

        return [
            plan.synthesizedPrompt,
            interactionLine,
            supportedLine,
            unsupportedLine,
            assumptionsLine
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n")
    }

    func executeCritiqueRepair(
        plan: AgentBuildPlan,
        service: AIWidgetService,
        maxIterations: Int = 3,
        targetConfidence: Double = 0.82,
        onTrace: ((String) -> Void)? = nil
    ) async throws -> AgentExecutionOutcome {
        let boundedIterations = max(1, maxIterations)
        var workingPlan = plan
        workingPlan.phase = .execute

        onTrace?("Phase: execute")
        var config = try await service.generateWidget(prompt: executionPrompt(for: workingPlan))
        var critiqueResult = critique(config: config, plan: workingPlan)
        var iteration = 1
        onTrace?("Iteration \(iteration): confidence \(formatConfidence(critiqueResult.confidence))")
        if !critiqueResult.issues.isEmpty {
            onTrace?("Issues found: \(critiqueResult.issues.count)")
        }

        while iteration < boundedIterations, critiqueResult.confidence < targetConfidence, !critiqueResult.issues.isEmpty {
            workingPlan.phase = .repair
            onTrace?("Phase: repair")
            let repairPrompt = repairPrompt(for: workingPlan, critique: critiqueResult)
            config = try await service.editWidget(existingConfig: config, editPrompt: repairPrompt)

            workingPlan.phase = .critique
            onTrace?("Phase: critique")
            critiqueResult = critique(config: config, plan: workingPlan)
            iteration += 1
            onTrace?("Iteration \(iteration): confidence \(formatConfidence(critiqueResult.confidence))")
            if !critiqueResult.issues.isEmpty {
                onTrace?("Remaining issues: \(critiqueResult.issues.count)")
            }
        }

        workingPlan.phase = .done
        onTrace?("Phase: done")
        onTrace?("Final confidence: \(formatConfidence(critiqueResult.confidence))")
        return AgentExecutionOutcome(
            config: config,
            iterations: iteration,
            confidence: critiqueResult.confidence,
            issues: critiqueResult.issues
        )
    }

    func lowConfidenceFollowupQuestions(plan: AgentBuildPlan, issues: [String]) -> [ClarificationQuestion] {
        var questions: [ClarificationQuestion] = []

        if issues.contains(where: { $0.lowercased().contains("refresh") }) {
            questions.append(
                ClarificationQuestion(
                    id: "refresh-target",
                    question: "How often should it update?",
                    options: ["1 min", "5 min", "15 min", "Hourly"],
                    allowsMultiple: false
                )
            )
        }

        if plan.interactionMode == .userEditable,
           issues.contains(where: { $0.lowercased().contains("interactive") || $0.lowercased().contains("editable") }) {
            questions.append(
                ClarificationQuestion(
                    id: "interaction-mode",
                    question: "Should users edit it directly?",
                    options: ["Yes, editable", "No, display only"],
                    allowsMultiple: false
                )
            )
        }

        if !plan.dataPlan.unsupportedSources.isEmpty {
            questions.append(
                ClarificationQuestion(
                    id: "fallback-choice",
                    question: "Fallback for unsupported source?",
                    options: ["Use bookmarks", "Use note summary", "Use static text"],
                    allowsMultiple: false
                )
            )
        }

        return Array(questions.prefix(3))
    }

    private func critique(config: WidgetConfig, plan: AgentBuildPlan) -> AgentCritique {
        var weightedIssues: [(String, Double)] = []
        let componentTypes = collectComponentTypes(from: config.content)
        let usesWidgetPreset = WidgetSize.appleWallpaperPresets.contains {
            abs($0.width - config.size.width) < 0.5 && abs($0.height - config.size.height) < 0.5
        }

        if !usesWidgetPreset {
            weightedIssues.append(("Critical: Widget size is not aligned to Apple wallpaper presets.", 0.35))
        }

        switch plan.interactionMode {
        case .userEditable:
            if !config.hasInteractiveContent {
                weightedIssues.append(("Major: Widget should be interactive/editable but generated content is static.", 0.22))
            }
        case .launcher:
            if !componentTypes.contains(.shortcutLauncher) {
                weightedIssues.append(("Major: Launcher intent detected but shortcut launcher component is missing.", 0.24))
            }
        case .autoRefreshing:
            if let hint = plan.dataPlan.refreshHintSeconds,
               abs(config.refreshInterval - hint) > max(30, hint / 2) {
                weightedIssues.append(("Minor: Refresh interval is not close to requested freshness.", 0.10))
            }
        case .staticDisplay:
            break
        }

        if !plan.dataPlan.unsupportedSources.isEmpty,
           !componentTypes.contains(.linkBookmarks),
           !componentTypes.contains(.note),
           !componentTypes.contains(.text) {
            weightedIssues.append(("Major: Unsupported data source requested without graceful fallback component.", 0.22))
        }

        for token in plan.dataPlan.supportedSources {
            if let expected = expectedComponent(for: token),
               !componentTypes.contains(expected) {
                weightedIssues.append(("Minor: Requested \(token) data is missing expected component \(expected.rawValue).", 0.08))
            }
        }

        let penalty = weightedIssues.reduce(0.0) { $0 + $1.1 }
        let confidence = weightedIssues.isEmpty ? 0.96 : max(0.05, 1.0 - min(0.92, penalty))
        return AgentCritique(issues: weightedIssues.map(\.0), confidence: confidence)
    }

    private func repairPrompt(for plan: AgentBuildPlan, critique: AgentCritique) -> String {
        let issueLines = critique.issues.enumerated().map { index, issue in
            "\(index + 1). \(issue)"
        }
        let confidenceLine = String(format: "Current confidence: %.2f", critique.confidence)

        return [
            executionPrompt(for: plan),
            "Repair this widget to address the issues below while preserving style/theme where possible.",
            confidenceLine,
            "Issues:",
            issueLines.joined(separator: "\n")
        ].joined(separator: "\n")
    }

    private func collectComponentTypes(from component: ComponentConfig) -> Set<ComponentType> {
        var result: Set<ComponentType> = [component.type]
        if let child = component.child {
            result.formUnion(collectComponentTypes(from: child))
        }
        if let children = component.children {
            for entry in children {
                result.formUnion(collectComponentTypes(from: entry))
            }
        }
        return result
    }

    private func expectedComponent(for token: String) -> ComponentType? {
        switch token {
        case "weather":
            return .weather
        case "stock":
            return .stock
        case "crypto":
            return .crypto
        case "calendar":
            return .calendarNext
        case "reminder":
            return .reminders
        case "battery":
            return .battery
        case "system":
            return .systemStats
        case "music":
            return .musicNowPlaying
        case "news":
            return .newsHeadlines
        case "screen time":
            return .screenTime
        case "github":
            return .githubRepoStats
        default:
            return nil
        }
    }

    private func formatConfidence(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func inferInteractionMode(from lowerPrompt: String) -> AgentInteractionMode {
        if lowerPrompt.contains("launcher") || lowerPrompt.contains("launch app") || lowerPrompt.contains("shortcut") {
            return .launcher
        }
        if lowerPrompt.contains("checklist")
            || lowerPrompt.contains("todo")
            || lowerPrompt.contains("note")
            || lowerPrompt.contains("journal")
            || lowerPrompt.contains("editable")
            || lowerPrompt.contains("type in") {
            return .userEditable
        }
        if lowerPrompt.contains("live")
            || lowerPrompt.contains("real-time")
            || lowerPrompt.contains("update")
            || lowerPrompt.contains("refresh")
            || lowerPrompt.contains("weather")
            || lowerPrompt.contains("stock")
            || lowerPrompt.contains("crypto") {
            return .autoRefreshing
        }
        return .staticDisplay
    }

    private func inferDataPlan(from lowerPrompt: String) -> AgentDataPlan {
        let sourceTokens: [(String, Bool)] = [
            ("weather", true),
            ("temperature", true),
            ("temp", true),
            ("stock", true),
            ("crypto", true),
            ("calendar", true),
            ("reminder", true),
            ("battery", true),
            ("system", true),
            ("music", true),
            ("news", true),
            ("screen time", true),
            ("github", true),
            ("reddit", false),
            ("notion", false),
            ("x.com", false),
            ("twitter", false),
            ("polymarket", false)
        ]

        var requested: [String] = []
        var supported: [String] = []
        var unsupported: [String] = []
        var missingRequirements: [String] = []

        for (token, isSupported) in sourceTokens where lowerPrompt.contains(token) {
            requested.append(token)
            if isSupported {
                supported.append(token)
            } else {
                unsupported.append(token)
            }
        }

        let requestsWeatherLike = supported.contains("weather")
            || supported.contains("temperature")
            || supported.contains("temp")

        if requestsWeatherLike, !containsLikelyLocation(lowerPrompt) {
            missingRequirements.append("weather_location")
        }
        if requestsWeatherLike, !containsExplicitTemperatureUnit(lowerPrompt) {
            missingRequirements.append("weather_temperature_unit")
        }
        if supported.contains("stock"), !containsTickerSymbols(lowerPrompt) {
            missingRequirements.append("stock_symbols")
        }
        if supported.contains("crypto"), !containsTickerSymbols(lowerPrompt) {
            missingRequirements.append("crypto_symbols")
        }
        if lowerPrompt.contains("launcher"), !containsAppNames(lowerPrompt) {
            missingRequirements.append("launcher_apps")
        }

        let refreshHint: Int?
        if lowerPrompt.contains("real-time") || lowerPrompt.contains("live") {
            refreshHint = 60
        } else if lowerPrompt.contains("daily") {
            refreshHint = 86_400
        } else {
            refreshHint = nil
        }

        return AgentDataPlan(
            requestedSources: requested,
            supportedSources: supported,
            unsupportedSources: unsupported,
            missingRequirements: missingRequirements,
            refreshHintSeconds: refreshHint,
            sourceAttributions: []
        )
    }

    private func defaultAssumptions(for interaction: AgentInteractionMode, dataPlan: AgentDataPlan) -> [String] {
        var assumptions: [String] = []
        if interaction == .userEditable {
            assumptions.append("Prefer interactive components when available.")
        }
        if !dataPlan.unsupportedSources.isEmpty {
            assumptions.append("If unsupported sources are requested, prefer link/bookmark fallback.")
        }
        if !dataPlan.missingRequirements.isEmpty {
            assumptions.append("Missing source details must be clarified before final rendering.")
        }
        if let refreshHint = dataPlan.refreshHintSeconds {
            assumptions.append("Target refresh interval around \(refreshHint) seconds when applicable.")
        }
        return assumptions
    }

    private func deterministicClarificationQuestions(
        prompt: String,
        lowerPrompt: String,
        interaction: AgentInteractionMode,
        dataPlan: AgentDataPlan
    ) -> [ClarificationQuestion] {
        var questions: [ClarificationQuestion] = []

        if dataPlan.missingRequirements.contains("weather_location") {
            questions.append(
                ClarificationQuestion(
                    id: "weather-location",
                    question: "Which city should weather use?",
                    options: ["Current city", "New York", "San Francisco", "London"],
                    allowsMultiple: false
                )
            )
        }

        if dataPlan.missingRequirements.contains("weather_temperature_unit") {
            questions.append(
                ClarificationQuestion(
                    id: "weather-unit",
                    question: "Which temperature unit?",
                    options: ["Celsius", "Fahrenheit"],
                    allowsMultiple: false
                )
            )
        }

        if dataPlan.missingRequirements.contains("stock_symbols") {
            questions.append(
                ClarificationQuestion(
                    id: "stock-symbols",
                    question: "Which stocks should it track?",
                    options: ["AAPL", "MSFT", "NVDA", "TSLA"],
                    allowsMultiple: true
                )
            )
        }

        if dataPlan.missingRequirements.contains("crypto_symbols") {
            questions.append(
                ClarificationQuestion(
                    id: "crypto-symbols",
                    question: "Which crypto should it track?",
                    options: ["BTC", "ETH", "SOL", "DOGE"],
                    allowsMultiple: true
                )
            )
        }

        if dataPlan.missingRequirements.contains("launcher_apps") {
            questions.append(
                ClarificationQuestion(
                    id: "launcher-apps",
                    question: "Which apps should launcher include?",
                    options: ["Safari", "Notes", "Terminal", "Calendar"],
                    allowsMultiple: true
                )
            )
        }

        if interaction == .userEditable,
           (lowerPrompt.contains("checklist") || lowerPrompt.contains("note")),
           !lowerPrompt.contains("editable"),
           !lowerPrompt.contains("read only"),
           !lowerPrompt.contains("read-only") {
            questions.append(
                ClarificationQuestion(
                    id: "editable-vs-static",
                    question: "Should this widget be editable?",
                    options: ["Yes", "No"],
                    allowsMultiple: false
                )
            )
        }

        if (lowerPrompt.contains("live") || lowerPrompt.contains("real-time")) && dataPlan.refreshHintSeconds == nil {
            questions.append(
                ClarificationQuestion(
                    id: "refresh-frequency",
                    question: "How often should it refresh?",
                    options: ["1 min", "5 min", "15 min", "Hourly"],
                    allowsMultiple: false
                )
            )
        }

        if !dataPlan.unsupportedSources.isEmpty, !containsURL(prompt) {
            questions.append(
                ClarificationQuestion(
                    id: "unsupported-source-url",
                    question: "Can you share source URL?",
                    options: ["Yes, I have URL", "No, use fallback"],
                    allowsMultiple: false
                )
            )
        }

        return Array(questions.prefix(3))
    }

    private func mergeClarificationQuestions(
        primary: [ClarificationQuestion],
        secondary: [ClarificationQuestion]
    ) -> [ClarificationQuestion] {
        var merged: [ClarificationQuestion] = []
        var seen = Set<String>()

        for question in primary + secondary {
            guard !seen.contains(question.id) else { continue }
            merged.append(question)
            seen.insert(question.id)
            if merged.count >= 3 { break }
        }
        return merged
    }

    private func webLookupResolutionIfNeeded(
        prompt: String,
        dataPlan: AgentDataPlan
    ) async -> (assumptions: [String], attributions: [AgentSourceAttribution]) {
        guard !dataPlan.unsupportedSources.isEmpty else {
            return ([], [])
        }
        do {
            let results = try await webSearchConnector.search(query: prompt, limit: 2)
            guard !results.isEmpty else {
                return (["No web source resolved; use graceful fallback."], [])
            }
            let attributions = results.map {
                AgentSourceAttribution(provider: $0.provider, title: $0.title, url: $0.url)
            }
            return (["Web hints found; validate relevance before using."], attributions)
        } catch {
            return (["Web search unavailable; use provider fallback and ask user for URL if needed."], [])
        }
    }

    private func containsLikelyLocation(_ lowerPrompt: String) -> Bool {
        let markers = [
            ",", " in ", " at ", "for ", "city", "usa", "india", "uk",
            "london", "tokyo", "new york", "san francisco", "madison",
            "tempe", "pune", "nagpur", "bangalore", "banglore", "bengaluru"
        ]
        return markers.contains(where: { lowerPrompt.contains($0) })
    }

    private func containsTickerSymbols(_ lowerPrompt: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: "\\b[A-Z]{2,5}\\b")
        let nsText = lowerPrompt.uppercased() as NSString
        let matches = regex?.matches(in: lowerPrompt.uppercased(), range: NSRange(location: 0, length: nsText.length)) ?? []
        return !matches.isEmpty
    }

    private func containsExplicitTemperatureUnit(_ lowerPrompt: String) -> Bool {
        let unitMarkers = [
            "celsius", "celcius", "centigrade", "°c",
            "fahrenheit", "fahreneit", "°f"
        ]
        return unitMarkers.contains(where: { lowerPrompt.contains($0) })
    }

    private func containsAppNames(_ lowerPrompt: String) -> Bool {
        let knownApps = ["safari", "notes", "calendar", "mail", "terminal", "finder", "music", "xcode", "chrome"]
        return knownApps.contains(where: { lowerPrompt.contains($0) })
    }

    private func containsURL(_ text: String) -> Bool {
        text.range(of: #"https?://|www\."#, options: .regularExpression) != nil
    }
}
