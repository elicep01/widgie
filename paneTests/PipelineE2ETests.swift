import Foundation
import Testing
@testable import pane

private struct E2EHarness {
    let pipeline: GenerationPipeline
    let generationClient: any AIProviderClient
    let verificationClient: any AIProviderClient
    let context: PromptContext
}

private struct E2EScenarioResult {
    let name: String
    let prompt: String
    let passed: Bool
    let failures: [String]
    let outputJSON: String
}

struct PipelineE2ETests {
    @Test("pane real-AI E2E pipeline suite")
    func runRealAIE2ESuite() async throws {
        guard let harness = Self.makeHarnessIfEnabled() else {
            print("Skipping real-AI E2E suite. Set PANE_RUN_E2E_AI_TESTS=1 and provider API key env vars.")
            return
        }

        var results: [E2EScenarioResult] = []

        results.append(await Self.runScenario(
            name: "Test 1: Crypto with typos",
            prompt: "need bitcoin stock and ethereum stock changes live updates",
            harness: harness
        ) { config, components, failures in
            let crypto = components.filter { $0.type == .crypto }
            Self.require(crypto.count >= 2, "Should include at least 2 crypto components.", failures: &failures)

            let symbols = Set(crypto.compactMap { $0.symbol?.lowercased() })
            Self.require(symbols.contains("btc") || symbols.contains("bitcoin"), "Should include BTC crypto component.", failures: &failures)
            Self.require(symbols.contains("eth") || symbols.contains("ethereum"), "Should include ETH crypto component.", failures: &failures)
            Self.require(crypto.allSatisfy { $0.showChange == true }, "Crypto components should include showChange=true.", failures: &failures)

            Self.require(config.refreshInterval <= 120, "Top-level refreshInterval should be <= 120 for live updates.", failures: &failures)
            Self.require(config.size.width > config.size.height, "Widget should be horizontal (width > height).", failures: &failures)

            let badStock = components.contains {
                $0.type == .stock && ["btc", "bitcoin", "eth", "ethereum"].contains(($0.symbol ?? "").lowercased())
            }
            Self.require(!badStock, "BTC/ETH should not be represented as stock components.", failures: &failures)
        })

        results.append(await Self.runScenario(
            name: "Test 2: Typo + timezone + units",
            prompt: "anolog clokc showing greenland time and wether for pune india in celcius",
            harness: harness
        ) { _, components, failures in
            let analog = components.first { $0.type == .analogClock }
            Self.require(analog != nil, "Should include analog_clock component.", failures: &failures)

            let timezone = analog?.timezone ?? ""
            let validGreenland = timezone == "America/Nuuk" || timezone == "America/Godthab"
            Self.require(validGreenland, "Greenland timezone should be America/Nuuk or America/Godthab. Got \(timezone).", failures: &failures)
            Self.require(!timezone.isEmpty && timezone.lowercased() != "local", "Timezone should not be empty/local when Greenland was requested.", failures: &failures)

            let weather = components.first { $0.type == .weather }
            Self.require(weather != nil, "Should include weather component.", failures: &failures)
            Self.require((weather?.location?.lowercased().contains("pune") == true), "Weather location should include Pune.", failures: &failures)
            Self.require(weather?.temperatureUnit?.lowercased() == "celsius", "Weather temperatureUnit should be celsius.", failures: &failures)

            let nonLayoutCount = components.filter { !Self.layoutTypes.contains($0.type) }.count
            Self.require(nonLayoutCount >= 2, "Should include at least two non-layout components.", failures: &failures)
        })

        results.append(await Self.runScenario(
            name: "Test 3: Vague creative request",
            prompt: "something beautiful for my desktop",
            harness: harness
        ) { config, components, failures in
            let nonLayout = components.filter { !Self.layoutTypes.contains($0.type) }
            Self.require(nonLayout.count >= 3, "Creative request should produce at least 3 components.", failures: &failures)

            let uniqueTypes = Set(nonLayout.map(\.type))
            Self.require(uniqueTypes.count >= 2, "Creative request should use at least 2 component types.", failures: &failures)

            let bgType = config.background.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let hasNonFlatBackground = bgType == "blur" || bgType == "gradient" || ((config.background.colors?.count ?? 0) > 1)
            Self.require(hasNonFlatBackground, "Background should be blur/gradient/non-flat for a beautiful widget.", failures: &failures)

            Self.require(config.size.width >= 280, "Widget width should be >= 280.", failures: &failures)
            Self.require(config.size.height >= 160, "Widget height should be >= 160.", failures: &failures)
            Self.require(config.cornerRadius >= 16, "cornerRadius should be >= 16.", failures: &failures)

            let hasNonRegularWeight = nonLayout.contains { component in
                guard let weight = component.weight else { return false }
                return weight != .regular
            }
            Self.require(hasNonRegularWeight, "At least one component should use non-regular font weight.", failures: &failures)

            Self.require(Self.allowedThemes.contains(config.theme), "Theme should be one of the supported themes.", failures: &failures)

            let uniqueSizes = Set(nonLayout.compactMap(\.size))
            Self.require(uniqueSizes.count >= 2, "Should use a mix of font/component sizes for visual hierarchy.", failures: &failures)
        })

        results.append(await Self.runScenario(
            name: "Test 4: Complex dashboard",
            prompt: "job search dashboard with daily checklist that resets, countdown to may 1 2026, madison wisconsin weather in fahrenheit, and a motivational quote that changes daily",
            harness: harness
        ) { config, components, failures in
            let checklist = components.first { $0.type == .checklist }
            Self.require(checklist != nil, "Should include checklist component.", failures: &failures)
            Self.require(checklist?.resetsDaily == true, "Checklist should have resetsDaily=true.", failures: &failures)
            Self.require(checklist?.interactive == true, "Checklist should have interactive=true.", failures: &failures)
            Self.require((checklist?.items?.count ?? 0) >= 3, "Checklist should contain at least 3 items.", failures: &failures)

            let countdown = components.first { $0.type == .countdown }
            Self.require(countdown != nil, "Should include countdown component.", failures: &failures)
            Self.require((countdown?.targetDate?.contains("2026-05-01") == true), "Countdown targetDate should include 2026-05-01.", failures: &failures)

            let weather = components.first { $0.type == .weather }
            Self.require(weather != nil, "Should include weather component.", failures: &failures)
            Self.require((weather?.location?.lowercased().contains("madison") == true), "Weather location should include Madison.", failures: &failures)
            Self.require(weather?.temperatureUnit?.lowercased() == "fahrenheit", "Weather temperatureUnit should be fahrenheit.", failures: &failures)

            let quote = components.first { $0.type == .quote }
            Self.require(quote != nil, "Should include quote component.", failures: &failures)
            Self.require(quote?.refreshInterval?.lowercased() == "daily", "Quote refreshInterval should be daily.", failures: &failures)

            Self.require(config.size.width >= 300, "Complex dashboard width should be >= 300.", failures: &failures)
            Self.require(config.size.height >= 300, "Complex dashboard height should be >= 300.", failures: &failures)

            let hasStackLayout = components.contains { component in
                component.type == .vstack || component.type == .hstack || component.type == .container
            }
            Self.require(hasStackLayout, "Complex dashboard should use stack/container layout.", failures: &failures)

            let allTypes = Set(components.map(\.type))
            Self.require(allTypes.contains(.checklist), "Checklist type missing.", failures: &failures)
            Self.require(allTypes.contains(.countdown), "Countdown type missing.", failures: &failures)
            Self.require(allTypes.contains(.weather), "Weather type missing.", failures: &failures)
            Self.require(allTypes.contains(.quote), "Quote type missing.", failures: &failures)
        })

        results.append(await Self.runScenario(
            name: "Test 5: Minimal sizing",
            prompt: "just show me the time, nothing else, keep it tiny",
            harness: harness
        ) { config, components, failures in
            let nonLayout = components.filter { !Self.layoutTypes.contains($0.type) }
            let timeComponents = nonLayout.filter { $0.type == .clock || $0.type == .analogClock }

            Self.require(timeComponents.count == 1, "Should include exactly one time component.", failures: &failures)

            let disallowed = nonLayout.filter {
                $0.type != .clock && $0.type != .analogClock
            }
            Self.require(disallowed.isEmpty, "Should not include any non-time non-layout components.", failures: &failures)

            Self.require(config.size.width <= 200, "Tiny widget width should be <= 200.", failures: &failures)
            Self.require(config.size.height <= 120, "Tiny widget height should be <= 120.", failures: &failures)
            Self.require(config.size.width > config.size.height, "Tiny time widget should be wider than tall.", failures: &failures)

            Self.require(config.padding.top <= 16, "Padding top should be <= 16.", failures: &failures)
            Self.require(config.padding.bottom <= 16, "Padding bottom should be <= 16.", failures: &failures)
            Self.require(config.padding.leading <= 16, "Padding leading should be <= 16.", failures: &failures)
            Self.require(config.padding.trailing <= 16, "Padding trailing should be <= 16.", failures: &failures)

            let forbiddenTypes: Set<ComponentType> = [
                .quote, .checklist, .weather, .stock, .crypto, .calendarNext, .reminders,
                .battery, .systemStats, .musicNowPlaying, .newsHeadlines, .screenTime,
                .timer, .stopwatch, .countdown, .pomodoro, .habitTracker
            ]
            let hasForbidden = components.contains { forbiddenTypes.contains($0.type) }
            Self.require(!hasForbidden, "Should not include quote/checklist/weather/stock/crypto or other extra data types.", failures: &failures)
        })

        Self.printReport(results)
        let allPassed = results.allSatisfy { $0.passed }
        #expect(allPassed)
    }

    private static let layoutTypes: Set<ComponentType> = [.vstack, .hstack, .container, .spacer, .divider]
    private static let allowedThemes: Set<WidgetTheme> = [.obsidian, .frosted, .neon, .paper, .transparent, .custom]

    private static func makeHarnessIfEnabled() -> E2EHarness? {
        let env = ProcessInfo.processInfo.environment
        guard env["PANE_RUN_E2E_AI_TESTS"] == "1" else {
            return nil
        }

        let provider = env["PANE_E2E_PROVIDER"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "openai"
        let generationClient: (any AIProviderClient)
        let verificationClient: (any AIProviderClient)

        switch provider {
        case "claude":
            let key = env["CLAUDE_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else {
                print("PANE_E2E_PROVIDER=claude but CLAUDE_API_KEY is missing.")
                return nil
            }
            let generationModel = (env["CLAUDE_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "claude-sonnet-4-20250514"
            let verificationModel = (env["CLAUDE_VERIFICATION_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "claude-3-5-haiku-latest"
            generationClient = ClaudeService(apiKey: key, model: generationModel)
            verificationClient = ClaudeService(apiKey: key, model: verificationModel)

        default:
            let key = env["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else {
                print("PANE_E2E_PROVIDER=openai but OPENAI_API_KEY is missing.")
                return nil
            }
            let generationModel = (env["OPENAI_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "gpt-4o"
            let verificationModel = (env["OPENAI_VERIFICATION_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "gpt-4o-mini"
            generationClient = OpenAIService(apiKey: key, model: generationModel)
            verificationClient = OpenAIService(apiKey: key, model: verificationModel)
        }

        let context = PromptContext(
            currentDate: Date(),
            userTimezone: env["PANE_E2E_USER_TIMEZONE"] ?? TimeZone.current.identifier,
            userLocation: env["PANE_E2E_USER_LOCATION"] ?? "Tempe, AZ, USA"
        )

        let pipeline = GenerationPipeline(
            promptBuilder: PromptBuilder(),
            validator: SchemaValidator(),
            callTimeoutSeconds: 25,
            totalPipelineTimeoutSeconds: 140
        )

        return E2EHarness(
            pipeline: pipeline,
            generationClient: generationClient,
            verificationClient: verificationClient,
            context: context
        )
    }

    private static func runScenario(
        name: String,
        prompt: String,
        harness: E2EHarness,
        assertions: (WidgetConfig, [ComponentConfig], inout [String]) -> Void
    ) async -> E2EScenarioResult {
        var failures: [String] = []

        do {
            let config = try await harness.pipeline.generate(
                prompt: prompt,
                defaultTheme: .obsidian,
                context: harness.context,
                generationClient: harness.generationClient,
                verificationClient: harness.verificationClient
            )

            let outputJSON = prettyJSON(config)
            let components = flattenedComponents(from: config.content)

            do {
                _ = try SchemaValidator().parseAndValidateWidgetConfig(from: outputJSON)
            } catch {
                failures.append("Schema validation failed for final output: \(error.localizedDescription)")
            }

            assertions(config, components, &failures)

            return E2EScenarioResult(
                name: name,
                prompt: prompt,
                passed: failures.isEmpty,
                failures: failures,
                outputJSON: outputJSON
            )
        } catch {
            failures.append("Pipeline failed with error: \(error.localizedDescription)")
            return E2EScenarioResult(
                name: name,
                prompt: prompt,
                passed: false,
                failures: failures,
                outputJSON: "{}"
            )
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String, failures: inout [String]) {
        if !condition() {
            failures.append(message)
        }
    }

    private static func flattenedComponents(from component: ComponentConfig) -> [ComponentConfig] {
        var all: [ComponentConfig] = [component]
        if let child = component.child {
            all.append(contentsOf: flattenedComponents(from: child))
        }
        if let children = component.children {
            for nested in children {
                all.append(contentsOf: flattenedComponents(from: nested))
            }
        }
        return all
    }

    private static func prettyJSON(_ config: WidgetConfig) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private static func printReport(_ results: [E2EScenarioResult]) {
        print("\n═══════════════════════════════════════════")
        print("  pane E2E Test Results")
        print("═══════════════════════════════════════════\n")

        for result in results {
            print("\(result.name)")
            print("Prompt: \(result.prompt)")
            if result.passed {
                print("  PASSED")
            } else {
                print("  FAILED")
                for failure in result.failures {
                    print("  - \(failure)")
                }
            }
            print("Output JSON:")
            print(result.outputJSON)
            print("")
        }

        let passed = results.filter(\.passed).count
        print("═══════════════════════════════════════════")
        print("  RESULT: \(passed)/\(results.count) TESTS PASSED")
        print("═══════════════════════════════════════════\n")
    }
}
