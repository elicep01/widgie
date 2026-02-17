import Foundation

struct WidgetTemplateSummary: Identifiable {
    let id: String
    let name: String
    let description: String
}

final class WidgetTemplateStore {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func availableTemplates() -> [WidgetTemplateSummary] {
        loadDefinitions().map {
            WidgetTemplateSummary(id: $0.id, name: $0.name, description: $0.description)
        }
    }

    func instantiateTemplate(id: String) -> WidgetConfig? {
        guard let definition = loadDefinitions().first(where: { $0.id == id }) else {
            return nil
        }

        var config = definition.config
        config.id = UUID()
        config.name = definition.name
        config.description = definition.description
        config.position = nil
        return config
    }

    func instantiateTemplate(matching query: String) -> WidgetConfig? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let definitions = loadDefinitions()

        if let exact = definitions.first(where: {
            $0.id.lowercased() == lower || $0.name.lowercased() == lower
        }) {
            return instantiate(definition: exact)
        }

        if let partial = definitions.first(where: {
            $0.id.lowercased().contains(lower) || $0.name.lowercased().contains(lower)
        }) {
            return instantiate(definition: partial)
        }

        return nil
    }

    private func instantiate(definition: WidgetTemplateDefinition) -> WidgetConfig {
        var config = definition.config
        config.id = UUID()
        config.name = definition.name
        config.description = definition.description
        config.position = nil
        return config
    }

    private func loadDefinitions() -> [WidgetTemplateDefinition] {
        var candidateURLs: [URL] = []

        if let templatesURL = bundle.resourceURL?.appendingPathComponent("Templates", isDirectory: true),
           let files = try? FileManager.default.contentsOfDirectory(
            at: templatesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            candidateURLs.append(contentsOf: files.filter { $0.pathExtension.lowercased() == "json" })
        }

        if let rootJSON = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            candidateURLs.append(contentsOf: rootJSON)
        }

        let loaded = decodeDefinitions(from: candidateURLs)

        return loaded.isEmpty ? fallbackDefinitions : loaded
    }

    private func decodeDefinitions(from urls: [URL]) -> [WidgetTemplateDefinition] {
        let unique = Array(Set(urls.map(\.lastPathComponent))).compactMap { lastPath in
            urls.first(where: { $0.lastPathComponent == lastPath })
        }

        return unique
            .compactMap { url -> WidgetTemplateDefinition? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(WidgetTemplateDefinition.self, from: data)
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var fallbackDefinitions: [WidgetTemplateDefinition] {
        [
            WidgetTemplateDefinition(
                id: "minimal-clock",
                name: "Minimal Clock",
                description: "Simple local clock with date.",
                config: WidgetConfig(
                    name: "Minimal Clock",
                    description: "Simple local clock with date.",
                    size: .small,
                    theme: .transparent,
                    content: ComponentConfig(
                        type: .vstack,
                        alignment: "center",
                        spacing: 4,
                        children: [
                            ComponentConfig(
                                type: .clock,
                                font: "sf-mono",
                                size: 48,
                                weight: .ultralight,
                                color: "primary",
                                timezone: "local",
                                format: "HH:mm",
                                style: "digital"
                            ),
                            ComponentConfig(
                                type: .date,
                                font: "sf-pro",
                                size: 13,
                                weight: .regular,
                                color: "muted",
                                format: "EEEE, MMM d",
                            )
                        ]
                    )
                )
            )
        ]
    }
}

private struct WidgetTemplateDefinition: Codable {
    let id: String
    let name: String
    let description: String
    let config: WidgetConfig
}
