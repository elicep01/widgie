import Foundation

struct WidgetTemplateSummary: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
}

struct StoreTemplateItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    let config: WidgetConfig
}

final class WidgetTemplateStore {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    // MARK: - Legacy template summaries (menu bar, etc.)

    func availableTemplates() -> [WidgetTemplateSummary] {
        loadDefinitions().map {
            WidgetTemplateSummary(id: $0.id, name: $0.name, description: $0.description, category: $0.category ?? "other")
        }
    }

    // MARK: - Store items (full configs for preview)

    func storeItems() -> [StoreTemplateItem] {
        loadStoreDefinitions().map {
            StoreTemplateItem(
                id: $0.id,
                name: $0.name,
                description: $0.description,
                category: $0.category ?? "other",
                config: compactElegantTemplateConfig($0.config)
            )
        }
    }

    func storeCategories() -> [String] {
        let cats = Set(loadStoreDefinitions().compactMap(\.category))
        let order = ["time", "productivity", "weather", "finance", "health", "system", "media", "inspiration", "dashboard"]
        return order.filter { cats.contains($0) } + cats.sorted().filter { !order.contains($0) }
    }

    // MARK: - Instantiation

    func instantiateTemplate(id: String) -> WidgetConfig? {
        let all = loadDefinitions() + loadStoreDefinitions()
        guard let definition = all.first(where: { $0.id == id }) else {
            return nil
        }
        return instantiate(definition: definition)
    }

    func instantiateTemplate(id: String, theme: WidgetTheme) -> WidgetConfig? {
        guard var config = instantiateTemplate(id: id) else { return nil }
        config.theme = theme
        config.background = BackgroundConfig.default(for: theme)
        return config
    }

    func instantiateTemplate(matching query: String) -> WidgetConfig? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let definitions = loadDefinitions() + loadStoreDefinitions()

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

    // MARK: - Private

    private func instantiate(definition: WidgetTemplateDefinition) -> WidgetConfig {
        var config = compactElegantTemplateConfig(definition.config)
        config.id = UUID()
        config.name = definition.name
        config.description = definition.description
        config.position = nil
        return config
    }

    private func compactElegantTemplateConfig(_ input: WidgetConfig) -> WidgetConfig {
        var config = input

        // Keep templates compact by default without collapsing tiny cards.
        let compactWidth = (config.size.width.cgFloat * 0.90).clamped(170, 460)
        let compactHeight = (config.size.height.cgFloat * 0.86).clamped(120, 320)
        config.size = WidgetSize(width: compactWidth.double, height: compactHeight.double)
        config.minSize = nil
        config.maxSize = nil

        // Slightly tighter card chrome for cleaner composition.
        config.cornerRadius = max(14, min(22, config.cornerRadius.cgFloat * 0.92)).double
        var p = config.padding
        p.top = max(8, min(18, p.top.cgFloat * 0.88)).double
        p.bottom = max(8, min(18, p.bottom.cgFloat * 0.88)).double
        p.leading = max(8, min(20, p.leading.cgFloat * 0.90)).double
        p.trailing = max(8, min(20, p.trailing.cgFloat * 0.90)).double
        config.padding = p

        config.content = compactComponent(config.content)
        return config
    }

    private func compactComponent(_ component: ComponentConfig) -> ComponentConfig {
        var c = component

        if let size = c.size {
            // Cap oversized template typography and tighten defaults.
            let next = (size.cgFloat * 0.90).clamped(10, 30)
            c.size = next.double
        }

        if let spacing = c.spacing {
            c.spacing = (spacing.cgFloat * 0.86).clamped(2, 14).double
        }

        if let padding = c.padding {
            c.padding = EdgeInsetsConfig(
                top: (padding.top.cgFloat * 0.86).clamped(0, 16).double,
                bottom: (padding.bottom.cgFloat * 0.86).clamped(0, 16).double,
                leading: (padding.leading.cgFloat * 0.90).clamped(0, 18).double,
                trailing: (padding.trailing.cgFloat * 0.90).clamped(0, 18).double
            )
        }

        // Favor compact presentation styles in gallery templates.
        if c.type == .weather {
            c.style = "compact"
        }

        if let child = c.child {
            c.child = compactComponent(child)
        }
        if let children = c.children {
            c.children = children.map(compactComponent)
        }

        return c
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

    private func loadStoreDefinitions() -> [WidgetTemplateDefinition] {
        // Try StoreTemplates subdirectory first (folder reference builds).
        var urls: [URL] = []
        if let storeURL = bundle.resourceURL?.appendingPathComponent("StoreTemplates", isDirectory: true),
           let files = try? FileManager.default.contentsOfDirectory(
            at: storeURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            urls = files.filter { $0.pathExtension.lowercased() == "json" }
        }

        // Fallback: scan flattened root JSON files and filter by category field.
        if urls.isEmpty, let rootJSON = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            urls = rootJSON
        }

        return decodeDefinitions(from: urls).filter { $0.category != nil }
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
                category: "time",
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
    let category: String?
    let config: WidgetConfig
}

private extension Double {
    var cgFloat: CGFloat { CGFloat(self) }
}

private extension CGFloat {
    var double: Double { Double(self) }

    func clamped(_ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, minValue), maxValue)
    }
}
