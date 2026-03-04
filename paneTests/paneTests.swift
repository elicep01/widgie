//
//  paneTests.swift
//  paneTests
//
//  Created by Elice Priyadarshini on 16/2/26.
//

import Foundation
import Testing
@testable import widgie

struct paneTests {
    @Test func widgetPatternLibraryIncludesGridHeatmapSection() throws {
        let resourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pane")
            .appendingPathComponent("Resources")
            .appendingPathComponent("WidgetPatternLibrary.md")

        let content = try String(contentsOf: resourcePath, encoding: .utf8)

        #expect(content.contains("SECTION 7: GRID/HEATMAP PATTERNS"))
        #expect(content.contains("Pattern A: DAILY GRID"))
        #expect(content.contains("AI DECISION TREE: Which grid to use?"))
    }

    @Test func generationPromptIncludesGridHeatmapSection() {
        let builder = PromptBuilder(componentSchema: "{}")
        let context = PromptContext(
            currentDate: Date(),
            userTimezone: "America/Chicago",
            userLocation: "Tempe, AZ, USA"
        )

        let prompt = builder.generationSystemPrompt(
            defaultTheme: .obsidian,
            context: context,
            prompt: "show my github contributions last year"
        )

        #expect(prompt.contains("SECTION 7: GRID/HEATMAP PATTERNS"))
        #expect(prompt.contains("Pattern A: DAILY GRID"))
    }

    @Test func promptExampleRetrieverSelectsMostRelevantExample() {
        let retriever = PromptExampleRetriever(examples: [
            PromptExample(
                id: "crypto",
                prompt: "need bitcoin stock and ethereum stock changes live updates",
                intentSummary: "Crypto live row",
                keySignals: ["bitcoin stock", "ethereum stock", "live updates"],
                categories: ["market"],
                outputHints: ["crypto BTC ETH"],
                expectedJSON: nil,
                expectedFile: nil
            ),
            PromptExample(
                id: "clock",
                prompt: "just show me the time, nothing else, keep it tiny",
                intentSummary: "Tiny clock",
                keySignals: ["time", "tiny"],
                categories: ["time"],
                outputHints: ["clock only"],
                expectedJSON: nil,
                expectedFile: nil
            )
        ])

        let selected = retriever.retrieveExamples(
            for: "need bitcoin stock and ethereum stock changes live updates",
            limit: 1
        )
        #expect(selected.first?.id == "crypto")
    }

    @Test func schemaValidatorExtractsFirstBalancedJSONObject() throws {
        let validator = SchemaValidator()
        let valid = makeWidgetJSON(
            name: "Balanced Extract",
            description: "Parse valid object from mixed text",
            contentJSON: #"{"type":"text","content":"Hello","font":"sf-pro","size":14,"color":"primary"}"#
        )
        let raw = """
        some non-json preface
        \(valid)
        trailing note {"foo":"bar"}
        """

        let config = try validator.parseAndValidateWidgetConfig(from: raw)
        #expect(config.name == "Balanced Extract")
        #expect(config.content.type == ComponentType.text)
    }
    
    @Test func generationPipelineRepairsInvalidSchemaWithinBudget() async throws {
        let pipeline = GenerationPipeline(
            promptBuilder: PromptBuilder(componentSchema: "{}"),
            validator: SchemaValidator(),
            callTimeoutSeconds: 1.0,
            totalPipelineTimeoutSeconds: 10.0
        )
        let client = SequencedAIClient(responses: [
            .success(makeWidgetJSON(
                name: "Broken 1",
                description: "Invalid type",
                contentJSON: #"{"type":"ticker","symbol":"BTC"}"#
            )),
            .success(makeWidgetJSON(
                name: "Broken 2",
                description: "Still invalid type",
                contentJSON: #"{"type":"stocks","symbol":"ETH"}"#
            )),
            .success(makeWidgetJSON(
                name: "Crypto Live",
                description: "Recovered schema",
                contentJSON: #"{"type":"crypto","symbol":"BTC","currency":"USD","showPrice":true,"showChange":true,"showChart":false}"#
            ))
        ])
        let context = PromptContext(
            currentDate: Date(),
            userTimezone: "America/Chicago",
            userLocation: "Tempe, AZ, USA"
        )
        
        let config = try await pipeline.generate(
            prompt: "need bitcoin stock and ethereum stock changes live updates",
            defaultTheme: .obsidian,
            context: context,
            generationClient: client
        )

        let components = flattenComponents(config.content)
        let cryptoSymbols = Set(
            components
                .filter { $0.type == .crypto }
                .compactMap { $0.symbol?.uppercased() }
        )

        #expect(cryptoSymbols.contains("BTC"))
        #expect(cryptoSymbols.contains("ETH"))
        #expect(config.refreshInterval <= 120)
        #expect(config.size.width > config.size.height)
        #expect(client.callCount >= 1)
    }
    
    @Test func generationPipelineReturnsValidConfigWhenVerificationFailsWithoutBudget() async throws {
        let pipeline = GenerationPipeline(
            promptBuilder: PromptBuilder(componentSchema: "{}"),
            validator: SchemaValidator(),
            callTimeoutSeconds: 1.0,
            totalPipelineTimeoutSeconds: 10.0
        )
        let client = SequencedAIClient(responses: [
            .success(makeWidgetJSON(
                name: "Broken retry",
                description: "Invalid first attempt",
                contentJSON: #"{"type":"ticker","symbol":"BTC"}"#
            )),
            .success(makeWidgetJSON(
                name: "Recovered on retry",
                description: "Valid second attempt",
                contentJSON: #"{"type":"crypto","symbol":"ETH","currency":"USD","showPrice":true,"showChange":true,"showChart":false}"#
            )),
            .success("""
            FAIL
            - Issue 1: Missing second asset row.
            - Fix 1: Add another crypto component.
            """)
        ])
        let context = PromptContext(
            currentDate: Date(),
            userTimezone: "America/Chicago",
            userLocation: "Tempe, AZ, USA"
        )
        
        let config = try await pipeline.generate(
            prompt: "bitcoin and ethereum live changes",
            defaultTheme: .obsidian,
            context: context,
            generationClient: client
        )

        let components = flattenComponents(config.content)
        let cryptoSymbols = Set(
            components
                .filter { $0.type == .crypto }
                .compactMap { $0.symbol?.uppercased() }
        )

        #expect(cryptoSymbols.contains("BTC") || cryptoSymbols.contains("ETH"))
        #expect(config.refreshInterval <= 120)
        #expect(config.size.width > config.size.height)
        #expect(client.callCount >= 1)
    }

    @Test func generationPipelineReturnsTimeoutErrorAfterExhaustingRecovery() async throws {
        let pipeline = GenerationPipeline(
            promptBuilder: PromptBuilder(componentSchema: "{}"),
            validator: SchemaValidator(),
            callTimeoutSeconds: 1.0,
            totalPipelineTimeoutSeconds: 10.0
        )
        let client = SequencedAIClient(responses: [
            .failure(AIWidgetServiceError.requestFailed("Timed out while waiting for OpenAI response.")),
            .failure(AIWidgetServiceError.requestFailed("Timed out while waiting for OpenAI response."))
        ])
        let context = PromptContext(
            currentDate: Date(),
            userTimezone: "America/Chicago",
            userLocation: "Tempe, AZ, USA"
        )

        do {
            _ = try await pipeline.generate(
                prompt: "bitcoin and ethereum live changes",
                defaultTheme: .obsidian,
                context: context,
                generationClient: client
            )
            Issue.record("Expected timeout error, but generation succeeded.")
        } catch let error as AIWidgetServiceError {
            if case .requestFailed(let message) = error {
                #expect(message.lowercased().contains("timed out"))
            } else {
                Issue.record("Expected requestFailed timeout error, got: \(error)")
            }
            #expect(client.callCount == 2)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func generationPipelineFallsBackToMultiCityTimeWeatherHeuristic() async throws {
        let pipeline = GenerationPipeline(
            promptBuilder: PromptBuilder(componentSchema: "{}"),
            validator: SchemaValidator(),
            callTimeoutSeconds: 1.0,
            totalPipelineTimeoutSeconds: 10.0
        )
        let client = SequencedAIClient(responses: [
            .success(makeWidgetJSON(
                name: "Invalid",
                description: "Wrong output for prompt",
                contentJSON: #"{"type":"stock","symbol":"AAPL","showPrice":true,"showChange":true,"showChangePercent":true,"showChart":false}"#
            )),
            .failure(AIWidgetServiceError.responseParsingFailed)
        ])
        let context = PromptContext(
            currentDate: Date(),
            userTimezone: "America/Chicago",
            userLocation: "Tempe, AZ, USA"
        )

        let config = try await pipeline.generate(
            prompt: "time in 12 hour for pune, tempe, seattle with weather on the right",
            defaultTheme: .obsidian,
            context: context,
            generationClient: client
        )

        let components = flattenComponents(config.content)
        let weatherComponents = components.filter { $0.type == .weather }
        let clockComponents = components.filter { $0.type == .clock }

        #expect(weatherComponents.count >= 3)
        #expect(clockComponents.count >= 3)

        let locations = weatherComponents.compactMap { $0.location?.lowercased() }
        #expect(locations.contains(where: { $0.contains("pune") }))
        #expect(locations.contains(where: { $0.contains("tempe") }))
        #expect(locations.contains(where: { $0.contains("seattle") }))

        let has12HourFormat = clockComponents.allSatisfy { ($0.format ?? "").lowercased().contains("h:mm a") }
        #expect(has12HourFormat)
        #expect(config.size.width > config.size.height)
    }

    @Test func schemaValidatorRepairsGridToLayoutInsteadOfIcon() throws {
        let validator = SchemaValidator()
        let raw = makeWidgetJSON(
            name: "Grid Repair",
            description: "Ensure unknown grid type does not collapse to icon",
            contentJSON: """
            {
              "type": "grid",
              "columns": 2,
              "children": [
                { "type": "crypto", "symbol": "BTC", "currency": "USD", "showPrice": true, "showChange": true, "showChart": false },
                { "type": "crypto", "symbol": "ETH", "currency": "USD", "showPrice": true, "showChange": true, "showChart": false },
                { "type": "stock", "symbol": "gold", "showPrice": true, "showChange": true, "showChangePercent": true, "showChart": false },
                { "type": "stock", "symbol": "silver", "showPrice": true, "showChange": true, "showChangePercent": true, "showChart": false }
              ]
            }
            """,
            width: 420,
            height: 220
        )

        let config = try validator.parseAndValidateWidgetConfig(from: raw)
        #expect(config.content.type == .vstack || config.content.type == .hstack || config.content.type == .container)
        #expect(config.content.type != .icon)
        #expect((config.content.children?.count ?? 0) >= 4)
    }

    @Test func schemaValidatorCanonicalizesGoldAndSilverSymbols() throws {
        let validator = SchemaValidator()
        let raw = makeWidgetJSON(
            name: "Metals Canonical",
            description: "Normalize stock symbols for metals",
            contentJSON: """
            {
              "type": "hstack",
              "children": [
                { "type": "stock", "symbol": "gold", "showPrice": true, "showChange": true, "showChangePercent": true, "showChart": false },
                { "type": "stock", "symbol": "silver", "showPrice": true, "showChange": true, "showChangePercent": true, "showChart": false }
              ]
            }
            """,
            width: 360,
            height: 120
        )

        let config = try validator.parseAndValidateWidgetConfig(from: raw)
        let symbols = Set(flattenComponents(config.content)
            .filter { $0.type == .stock }
            .compactMap { $0.symbol?.uppercased() })
        #expect(symbols.contains("GLD"))
        #expect(symbols.contains("SLV"))
    }

    @Test func schemaValidatorSupportsGitHubRepoStatsAndNormalizesURLSource() throws {
        let validator = SchemaValidator()
        let raw = makeWidgetJSON(
            name: "GitHub Stats",
            description: "Repo stars tracker",
            contentJSON: """
            {
              "type": "github_repo_stats",
              "source": "https://github.com/SuperCmdLabs/SuperCmd",
              "showComponents": ["Stars", "forks", "issues", "watchers", "description"]
            }
            """,
            width: 320,
            height: 180
        )

        let config = try validator.parseAndValidateWidgetConfig(from: raw)
        #expect(config.content.type == .githubRepoStats)
        #expect(config.content.source == "SuperCmdLabs/SuperCmd")
        #expect(config.content.showComponents?.contains("stars") == true)
    }

    @Test func agentPlanWithoutWebDiscoveryHasNoSourceAttribution() async {
        let orchestrator = await MainActor.run {
            AgentOrchestrator(webSearchConnector: NoopAgentWebSearchConnector())
        }

        let decision = await orchestrator.plan(
            prompt: "reddit trends for ai startups",
            clarificationClient: nil
        )

        let plan = extractPlan(from: decision)
        #expect(plan.dataPlan.unsupportedSources.contains("reddit"))
        #expect(plan.dataPlan.sourceAttributions.isEmpty)
    }

    @Test func agentPlanWithWebDiscoveryIncludesSourceAttribution() async {
        let connector = MockAgentWebSearchConnector(results: [
            AgentWebSearchResult(
                provider: "DuckDuckGo",
                title: "AI startup trends",
                url: "https://example.com/ai-startup-trends",
                snippet: "Summary"
            )
        ])
        let orchestrator = await MainActor.run {
            AgentOrchestrator(webSearchConnector: connector)
        }

        let decision = await orchestrator.plan(
            prompt: "reddit trends for ai startups",
            clarificationClient: nil
        )

        let plan = extractPlan(from: decision)
        #expect(plan.dataPlan.unsupportedSources.contains("reddit"))
        #expect(plan.dataPlan.sourceAttributions.count == 1)
        #expect(plan.dataPlan.sourceAttributions.first?.provider == "DuckDuckGo")
        #expect(plan.dataPlan.sourceAttributions.first?.url == "https://example.com/ai-startup-trends")
    }

}

private final class SequencedAIClient: AIProviderClient {
    private var responses: [Result<String, Error>]
    private(set) var callCount = 0
    
    init(responses: [Result<String, Error>]) {
        self.responses = responses
    }
    
    func generateJSON(systemPrompt: String, userPrompt: String) async throws -> String {
        callCount += 1
        guard !responses.isEmpty else {
            throw AIWidgetServiceError.requestFailed("No mock response available.")
        }
        let next = responses.removeFirst()
        return try next.get()
    }
}

private func makeWidgetJSON(
    name: String,
    description: String,
    contentJSON: String,
    width: Int = 320,
    height: Int = 180
) -> String {
    """
    {
      "version": "1.0",
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "\(name)",
      "description": "\(description)",
      "size": { "width": \(width), "height": \(height) },
      "theme": "obsidian",
      "background": {
        "type": "blur",
        "material": "hudWindow",
        "tintColor": "#0D1117",
        "tintOpacity": 0.72
      },
      "cornerRadius": 20,
      "padding": { "top": 16, "bottom": 16, "leading": 16, "trailing": 16 },
      "refreshInterval": 60,
      "content": \(contentJSON)
    }
    """
}

private func flattenComponents(_ root: ComponentConfig) -> [ComponentConfig] {
    var output: [ComponentConfig] = [root]
    if let child = root.child {
        output.append(contentsOf: flattenComponents(child))
    }
    if let children = root.children {
        for child in children {
            output.append(contentsOf: flattenComponents(child))
        }
    }
    return output
}

private struct MockAgentWebSearchConnector: AgentWebSearchConnector {
    let results: [AgentWebSearchResult]

    func search(query: String, limit: Int) async throws -> [AgentWebSearchResult] {
        Array(results.prefix(max(1, limit)))
    }
}

private func extractPlan(from decision: AgentPlanningDecision) -> AgentBuildPlan {
    switch decision {
    case .needsClarification(let plan, _):
        return plan
    case .ready(let plan):
        return plan
    }
}
