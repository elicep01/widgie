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
                config: compactElegantTemplateConfig($0.config, templateID: $0.id, category: $0.category)
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
        var config = compactElegantTemplateConfig(
            definition.config,
            templateID: definition.id,
            category: definition.category
        )
        config.id = UUID()
        config.name = definition.name
        config.description = definition.description
        config.position = nil
        return config
    }

    private func compactElegantTemplateConfig(
        _ input: WidgetConfig,
        templateID: String,
        category: String?
    ) -> WidgetConfig {
        var config = input

        // Slightly tighter card chrome for cleaner composition.
        config.cornerRadius = max(14, min(22, config.cornerRadius.cgFloat * 0.92)).double
        var p = config.padding
        p.top = max(8, min(18, p.top.cgFloat * 0.88)).double
        p.bottom = max(8, min(18, p.bottom.cgFloat * 0.88)).double
        p.leading = max(8, min(20, p.leading.cgFloat * 0.90)).double
        p.trailing = max(8, min(20, p.trailing.cgFloat * 0.90)).double
        config.padding = p

        config.content = compactComponent(config.content, templateID: templateID)

        // Compute an explicit compact size per template based on content complexity
        // so gallery snippets don't carry large empty tails.
        let preferredContent = inferredPreferredContentSize(for: config.content)
        let horizontalChrome = p.leading.cgFloat + p.trailing.cgFloat + 10
        let verticalChrome = p.top.cgFloat + p.bottom.cgFloat + 10

        let targetWidth = (preferredContent.width + horizontalChrome).clamped(160, 430)
        var targetHeight = (preferredContent.height + verticalChrome).clamped(92, 260)

        // Prevent overly tall cards; favor compact area while keeping readability.
        let softMaxHeight = max(110, (targetWidth * 1.08).rounded(.up))
        targetHeight = min(targetHeight, softMaxHeight.clamped(110, 260))

        // For list-like widgets keep enough vertical room for multiple rows.
        if isListHeavy(config.content) {
            targetHeight = max(targetHeight, 150)
        }

        config.size = perTemplateTargetSize(
            id: templateID,
            category: category,
            fallback: WidgetSize(width: targetWidth.double, height: targetHeight.double)
        )
        config.minSize = nil
        config.maxSize = nil
        config.refreshInterval = perTemplateRefreshInterval(id: templateID, fallback: config.refreshInterval)
        return config
    }

    private func compactComponent(_ component: ComponentConfig, templateID: String) -> ComponentConfig {
        let c = component

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

        // Favor compact presentation styles in gallery templates (preserve forecast).
        if c.type == .weather, c.style?.lowercased() != "forecast" {
            c.style = "compact"
        }

        applyTemplateSpecificPolish(templateID: templateID, component: c)

        if let child = c.child {
            c.child = compactComponent(child, templateID: templateID)
        }
        if let children = c.children {
            c.children = children.map { compactComponent($0, templateID: templateID) }
        }

        return c
    }

    private func applyTemplateSpecificPolish(templateID: String, component: ComponentConfig) {
        switch component.type {
        case .text:
            component.size = (component.size ?? 13).cgFloat.clamped(12, 20).double
            component.maxLines = min(component.maxLines ?? 4, 4)
        case .clock:
            if component.format?.isEmpty != false {
                component.format = "h:mm a"
            }
            component.showSeconds = false
            if templateID == "clock-minimal" || templateID == "world-clocks" {
                component.size = (component.size ?? 26).cgFloat.clamped(16, 26).double
            } else {
                component.size = (component.size ?? 22).cgFloat.clamped(14, 24).double
            }
        case .analogClock:
            component.showSecondHand = false
            component.lineWidth = (component.lineWidth ?? 2.2).cgFloat.clamped(1.6, 2.8).double
            component.alignment = component.alignment ?? "center"
        case .weather:
            if component.style?.lowercased() != "forecast" {
                component.style = "compact"
            }
            component.showHumidity = false
            component.showWind = false
            component.showFeelsLike = false
            component.showCondition = true
            component.showTemperature = true
            component.showHighLow = true
            component.forecastDays = min(component.forecastDays ?? 3, 3)
        case .stock, .crypto:
            component.showChart = component.showChart ?? true
            component.chartType = component.chartType ?? "line"
            component.chartPeriod = component.chartPeriod ?? "1d"
            component.showChangePercent = true
            component.size = (component.size ?? 13.5).cgFloat.clamped(12.5, 18).double
        case .calendarNext:
            component.maxEvents = min(component.maxEvents ?? 4, 4)
            component.showTime = true
            component.showCalendarColor = true
            component.size = (component.size ?? 12.5).cgFloat.clamped(12, 17).double
        case .reminders:
            component.maxItems = min(component.maxItems ?? 5, 5)
            component.showCheckbox = true
            component.size = (component.size ?? 12.5).cgFloat.clamped(12, 17).double
        case .newsHeadlines:
            component.maxItems = min(component.maxItems ?? 4, 4)
            component.showSource = true
            component.size = (component.size ?? 12.5).cgFloat.clamped(12, 17).double
        case .screenTime:
            component.maxApps = min(component.maxApps ?? 4, 4)
            component.timeRange = component.timeRange ?? "today"
            component.size = (component.size ?? 12.5).cgFloat.clamped(12, 17).double
        case .checklist:
            component.maxItems = min(component.maxItems ?? 5, 5)
            component.showCheckbox = true
            component.size = (component.size ?? 12.5).cgFloat.clamped(12, 17).double
        case .habitTracker:
            component.maxItems = min(component.maxItems ?? 5, 5)
            component.showStreak = component.showStreak ?? true
            component.size = (component.size ?? 12.5).cgFloat.clamped(12, 17).double
        case .note:
            component.maxLines = min(component.maxLines ?? 6, 6)
            component.editable = true
            component.size = (component.size ?? 13).cgFloat.clamped(12, 18).double
        case .quote:
            component.showQuotationMarks = true
            component.maxLines = min(component.maxLines ?? 4, 4)
            component.size = (component.size ?? 13).cgFloat.clamped(12.5, 18).double
        case .githubRepoStats:
            component.showMetrics = component.showMetrics ?? ["stars", "forks", "issues", "watchers"]
            component.size = (component.size ?? 12.5).cgFloat.clamped(12, 17).double
        case .shortcutLauncher:
            if let shortcuts = component.shortcuts, shortcuts.count > 6 {
                component.shortcuts = Array(shortcuts.prefix(6))
            }
            component.style = "compact"
            component.iconSize = (component.iconSize ?? 15).cgFloat.clamped(12, 18).double
        case .linkBookmarks:
            if let links = component.links, links.count > 6 {
                component.links = Array(links.prefix(6))
            }
            component.showFavicon = true
            component.style = "compact"
        default:
            break
        }
    }

    private func perTemplateRefreshInterval(id: String, fallback: Int) -> Int {
        switch id {
        case "clock-minimal", "world-clocks", "stopwatch", "analog-clock", "countdown-newyear", "day-progress", "year-progress":
            return 1
        case "weather-compact", "weather-forecast":
            return 900
        case "stock-ticker", "crypto-tracker":
            return 120
        case "now-playing":
            return 10
        case "system-monitor", "battery-ring", "screen-time":
            return 30
        default:
            return fallback
        }
    }

    private func perTemplateTargetSize(id: String, category: String?, fallback: WidgetSize) -> WidgetSize {
        switch id {
        case "clock-minimal": return WidgetSize(width: 168, height: 108)
        case "analog-clock": return WidgetSize(width: 172, height: 172)
        case "world-clocks": return WidgetSize(width: 260, height: 150)
        case "stopwatch": return WidgetSize(width: 204, height: 124)
        case "countdown-newyear": return WidgetSize(width: 220, height: 120)
        case "day-progress": return WidgetSize(width: 196, height: 104)
        case "year-progress": return WidgetSize(width: 196, height: 104)
        case "weather-compact": return WidgetSize(width: 194, height: 112)
        case "weather-forecast": return WidgetSize(width: 250, height: 144)
        case "stock-ticker": return WidgetSize(width: 236, height: 114)
        case "crypto-tracker": return WidgetSize(width: 210, height: 148)
        case "calendar-agenda": return WidgetSize(width: 262, height: 150)
        case "reminders-today": return WidgetSize(width: 250, height: 144)
        case "daily-checklist": return WidgetSize(width: 244, height: 142)
        case "habit-tracker": return WidgetSize(width: 246, height: 144)
        case "notes-pad": return WidgetSize(width: 228, height: 132)
        case "quote-of-the-day": return WidgetSize(width: 206, height: 112)
        case "now-playing": return WidgetSize(width: 236, height: 128)
        case "pomodoro-timer": return WidgetSize(width: 228, height: 140)
        case "screen-time": return WidgetSize(width: 236, height: 132)
        case "github-stats": return WidgetSize(width: 238, height: 118)
        case "battery-ring": return WidgetSize(width: 140, height: 150)
        case "system-monitor": return WidgetSize(width: 238, height: 126)
        case "bookmarks-social": return WidgetSize(width: 228, height: 116)
        case "quick-launch": return WidgetSize(width: 224, height: 108)
        case "morning-dashboard": return WidgetSize(width: 296, height: 174)
        case "productivity-daily": return WidgetSize(width: 286, height: 170)
        case "news-headlines": return WidgetSize(width: 258, height: 148)
        default:
            if category == "dashboard" {
                return WidgetSize(width: 286, height: 172)
            }
            return fallback
        }
    }

    private func inferredPreferredContentSize(for component: ComponentConfig) -> CGSize {
        if component.type == .spacer {
            return .zero
        }

        if component.type == .divider {
            if (component.direction ?? "horizontal").lowercased() == "vertical" {
                return CGSize(width: max(1, CGFloat(component.thickness ?? 1)), height: 1)
            }
            return CGSize(width: 1, height: max(1, CGFloat(component.thickness ?? 1)))
        }

        if component.type == .vstack {
            let children = (component.children ?? (component.child.map { [$0] } ?? []))
                .filter { $0.type != .spacer }
            guard !children.isEmpty else { return CGSize(width: 120, height: 74) }
            let spacing = CGFloat(component.spacing ?? 6)
            let sizes = children.map(inferredPreferredContentSize(for:))
            let width = (sizes.map(\.width).max() ?? 120) + 6
            let height = sizes.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, sizes.count - 1)) + 6
            return CGSize(width: width, height: height)
        }

        if component.type == .hstack {
            let children = (component.children ?? (component.child.map { [$0] } ?? []))
                .filter { $0.type != .spacer && $0.type != .divider }
            guard !children.isEmpty else { return CGSize(width: 160, height: 88) }

            let spacing = CGFloat(component.spacing ?? 8)
            let childSizes = children.map(inferredPreferredContentSize(for:))
            let columns = min(max(1, children.count), 4)

            var rowWidths: [CGFloat] = []
            var rowHeights: [CGFloat] = []
            var idx = 0
            while idx < childSizes.count {
                let end = min(idx + columns, childSizes.count)
                let row = childSizes[idx..<end]
                rowWidths.append(row.map(\.width).reduce(0, +) + spacing * CGFloat(max(0, row.count - 1)))
                rowHeights.append(row.map(\.height).max() ?? 0)
                idx = end
            }

            let width = (rowWidths.max() ?? 120) + 8
            let height = rowHeights.reduce(0, +) + spacing * CGFloat(max(0, rowHeights.count - 1)) + 8
            return CGSize(width: width, height: height)
        }

        if component.type == .container {
            let child = component.child ?? component.children?.first
            let childSize = child.map(inferredPreferredContentSize(for:)) ?? CGSize(width: 140, height: 78)
            let insets = component.padding ?? .medium
            return CGSize(
                width: childSize.width + insets.leading.cgFloat + insets.trailing.cgFloat,
                height: childSize.height + insets.top.cgFloat + insets.bottom.cgFloat
            )
        }

        return inferredPreferredSizeForLeaf(component)
    }

    private func inferredPreferredSizeForLeaf(_ component: ComponentConfig) -> CGSize {
        switch component.type {
        case .analogClock:
            return CGSize(width: 116, height: 116)
        case .timer:
            return component.style?.lowercased() == "ring" ? CGSize(width: 124, height: 124) : CGSize(width: 162, height: 70)
        case .progressRing, .pomodoro:
            return CGSize(width: 120, height: 120)
        case .battery:
            return component.style?.lowercased() == "ring" ? CGSize(width: 116, height: 116) : CGSize(width: 150, height: 62)
        case .weather:
            return component.style?.lowercased() == "compact" ? CGSize(width: 152, height: 58) : CGSize(width: 172, height: 82)
        case .clock:
            return CGSize(width: 148, height: 52)
        case .worldClocks:
            let count = max(1, component.clocks?.count ?? 1)
            return CGSize(width: 216, height: CGFloat(36 + (count * 22)))
        case .checklist, .calendarNext, .reminders, .newsHeadlines, .habitTracker:
            return CGSize(width: 220, height: 132)
        case .countdown, .date, .stock, .crypto, .dayProgress, .yearProgress, .systemStats:
            return CGSize(width: 162, height: 68)
        case .text:
            let text = component.content ?? ""
            let chars = max(1, text.count)
            let width = min(280, max(90, 56 + (chars * 3)))
            let lines = max(1, min(4, Int(ceil(Double(chars) / 26.0))))
            let fontSize = CGFloat(component.size ?? 13)
            let lineHeight = max(11, fontSize * 1.2)
            let height = (CGFloat(lines) * lineHeight) + 6
            return CGSize(width: CGFloat(width), height: height)
        default:
            return CGSize(width: 138, height: 72)
        }
    }

    private func isListHeavy(_ component: ComponentConfig) -> Bool {
        if component.type == .checklist
            || component.type == .calendarNext
            || component.type == .reminders
            || component.type == .newsHeadlines
            || component.type == .habitTracker {
            return true
        }
        if let child = component.child, isListHeavy(child) {
            return true
        }
        if let children = component.children, children.contains(where: { isListHeavy($0) }) {
            return true
        }
        return false
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
