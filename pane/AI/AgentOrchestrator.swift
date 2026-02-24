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

struct AgentDataPlan: Codable {
    var requestedSources: [String]
    var supportedSources: [String]
    var unsupportedSources: [String]
    var refreshHintSeconds: Int?
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

    init(promptClarifier: PromptClarifier = PromptClarifier()) {
        self.promptClarifier = promptClarifier
    }

    func plan(
        prompt: String,
        clarificationClient: AIProviderClient?
    ) async -> AgentPlanningDecision {
        let lower = prompt.lowercased()
        let interaction = inferInteractionMode(from: lower)
        let dataPlan = inferDataPlan(from: lower)

        var plan = AgentBuildPlan(
            originalPrompt: prompt,
            synthesizedPrompt: prompt,
            phase: .understand,
            interactionMode: interaction,
            dataPlan: dataPlan,
            openQuestions: [],
            assumptions: defaultAssumptions(for: interaction, dataPlan: dataPlan)
        )

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
            plan.phase = .clarify
            plan.openQuestions = questions
            return .needsClarification(plan: plan, questions: questions)
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

        for (token, isSupported) in sourceTokens where lowerPrompt.contains(token) {
            requested.append(token)
            if isSupported {
                supported.append(token)
            } else {
                unsupported.append(token)
            }
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
            refreshHintSeconds: refreshHint
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
        if let refreshHint = dataPlan.refreshHintSeconds {
            assumptions.append("Target refresh interval around \(refreshHint) seconds when applicable.")
        }
        return assumptions
    }
}
