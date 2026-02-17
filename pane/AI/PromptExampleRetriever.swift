import Foundation

struct PromptExample: Codable {
    let id: String
    let prompt: String
    let intentSummary: String
    let keySignals: [String]
    let categories: [String]
    let outputHints: [String]
    let expectedJSON: String?
    let expectedFile: String?
}

struct PromptExampleRetriever {
    private struct PromptExampleCollection: Codable {
        let examples: [PromptExample]
    }

    private let examples: [PromptExample]

    init(examples: [PromptExample]? = nil) {
        if let examples, !examples.isEmpty {
            self.examples = examples
        } else {
            self.examples = Self.loadExamples()
        }
    }

    func formattedExamples(for prompt: String, limit: Int = 4) -> String {
        let selected = retrieveExamples(for: prompt, limit: limit)
        guard !selected.isEmpty else { return "" }

        return selected.enumerated()
            .map { index, example in
                let expected = renderedExpectedJSON(for: example)
                if !expected.isEmpty {
                    return """
                    Example \(index + 1)
                    User: "\(example.prompt)"
                    Expected JSON: \(expected)
                    """
                }

                let hints = example.outputHints.isEmpty
                    ? ""
                    : "\nOutput hints: \(example.outputHints.joined(separator: "; "))"
                return """
                Example \(index + 1)
                User: "\(example.prompt)"
                Intent: \(example.intentSummary)\(hints)
                """
            }
            .joined(separator: "\n\n")
    }

    func retrieveExamples(for prompt: String, limit: Int = 4) -> [PromptExample] {
        let normalizedPrompt = Self.normalized(prompt)
        guard !normalizedPrompt.isEmpty else { return [] }

        let promptTokens = Set(Self.tokens(from: normalizedPrompt))
        var scored: [(example: PromptExample, score: Int)] = []

        for example in examples {
            let score = score(example: example, normalizedPrompt: normalizedPrompt, promptTokens: promptTokens)
            if score > 0 {
                scored.append((example, score))
            }
        }

        scored.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.example.id < rhs.example.id
            }
            return lhs.score > rhs.score
        }

        var selected: [PromptExample] = []
        var usedCategories: Set<String> = []

        for candidate in scored {
            let categories = Set(candidate.example.categories.map { $0.lowercased() })
            let overlapsCategory = !usedCategories.isDisjoint(with: categories)

            // Keep variety when we already have enough examples.
            if overlapsCategory, selected.count >= max(2, limit - 1) {
                continue
            }

            selected.append(candidate.example)
            usedCategories.formUnion(categories)

            if selected.count >= limit {
                break
            }
        }

        if selected.isEmpty, let fallback = examples.first(where: { $0.categories.contains("creative") }) {
            return [fallback]
        }

        return selected
    }

    private func score(
        example: PromptExample,
        normalizedPrompt: String,
        promptTokens: Set<String>
    ) -> Int {
        var score = 0

        let examplePromptTokens = Set(Self.tokens(from: Self.normalized(example.prompt)))
        let overlapCount = promptTokens.intersection(examplePromptTokens).count
        score += min(10, overlapCount)

        for signal in example.keySignals {
            let normalizedSignal = Self.normalized(signal)
            guard !normalizedSignal.isEmpty else { continue }

            if normalizedPrompt.contains(normalizedSignal) {
                score += 12
                continue
            }

            let signalTokens = Set(Self.tokens(from: normalizedSignal))
            if !signalTokens.isEmpty, signalTokens.isSubset(of: promptTokens) {
                score += 8
            }
        }

        // Broad intent boosts.
        let broadSignals: [(category: String, terms: [String])] = [
            ("market", ["stock", "stocks", "ticker", "bitcoin", "ethereum", "crypto", "btc", "eth"]),
            ("weather", ["weather", "wether", "temperature", "celsius", "fahrenheit"]),
            ("time", ["clock", "time", "timezone", "timer", "countdown", "analog", "anolog", "clokc"]),
            ("dashboard", ["dashboard", "productivity", "checklist", "quote", "focus"]),
            ("creative", ["beautiful", "surprise", "desktop", "bored"])
        ]

        for broad in broadSignals {
            let hasPromptTerm = broad.terms.contains { normalizedPrompt.contains($0) }
            if hasPromptTerm, example.categories.map({ $0.lowercased() }).contains(broad.category) {
                score += 6
            }
        }

        return score
    }

    private static func loadExamples() -> [PromptExample] {
        if let custom = loadCustomDiskExamples(), !custom.isEmpty {
            return custom
        }

        if let bundled = loadBundledExamples(), !bundled.isEmpty {
            return bundled
        }

        return fallbackExamples
    }

    private static func loadCustomDiskExamples() -> [PromptExample]? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let url = appSupport
            .appendingPathComponent("pane", isDirectory: true)
            .appendingPathComponent("prompt_examples.json")

        return decodeExamples(at: url)
    }

    private static func loadBundledExamples() -> [PromptExample]? {
        guard let url = Bundle.main.url(forResource: "PromptExamples", withExtension: "json") else {
            return nil
        }
        return decodeExamples(at: url)
    }

    private static func decodeExamples(at url: URL) -> [PromptExample]? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([PromptExample].self, from: data) {
            return direct
        }

        if let wrapped = try? decoder.decode(PromptExampleCollection.self, from: data) {
            return wrapped.examples
        }

        return nil
    }

    private func renderedExpectedJSON(for example: PromptExample) -> String {
        if let inline = example.expectedJSON,
           !inline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Self.minifiedJSONIfPossible(inline)
        }

        if let file = example.expectedFile,
           let text = loadExampleJSONFromFile(fileName: file) {
            return Self.minifiedJSONIfPossible(text)
        }

        return ""
    }

    private func loadExampleJSONFromFile(fileName: String) -> String? {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let customURL = Self.customExamplesDirectory()
            .appendingPathComponent(trimmed)
        if let text = try? String(contentsOf: customURL, encoding: .utf8) {
            return text
        }

        let ns = trimmed as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        let extensionValue = ext.isEmpty ? "json" : ext

        if let url = Bundle.main.url(
            forResource: base,
            withExtension: extensionValue,
            subdirectory: "PromptExamples"
        ),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }

        return nil
    }

    private static func customExamplesDirectory() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("pane", isDirectory: true)
            .appendingPathComponent("prompt_examples", isDirectory: true)
    }

    private static func minifiedJSONIfPossible(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let minifiedData = try? JSONSerialization.data(withJSONObject: object, options: []),
              let minified = String(data: minifiedData, encoding: .utf8) else {
            return trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        }

        return minified
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokens(from value: String) -> [String] {
        value.split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static let fallbackExamples: [PromptExample] = [
        PromptExample(
            id: "fallback-crypto-live",
            prompt: "need bitcoin stock and ethereum stock changes live updates",
            intentSummary: "Interpret bitcoin/ethereum as crypto, show BTC and ETH with live price changes in a horizontal layout.",
            keySignals: ["bitcoin stock", "ethereum stock", "live updates", "crypto"],
            categories: ["market"],
            outputHints: ["Use crypto components for BTC and ETH", "showChange true", "refreshInterval <= 120", "width > height"],
            expectedJSON: "{\"name\":\"Crypto Tracker\",\"size\":{\"width\":300,\"height\":110},\"theme\":\"obsidian\",\"background\":{\"type\":\"blur\",\"material\":\"hudWindow\",\"tintColor\":\"#0D1117\",\"tintOpacity\":0.7},\"cornerRadius\":16,\"padding\":{\"top\":14,\"bottom\":14,\"leading\":18,\"trailing\":18},\"content\":{\"type\":\"hstack\",\"alignment\":\"center\",\"spacing\":20,\"children\":[{\"type\":\"crypto\",\"symbol\":\"BTC\",\"currency\":\"USD\",\"showPrice\":true,\"showChange\":true,\"showChart\":false,\"color\":\"#F7931A\"},{\"type\":\"divider\",\"color\":\"muted\",\"thickness\":0.5,\"direction\":\"vertical\"},{\"type\":\"crypto\",\"symbol\":\"ETH\",\"currency\":\"USD\",\"showPrice\":true,\"showChange\":true,\"showChart\":false,\"color\":\"#627EEA\"}]},\"refreshInterval\":60}",
            expectedFile: nil
        ),
        PromptExample(
            id: "fallback-analog-greenland",
            prompt: "anolog clokc showing greenland time and wether for pune india in celcius",
            intentSummary: "Use analog clock with Greenland timezone and weather for Pune in celsius.",
            keySignals: ["anolog", "clokc", "greenland time", "wether", "pune", "celcius"],
            categories: ["time", "weather"],
            outputHints: ["analog_clock", "timezone America/Nuuk", "weather location Pune, India", "temperatureUnit celsius"],
            expectedJSON: nil,
            expectedFile: nil
        ),
        PromptExample(
            id: "fallback-tiny-time",
            prompt: "just show me the time, nothing else, keep it tiny",
            intentSummary: "Return a minimal tiny time-only widget with compact rectangle sizing.",
            keySignals: ["just show me the time", "nothing else", "tiny"],
            categories: ["time"],
            outputHints: ["single clock component", "width <= 200", "height <= 120", "width > height"],
            expectedJSON: "{\"name\":\"Clock\",\"size\":{\"width\":160,\"height\":72},\"theme\":\"obsidian\",\"background\":{\"type\":\"blur\",\"material\":\"hudWindow\",\"tintColor\":\"#0D1117\",\"tintOpacity\":0.7},\"cornerRadius\":16,\"padding\":{\"top\":14,\"bottom\":14,\"leading\":20,\"trailing\":20},\"content\":{\"type\":\"clock\",\"style\":\"digital\",\"timezone\":\"local\",\"format\":\"HH:mm\",\"showSeconds\":false,\"font\":\"sf-mono\",\"size\":36,\"weight\":\"ultralight\",\"color\":\"primary\"}}",
            expectedFile: nil
        ),
        PromptExample(
            id: "fallback-dashboard",
            prompt: "job search dashboard with daily checklist that resets, countdown to may 1 2026, weather in fahrenheit, and a quote that changes daily",
            intentSummary: "Build a full dashboard including checklist, countdown, weather, and daily quote.",
            keySignals: ["job search dashboard", "checklist resets", "countdown may 1 2026", "fahrenheit", "quote changes daily"],
            categories: ["dashboard"],
            outputHints: ["include all 4 requested component types", "resetsDaily true", "countdown targetDate includes 2026-05-01", "quote refreshInterval daily"],
            expectedJSON: nil,
            expectedFile: nil
        )
    ]
}
