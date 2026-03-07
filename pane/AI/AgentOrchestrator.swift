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
    case needsClarification(plan: AgentBuildPlan, questions: [ClarificationQuestion], conversation: AgentConversation)
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

        var conversation = AgentConversation(originalPrompt: prompt)

        if !deterministicQuestions.isEmpty {
            plan.phase = .clarify
            plan.openQuestions = deterministicQuestions
            return .needsClarification(plan: plan, questions: deterministicQuestions, conversation: conversation)
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
            return .needsClarification(plan: plan, questions: merged, conversation: conversation)
        }
    }

    /// Continue the conversation after the user answered questions. The AI may ask
    /// follow-up questions if the answers reveal new ambiguity, up to maxRounds.
    func continueClarification(
        plan: AgentBuildPlan,
        conversation: AgentConversation,
        answeredQuestions: [ClarificationQuestion],
        answers: [String: [String]],
        clarificationClient: AIProviderClient?
    ) async -> AgentPlanningDecision {
        var updatedPlan = applyClarifications(
            plan: plan,
            questions: answeredQuestions,
            answers: answers
        )

        guard let clarificationClient, conversation.canContinue else {
            updatedPlan.phase = .plan
            return .ready(plan: updatedPlan)
        }

        let (result, updatedConversation) = await promptClarifier.continueConversation(
            conversation: conversation,
            answeredQuestions: answeredQuestions,
            answers: answers,
            client: clarificationClient
        )

        // Update the synthesized prompt with full conversation context.
        updatedPlan.synthesizedPrompt = promptClarifier.synthesizeFromConversation(updatedConversation)

        switch result {
        case .clear:
            updatedPlan.phase = .plan
            return .ready(plan: updatedPlan)
        case .needsQuestions(let followUpQuestions):
            updatedPlan.phase = .clarify
            updatedPlan.openQuestions = followUpQuestions
            return .needsClarification(
                plan: updatedPlan,
                questions: followUpQuestions,
                conversation: updatedConversation
            )
        }
    }

    /// Plan for an edit operation — reasons about what the edit implies before generating.
    func planEdit(
        existingConfig: WidgetConfig,
        editPrompt: String,
        clarificationClient: AIProviderClient?
    ) async -> AgentPlanningDecision {
        let lower = editPrompt.lowercased()
        let interaction = inferInteractionMode(from: lower)
        let dataPlan = inferDataPlan(from: lower)

        var plan = AgentBuildPlan(
            originalPrompt: editPrompt,
            synthesizedPrompt: editPrompt,
            phase: .understand,
            interactionMode: interaction,
            dataPlan: dataPlan,
            openQuestions: [],
            assumptions: editAssumptions(existingConfig: existingConfig, editPrompt: editPrompt)
        )

        guard let clarificationClient else {
            plan.phase = .plan
            return .ready(plan: plan)
        }

        let editContext = buildEditContext(existingConfig: existingConfig, editPrompt: editPrompt)
        let conversation = AgentConversation(originalPrompt: editContext)

        let clarification = await promptClarifier.analyze(prompt: editContext, client: clarificationClient)
        switch clarification {
        case .clear:
            plan.phase = .plan
            return .ready(plan: plan)
        case .needsQuestions(let questions):
            plan.phase = .clarify
            plan.openQuestions = questions
            return .needsClarification(plan: plan, questions: questions, conversation: conversation)
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
            let sources = plan.dataPlan.unsupportedSources.prefix(2).joined(separator: "/")
            questions.append(
                ClarificationQuestion(
                    id: "fallback-choice",
                    question: "Can't fetch \(sources) live. Best approach?",
                    options: ["Clickable links", "Quick-access launcher", "Notes + bookmarks"],
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
            weightedIssues.append(("Critical: Unsupported data source requested without any fallback. Widget will likely render empty. Must include link_bookmarks or note.", 0.35))
        }

        // Check for news_headlines without a proper feedUrl — high risk of empty widget
        if componentTypes.contains(.newsHeadlines) {
            let hasValidFeed = hasFeedUrl(in: config.content)
            if !hasValidFeed {
                weightedIssues.append(("Major: news_headlines component without explicit feedUrl will default to generic BBC feed. May show irrelevant or no content for topic-specific requests.", 0.20))
            }
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
        case "weather", "temperature", "temp":
            return .weather
        case "stock":
            return .stock
        case "crypto", "bitcoin", "ethereum":
            return .crypto
        case "calendar":
            return .calendarNext
        case "reminder":
            return .reminders
        case "battery":
            return .battery
        case "system", "cpu", "memory":
            return .systemStats
        case "music", "now playing":
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
        let launcherKeywords = ["launcher", "launch app", "shortcut", "quick access", "dock", "open app"]
        if launcherKeywords.contains(where: { lowerPrompt.contains($0) }) {
            return .launcher
        }

        let editableKeywords = [
            "checklist", "todo", "to-do", "to do", "task list", "shopping list",
            "note", "journal", "diary", "memo", "scratch", "jot",
            "editable", "type in", "write", "brain dump",
            "habit", "tracker", "mood", "routine",
            "bookmark", "link"
        ]
        if editableKeywords.contains(where: { lowerPrompt.contains($0) }) {
            return .userEditable
        }

        let autoRefreshKeywords = [
            "live", "real-time", "realtime", "update", "refresh",
            "weather", "stock", "crypto", "bitcoin", "ethereum",
            "news", "headline", "rss",
            "battery", "system", "cpu", "memory",
            "music", "now playing", "screen time",
            "github", "calendar", "reminder"
        ]
        if autoRefreshKeywords.contains(where: { lowerPrompt.contains($0) }) {
            return .autoRefreshing
        }

        return .staticDisplay
    }

    private func inferDataPlan(from lowerPrompt: String) -> AgentDataPlan {
        // Native data sources (built-in providers that fetch real data)
        let sourceTokens: [(String, Bool)] = [
            ("weather", true),
            ("temperature", true),
            ("temp", true),
            ("stock", true),
            ("crypto", true),
            ("bitcoin", true),
            ("ethereum", true),
            ("calendar", true),
            ("reminder", true),
            ("battery", true),
            ("system", true),
            ("cpu", true),
            ("memory", true),
            ("music", true),
            ("now playing", true),
            ("screen time", true),
            ("github", true),
            ("news", true),
            // Unsupported external services — can't fetch, use fallback
            ("reddit", false),
            ("notion", false),
            ("x.com", false),
            ("twitter", false),
            ("polymarket", false),
            ("spotify", false),
            ("instagram", false),
            ("youtube", false),
            ("tiktok", false),
            ("discord", false),
            ("slack", false),
            ("email", false),
            ("gmail", false),
            ("outlook", false),
        ]

        // Composable requests — not "unsupported", just need smart composition
        // These should NOT be flagged as unsupported — the AI knows how to build them
        let composablePatterns = [
            "habit", "tracker", "mood", "water", "exercise", "fitness", "workout",
            "todo", "checklist", "task", "shopping",
            "note", "journal", "diary", "memo", "scratch",
            "quote", "motivation", "affirmation", "inspiration",
            "timer", "stopwatch", "pomodoro", "focus",
            "countdown", "deadline", "event",
            "launcher", "shortcut", "quick access", "dock",
            "bookmark", "link", "favorite",
            "clock", "time", "world clock",
            "progress", "goal", "target",
            "schedule", "routine", "planner",
            "budget", "expense", "money",
            "plant", "pet", "medication", "pill",
            "study", "learning", "flashcard",
            "recipe", "meal", "cooking",
            "project", "kanban", "sprint",
            "period", "cycle", "skincare", "skin care",
            "morning", "evening", "night", "daily",
            "interview", "prep", "resume",
            "game", "gaming", "wishlist", "release",
            "class", "course", "assignment", "homework", "exam",
            "prayer", "meditation", "gratitude", "affirmation",
            "reading", "book", "watchlist", "movie", "show",
            "clean", "cleaning", "chore", "laundry",
            "birthday", "anniversary", "wedding",
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

        // If nothing matched as a data source but the request matches a composable pattern,
        // mark it as supported (the AI can build it from available components)
        if requested.isEmpty {
            let isComposable = composablePatterns.contains(where: { lowerPrompt.contains($0) })
            if isComposable {
                supported.append("composable")
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
            assumptions.append("Prefer interactive components when available (interactive: true on checklists, editable: true on notes).")
        }
        if !dataPlan.unsupportedSources.isEmpty {
            let sources = dataPlan.unsupportedSources.joined(separator: ", ")
            assumptions.append("Cannot fetch live data from: \(sources). Use link_bookmarks with relevant URLs + text header as a useful fallback. NEVER produce an empty widget.")
        }
        if !dataPlan.missingRequirements.isEmpty {
            assumptions.append("Missing source details must be clarified before final rendering.")
        }
        if let refreshHint = dataPlan.refreshHintSeconds {
            assumptions.append("Target refresh interval around \(refreshHint) seconds when applicable.")
        }
        if dataPlan.requestedSources.isEmpty && dataPlan.unsupportedSources.isEmpty {
            assumptions.append("No external data source needed. Compose from interactive/static components to best serve the user's intent.")
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

        // Smart URL asking — if the user mentions a specific service/platform,
        // ask them to paste the link so we can build a much better widget
        if !containsURL(prompt) {
            if !dataPlan.unsupportedSources.isEmpty {
                let service = dataPlan.unsupportedSources.first ?? "that service"
                questions.append(
                    ClarificationQuestion(
                        id: "service-url",
                        question: "Got a \(service) link to include?",
                        options: ["I'll paste a link", "Use defaults"],
                        allowsMultiple: false
                    )
                )
            } else if lowerPrompt.contains("my ") && mentionsLinkableService(lowerPrompt) {
                // User said "my [service]" — they likely have a specific URL
                questions.append(
                    ClarificationQuestion(
                        id: "personal-url",
                        question: "Got a link to include?",
                        options: ["I'll paste a link", "Use defaults"],
                        allowsMultiple: false
                    )
                )
            }
        }

        // GitHub-specific: ask for repo/username if they mention GitHub but don't provide it
        if lowerPrompt.contains("github") && !containsGitHubRef(prompt) && !containsURL(prompt) {
            questions.append(
                ClarificationQuestion(
                    id: "github-repo",
                    question: "Which GitHub repo or username?",
                    options: ["I'll type it"],
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

    private func hasFeedUrl(in component: ComponentConfig) -> Bool {
        if component.type == .newsHeadlines, component.feedUrl != nil {
            return true
        }
        if let child = component.child, hasFeedUrl(in: child) {
            return true
        }
        if let children = component.children {
            for entry in children where hasFeedUrl(in: entry) {
                return true
            }
        }
        return false
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

    /// Detects if the prompt mentions a service the user likely has a personal link for.
    private func mentionsLinkableService(_ lowerPrompt: String) -> Bool {
        let services = [
            "notion", "canvas", "blackboard", "moodle", "coursera",
            "jira", "linear", "trello", "asana",
            "twitch", "youtube", "channel", "stream",
            "portfolio", "website", "blog", "page",
            "figma", "dribbble", "behance",
            "dashboard", "board", "workspace",
            "server", "invite",
        ]
        return services.contains(where: { lowerPrompt.contains($0) })
    }

    /// Detects if the prompt contains a GitHub owner/repo reference.
    private func containsGitHubRef(_ text: String) -> Bool {
        // Matches patterns like "owner/repo" or GitHub URLs
        text.range(of: #"[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+"#, options: .regularExpression) != nil
    }

    // MARK: - Edit Intelligence

    /// Build a context string that describes the edit in terms the AI can reason about.
    private func buildEditContext(existingConfig: WidgetConfig, editPrompt: String) -> String {
        let existingTypes = collectComponentTypes(from: existingConfig.content)
        let typeNames = existingTypes.map(\.rawValue).sorted().joined(separator: ", ")

        return """
        EDIT REQUEST on existing widget.
        Current widget: "\(existingConfig.name)" with components: [\(typeNames)], size: \(Int(existingConfig.size.width))x\(Int(existingConfig.size.height)).
        Edit: "\(editPrompt)"
        Consider what the target state requires that the current state doesn't have. For example, switching from digital to analog clock means using analog_clock component with animated hands. Adding cities means adding timezone data. Adding weather means specifying location and units.
        """
    }

    /// Infer assumptions about what an edit implies.
    private func editAssumptions(existingConfig: WidgetConfig, editPrompt: String) -> [String] {
        let lower = editPrompt.lowercased()
        let existingTypes = collectComponentTypes(from: existingConfig.content)
        var assumptions: [String] = []

        // Digital → analog conversion
        if lower.contains("analog") && existingTypes.contains(.clock) && !existingTypes.contains(.analogClock) {
            assumptions.append("Converting digital clock to analog_clock component with animated rotating hands.")
            assumptions.append("Preserve existing timezone configuration from the digital clock.")
        }

        // Analog → digital conversion
        if (lower.contains("digital") || lower.contains("text clock")) && existingTypes.contains(.analogClock) {
            assumptions.append("Converting analog clock to digital clock component.")
            assumptions.append("Preserve existing timezone configuration.")
        }

        // Adding cities/locations to an existing clock
        if (lower.contains("cities") || lower.contains("city") || lower.contains("multiple")) &&
           (existingTypes.contains(.clock) || existingTypes.contains(.analogClock)) {
            assumptions.append("Expanding to multi-timezone layout. Each city needs its own timezone mapping and clock component.")
            assumptions.append("Layout may need to change to accommodate multiple clock entries.")
        }

        // Adding weather to existing widget
        if (lower.contains("weather") || lower.contains("temperature")) && !existingTypes.contains(.weather) {
            assumptions.append("Adding weather component requires location and temperature unit specification.")
        }

        // Making something interactive
        if lower.contains("interactive") || lower.contains("editable") || lower.contains("check off") {
            assumptions.append("Enable interactive: true on relevant components.")
        }

        // Size implications
        if lower.contains("bigger") || lower.contains("larger") || lower.contains("expand") {
            assumptions.append("Increase to next larger Apple widget size class to fit additional content.")
        }

        if assumptions.isEmpty {
            assumptions.append("Apply the edit while preserving all unmentioned aspects of the existing widget.")
        }

        return assumptions
    }
}
