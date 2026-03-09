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

        // Ensure good card chrome for medium-sized rendering.
        config.cornerRadius = max(14, min(24, config.cornerRadius.cgFloat)).double
        var p = config.padding
        p.top = max(14, min(24, p.top.cgFloat)).double
        p.bottom = max(14, min(24, p.bottom.cgFloat)).double
        p.leading = max(14, min(24, p.leading.cgFloat)).double
        p.trailing = max(14, min(24, p.trailing.cgFloat)).double
        config.padding = p

        config.content = compactComponent(config.content, templateID: templateID)

        // Compute an explicit compact size per template based on content complexity
        // so gallery snippets don't carry large empty tails.
        let preferredContent = inferredPreferredContentSize(for: config.content)
        let horizontalChrome = p.leading.cgFloat + p.trailing.cgFloat + 10
        let verticalChrome = p.top.cgFloat + p.bottom.cgFloat + 10

        let targetWidth = (preferredContent.width + horizontalChrome).clamped(200, 460)
        var targetHeight = (preferredContent.height + verticalChrome).clamped(130, 320)

        // Prevent overly tall cards; favor readable proportions.
        let softMaxHeight = max(140, (targetWidth * 1.2).rounded(.up))
        targetHeight = min(targetHeight, softMaxHeight.clamped(140, 320))

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
        // Cap maxSize relative to the chosen size so auto-fit doesn't blow the widget
        // far past its intended gallery dimensions. Allow ~30% growth for data loading.
        let chosenSize = config.size
        config.maxSize = WidgetSize(
            width: (chosenSize.width * 1.3).rounded(.up),
            height: (chosenSize.height * 1.3).rounded(.up)
        )
        config.refreshInterval = perTemplateRefreshInterval(id: templateID, fallback: config.refreshInterval)
        return config
    }

    private func compactComponent(_ component: ComponentConfig, templateID: String) -> ComponentConfig {
        let c = component

        if let size = c.size {
            // Keep readable typography for medium-sized widgets.
            let next = size.cgFloat.clamped(11, 36)
            c.size = next.double
        }

        if let spacing = c.spacing {
            c.spacing = spacing.cgFloat.clamped(4, 18).double
        }

        if let padding = c.padding {
            c.padding = EdgeInsetsConfig(
                top: padding.top.cgFloat.clamped(4, 20).double,
                bottom: padding.bottom.cgFloat.clamped(4, 20).double,
                leading: padding.leading.cgFloat.clamped(4, 22).double,
                trailing: padding.trailing.cgFloat.clamped(4, 22).double
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
            component.size = (component.size ?? 15).cgFloat.clamped(13, 24).double
            component.maxLines = min(component.maxLines ?? 6, 6)
        case .clock:
            if component.format?.isEmpty != false {
                component.format = "h:mm a"
            }
            component.showSeconds = false
            if templateID == "clock-minimal" || templateID == "world-clocks" {
                component.size = (component.size ?? 32).cgFloat.clamped(22, 36).double
            } else {
                component.size = (component.size ?? 28).cgFloat.clamped(18, 32).double
            }
        case .analogClock:
            component.showSecondHand = false
            component.lineWidth = (component.lineWidth ?? 2.5).cgFloat.clamped(1.8, 3.5).double
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
            component.forecastDays = min(component.forecastDays ?? 5, 5)
        case .stock, .crypto:
            component.showChart = component.showChart ?? true
            component.chartType = component.chartType ?? "line"
            component.chartPeriod = component.chartPeriod ?? "1d"
            component.showChangePercent = true
            component.size = (component.size ?? 15).cgFloat.clamped(13, 20).double
        case .calendarNext:
            component.maxEvents = min(component.maxEvents ?? 5, 5)
            component.showTime = true
            component.showCalendarColor = true
            component.size = (component.size ?? 14).cgFloat.clamped(13, 20).double
        case .reminders:
            component.maxItems = min(component.maxItems ?? 6, 6)
            component.showCheckbox = true
            component.size = (component.size ?? 14).cgFloat.clamped(13, 20).double
        case .newsHeadlines:
            component.maxItems = min(component.maxItems ?? 5, 5)
            component.showSource = true
            component.size = (component.size ?? 14).cgFloat.clamped(13, 20).double
        case .screenTime:
            component.maxApps = min(component.maxApps ?? 5, 5)
            component.timeRange = component.timeRange ?? "today"
            component.size = (component.size ?? 14).cgFloat.clamped(13, 20).double
        case .checklist:
            component.maxItems = min(component.maxItems ?? 6, 6)
            component.showCheckbox = true
            component.size = (component.size ?? 14).cgFloat.clamped(13, 20).double
        case .habitTracker:
            component.maxItems = min(component.maxItems ?? 6, 6)
            component.showStreak = component.showStreak ?? true
            component.size = (component.size ?? 14).cgFloat.clamped(13, 20).double
        case .note:
            component.maxLines = min(component.maxLines ?? 8, 8)
            component.editable = true
            component.size = (component.size ?? 15).cgFloat.clamped(13, 20).double
        case .quote:
            component.showQuotationMarks = true
            component.maxLines = min(component.maxLines ?? 5, 5)
            component.size = (component.size ?? 15).cgFloat.clamped(14, 22).double
        case .githubRepoStats:
            component.showMetrics = component.showMetrics ?? ["stars", "forks", "issues", "watchers"]
            component.size = (component.size ?? 14).cgFloat.clamped(13, 20).double
        case .shortcutLauncher:
            if let shortcuts = component.shortcuts, shortcuts.count > 8 {
                component.shortcuts = Array(shortcuts.prefix(8))
            }
            component.iconSize = (component.iconSize ?? 18).cgFloat.clamped(14, 24).double
        case .linkBookmarks:
            if let links = component.links, links.count > 8 {
                component.links = Array(links.prefix(8))
            }
            component.showFavicon = true
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
        // ── Standard size: 320x180 (medium) — uniform look across all gallery widgets ──

        // Time
        case "clock-minimal":    return .medium
        case "analog-clock":     return .medium
        case "world-clocks":     return .medium
        case "stopwatch":        return .medium
        case "countdown-newyear":return .medium
        case "day-progress":     return .medium
        case "year-progress":    return .medium

        // Weather
        case "weather-compact":  return .medium
        case "weather-forecast": return .medium

        // Finance
        case "stock-ticker":     return .medium
        case "crypto-tracker":   return .medium

        // Productivity
        case "calendar-agenda":  return .medium
        case "reminders-today":  return .medium
        case "daily-checklist":  return .medium
        case "habit-tracker":    return .medium
        case "notes-pad":        return .medium

        // Inspiration
        case "quote-of-the-day": return .medium

        // Media
        case "now-playing":      return .medium

        // Health
        case "pomodoro-timer":   return .medium
        case "meditation":       return .medium
        case "mood-tracker":     return .medium
        case "period-tracker":   return .medium
        case "virtual-pet":      return .large

        // System
        case "screen-time":      return .medium
        case "github-stats":     return .medium
        case "battery-ring":     return .medium
        case "system-monitor":   return .medium
        case "bookmarks-social": return .medium
        case "quick-launch":     return .medium
        case "news-headlines":   return .medium

        // ── Dashboards: wider because they have multiple sections side-by-side ──
        case "morning-dashboard":  return .wide
        case "productivity-daily": return .medium

        default:
            if category == "dashboard" {
                return .wide
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
            return CGSize(width: 160, height: 160)
        case .timer:
            return component.style?.lowercased() == "ring" ? CGSize(width: 160, height: 160) : CGSize(width: 220, height: 100)
        case .progressRing, .pomodoro:
            return CGSize(width: 160, height: 160)
        case .battery:
            return component.style?.lowercased() == "ring" ? CGSize(width: 150, height: 150) : CGSize(width: 200, height: 80)
        case .weather:
            return component.style?.lowercased() == "compact" ? CGSize(width: 200, height: 80) : CGSize(width: 260, height: 140)
        case .clock:
            return CGSize(width: 200, height: 60)
        case .worldClocks:
            let count = max(1, component.clocks?.count ?? 1)
            return CGSize(width: 260, height: CGFloat(44 + (count * 28)))
        case .checklist:
            let itemCount = max(1, min(component.items?.count ?? 3, component.maxItems ?? 6))
            return CGSize(width: 160, height: CGFloat(28 + itemCount * 22))
        case .calendarNext, .reminders, .newsHeadlines, .habitTracker:
            let itemCount = max(1, min(component.maxItems ?? 4, 6))
            return CGSize(width: 200, height: CGFloat(28 + itemCount * 24))
        case .quote:
            return CGSize(width: 160, height: 60)
        case .countdown, .date, .stock, .crypto, .dayProgress, .yearProgress, .systemStats:
            return CGSize(width: 210, height: 90)
        case .text:
            let text = component.content ?? ""
            let chars = max(1, text.count)
            let width = min(320, max(120, 70 + (chars * 4)))
            let lines = max(1, min(6, Int(ceil(Double(chars) / 26.0))))
            let fontSize = CGFloat(component.size ?? 15)
            let lineHeight = max(14, fontSize * 1.3)
            let height = (CGFloat(lines) * lineHeight) + 10
            return CGSize(width: CGFloat(width), height: height)
        case .virtualPet:
            return CGSize(width: 280, height: 320)
        default:
            return CGSize(width: 180, height: 100)
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
