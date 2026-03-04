import Foundation

/// Persists user-accepted widget generations as prompt examples.
/// Over time this gives the retriever concrete reference configurations
/// for the prompts each user actually types.
@MainActor
final class LearnedExampleStore {
    private static let maxExamples = 100
    private static let fileName = "learned_examples.json"

    private(set) var examples: [PromptExample] = []

    init() {
        examples = Self.loadFromDisk() ?? []
    }

    // MARK: - Public API

    /// Record a prompt + accepted widget config as a new learned example.
    func record(prompt: String, config: WidgetConfig) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return }

        // Don't store the same prompt twice.
        if examples.contains(where: { $0.prompt == trimmed }) { return }

        let example = makeExample(from: trimmed, config: config)
        examples.insert(example, at: 0)

        if examples.count > Self.maxExamples {
            examples = Array(examples.prefix(Self.maxExamples))
        }

        saveToDisk()
    }

    // MARK: - Building an example

    private func makeExample(from prompt: String, config: WidgetConfig) -> PromptExample {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let json = (try? encoder.encode(config)).flatMap { String(data: $0, encoding: .utf8) }

        return PromptExample(
            id: "learned-\(UUID().uuidString.prefix(8).lowercased())",
            prompt: prompt,
            intentSummary: "User-accepted widget: \(config.name)",
            keySignals: extractKeySignals(from: prompt),
            categories: extractCategories(from: config.content),
            outputHints: [],
            expectedJSON: json,
            expectedFile: nil
        )
    }

    private func extractKeySignals(from prompt: String) -> [String] {
        let normalized = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = normalized
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 }

        let stopWords: Set<String> = [
            "the", "and", "for", "with", "that", "this", "show", "make",
            "create", "widget", "display", "want", "need", "just", "only",
            "give", "get", "add", "put", "use", "can", "some"
        ]

        let meaningful = tokens.filter { !stopWords.contains($0) }

        // Collect single-word signals (up to 6).
        var signals = Array(meaningful.prefix(6))

        // Also collect 2-gram phrases from meaningful adjacent tokens.
        let tokenArray = Array(meaningful)
        for i in 0..<(tokenArray.count - 1) {
            let bigram = "\(tokenArray[i]) \(tokenArray[i + 1])"
            signals.append(bigram)
            if signals.count >= 9 { break }
        }

        return Array(Set(signals))
    }

    private func extractCategories(from component: ComponentConfig) -> [String] {
        let allTypes = Set(flattenedTypes(component))
        var categories: [String] = []

        let marketTypes: Set<ComponentType> = [.crypto, .stock]
        let timeTypes: Set<ComponentType> = [
            .clock, .analogClock, .timer, .countdown, .stopwatch,
            .worldClocks, .dayProgress, .yearProgress, .pomodoro
        ]
        let weatherTypes: Set<ComponentType> = [.weather]
        let healthTypes: Set<ComponentType> = [.habitTracker, .checklist]
        let dashboardTypes: Set<ComponentType> = [.calendarNext, .reminders, .note, .quote, .newsHeadlines]

        if !allTypes.isDisjoint(with: marketTypes)   { categories.append("market") }
        if !allTypes.isDisjoint(with: timeTypes)     { categories.append("time") }
        if !allTypes.isDisjoint(with: weatherTypes)  { categories.append("weather") }
        if !allTypes.isDisjoint(with: healthTypes)   { categories.append("health") }
        if !allTypes.isDisjoint(with: dashboardTypes){ categories.append("dashboard") }

        // Multi-category widgets are effectively dashboards.
        if categories.count > 1 { categories.append("dashboard") }
        if categories.isEmpty   { categories = ["creative"] }

        return Array(Set(categories))
    }

    private func flattenedTypes(_ component: ComponentConfig) -> [ComponentType] {
        var types = [component.type]
        if let child = component.child {
            types += flattenedTypes(child)
        }
        if let children = component.children {
            for child in children {
                types += flattenedTypes(child)
            }
        }
        return types
    }

    // MARK: - Persistence

    private static func storeURL() -> URL? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("widgie", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private static func loadFromDisk() -> [PromptExample]? {
        guard let url = storeURL(), let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode([PromptExample].self, from: data)
    }

    private func saveToDisk() {
        guard let url = Self.storeURL() else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(examples) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
