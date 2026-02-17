import Foundation

struct SchemaValidator {
    private let semanticColors: Set<String> = ["primary", "secondary", "accent", "positive", "negative", "warning", "muted"]
    private let colorRegex = try? NSRegularExpression(pattern: "^#(?:[A-Fa-f0-9]{3}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$")

    func parseAndValidateWidgetConfig(from rawResponse: String) throws -> WidgetConfig {
        let jsonString = try extractJSONObject(from: rawResponse)

        guard let data = jsonString.data(using: .utf8) else {
            throw AIWidgetServiceError.responseParsingFailed
        }

        let decoder = JSONDecoder()
        let config: WidgetConfig

        do {
            config = try decoder.decode(WidgetConfig.self, from: data)
        } catch {
            throw AIWidgetServiceError.schemaValidationFailed("Unable to decode JSON into WidgetConfig: \(error.localizedDescription)")
        }

        try validate(config)
        return config
    }

    private func validate(_ config: WidgetConfig) throws {
        guard config.size.width > 0, config.size.height > 0 else {
            throw AIWidgetServiceError.schemaValidationFailed("size.width and size.height must be positive numbers.")
        }

        guard config.cornerRadius >= 0 else {
            throw AIWidgetServiceError.schemaValidationFailed("cornerRadius cannot be negative.")
        }

        guard config.refreshInterval > 0 else {
            throw AIWidgetServiceError.schemaValidationFailed("refreshInterval must be > 0.")
        }

        if let tintColor = config.background.tintColor {
            try validateColorToken(tintColor, path: "background.tintColor")
        }

        if let color = config.background.color {
            try validateColorToken(color, path: "background.color")
        }

        if let colors = config.background.colors {
            for (index, color) in colors.enumerated() {
                try validateColorToken(color, path: "background.colors[\(index)]")
            }
        }

        try validateComponent(config.content, path: "content", depth: 0)
    }

    private func validateComponent(_ component: ComponentConfig, path: String, depth: Int) throws {
        guard depth < 10 else {
            throw AIWidgetServiceError.schemaValidationFailed("Maximum component nesting depth exceeded at \(path).")
        }

        if let color = component.color {
            try validateColorToken(color, path: "\(path).color")
        }

        if let color = component.workColor {
            try validateColorToken(color, path: "\(path).workColor")
        }

        if let color = component.breakColor {
            try validateColorToken(color, path: "\(path).breakColor")
        }

        if let color = component.trackColor {
            try validateColorToken(color, path: "\(path).trackColor")
        }

        if let color = component.fillColor {
            try validateColorToken(color, path: "\(path).fillColor")
        }

        if let color = component.positiveColor {
            try validateColorToken(color, path: "\(path).positiveColor")
        }

        if let color = component.negativeColor {
            try validateColorToken(color, path: "\(path).negativeColor")
        }

        if let color = component.lowColor {
            try validateColorToken(color, path: "\(path).lowColor")
        }

        if let color = component.checkedColor {
            try validateColorToken(color, path: "\(path).checkedColor")
        }

        if let color = component.uncheckedColor {
            try validateColorToken(color, path: "\(path).uncheckedColor")
        }

        if let color = component.authorColor {
            try validateColorToken(color, path: "\(path).authorColor")
        }

        if let background = component.background,
           !background.hasPrefix("blur:"),
           !background.hasPrefix("gradient:"),
           background != "transparent" {
            try validateColorToken(background, path: "\(path).background")
        }

        switch component.type {
        case .text:
            guard let content = component.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("text.content is required at \(path).")
            }

        case .progressRing, .progressBar:
            guard let source = component.source, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("\(component.type.rawValue).source is required at \(path).")
            }
            if let lineWidth = component.lineWidth, lineWidth <= 0 {
                throw AIWidgetServiceError.schemaValidationFailed("\(component.type.rawValue).lineWidth must be > 0 at \(path).")
            }
            if let height = component.height, height <= 0 {
                throw AIWidgetServiceError.schemaValidationFailed("\(component.type.rawValue).height must be > 0 at \(path).")
            }

        case .icon:
            guard let name = component.name, !name.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("icon.name is required at \(path).")
            }

        case .clock:
            guard let format = component.format, !format.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("clock.format is required at \(path).")
            }
            if let timezone = component.timezone?.trimmingCharacters(in: .whitespacesAndNewlines),
               !timezone.isEmpty {
                if timezone.lowercased() != "local",
                   TimeZone(identifier: timezone) == nil {
                    throw AIWidgetServiceError.schemaValidationFailed("clock.timezone is invalid at \(path).")
                }
            }

        case .analogClock:
            if let timezone = component.timezone?.trimmingCharacters(in: .whitespacesAndNewlines),
               !timezone.isEmpty {
                if timezone.lowercased() != "local",
                   TimeZone(identifier: timezone) == nil {
                    throw AIWidgetServiceError.schemaValidationFailed("analog_clock.timezone is invalid at \(path).")
                }
            }

        case .date:
            guard let format = component.format, !format.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("date.format is required at \(path).")
            }
            if let timezone = component.timezone?.trimmingCharacters(in: .whitespacesAndNewlines),
               !timezone.isEmpty {
                if timezone.lowercased() != "local",
                   TimeZone(identifier: timezone) == nil {
                    throw AIWidgetServiceError.schemaValidationFailed("date.timezone is invalid at \(path).")
                }
            }

        case .countdown:
            guard let targetDate = component.targetDate, !targetDate.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("countdown.targetDate is required at \(path).")
            }

            guard ISO8601DateFormatter().date(from: targetDate) != nil else {
                throw AIWidgetServiceError.schemaValidationFailed("countdown.targetDate must be ISO8601 at \(path).")
            }

        case .timer:
            guard let duration = component.duration, duration > 0 else {
                throw AIWidgetServiceError.schemaValidationFailed("timer.duration must be > 0 at \(path).")
            }

        case .stopwatch:
            break

        case .worldClocks:
            guard let clocks = component.clocks, !clocks.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("world_clocks.clocks must be non-empty at \(path).")
            }

            for (index, entry) in clocks.enumerated() {
                let trimmed = entry.timezone.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw AIWidgetServiceError.schemaValidationFailed("world_clocks.clocks[\(index)].timezone is required at \(path).")
                }
                if trimmed.lowercased() != "local",
                   TimeZone(identifier: trimmed) == nil {
                    throw AIWidgetServiceError.schemaValidationFailed("world_clocks.clocks[\(index)].timezone is invalid at \(path).")
                }
            }

        case .pomodoro:
            guard (component.workDuration ?? 0) > 0 else {
                throw AIWidgetServiceError.schemaValidationFailed("pomodoro.workDuration must be > 0 at \(path).")
            }
            guard (component.breakDuration ?? 0) > 0 else {
                throw AIWidgetServiceError.schemaValidationFailed("pomodoro.breakDuration must be > 0 at \(path).")
            }
            guard (component.longBreakDuration ?? 0) > 0 else {
                throw AIWidgetServiceError.schemaValidationFailed("pomodoro.longBreakDuration must be > 0 at \(path).")
            }
            guard (component.sessionsBeforeLongBreak ?? 0) > 0 else {
                throw AIWidgetServiceError.schemaValidationFailed("pomodoro.sessionsBeforeLongBreak must be > 0 at \(path).")
            }

        case .dayProgress:
            let start = component.startHour ?? 0
            let end = component.endHour ?? 24
            guard (0...23).contains(start), (1...24).contains(end), end > start else {
                throw AIWidgetServiceError.schemaValidationFailed("day_progress requires valid startHour/endHour at \(path).")
            }

        case .yearProgress:
            break

        case .weather:
            guard let location = component.location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("weather.location is required at \(path).")
            }

        case .stock:
            guard let symbol = component.symbol, !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("stock.symbol is required at \(path).")
            }

        case .crypto:
            guard let symbol = component.symbol, !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("crypto.symbol is required at \(path).")
            }

        case .calendarNext:
            if let maxEvents = component.maxEvents, maxEvents <= 0 {
                throw AIWidgetServiceError.schemaValidationFailed("calendar_next.maxEvents must be > 0 at \(path).")
            }

        case .reminders:
            if let maxItems = component.maxItems, maxItems <= 0 {
                throw AIWidgetServiceError.schemaValidationFailed("reminders.maxItems must be > 0 at \(path).")
            }

        case .battery:
            if let lowThreshold = component.lowThreshold, lowThreshold < 0 || lowThreshold > 100 {
                throw AIWidgetServiceError.schemaValidationFailed("battery.lowThreshold must be 0-100 at \(path).")
            }

        case .systemStats:
            break

        case .musicNowPlaying:
            break

        case .newsHeadlines:
            if let feedURL = component.feedUrl {
                guard URL(string: feedURL) != nil else {
                    throw AIWidgetServiceError.schemaValidationFailed("news_headlines.feedUrl is invalid at \(path).")
                }
            }

        case .screenTime:
            if let maxApps = component.maxApps, maxApps <= 0 {
                throw AIWidgetServiceError.schemaValidationFailed("screen_time.maxApps must be > 0 at \(path).")
            }

        case .checklist:
            guard let items = component.items, !items.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("checklist.items must be non-empty at \(path).")
            }
            if items.contains(where: { $0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                throw AIWidgetServiceError.schemaValidationFailed("checklist items require non-empty id/text at \(path).")
            }

        case .habitTracker:
            guard let habits = component.habits, !habits.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("habit_tracker.habits must be non-empty at \(path).")
            }
            if habits.contains(where: { $0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.target <= 0 }) {
                throw AIWidgetServiceError.schemaValidationFailed("habit_tracker habits require id/name and target > 0 at \(path).")
            }

        case .quote:
            if let custom = component.customQuotes, component.source?.lowercased() == "custom", custom.isEmpty {
                throw AIWidgetServiceError.schemaValidationFailed("quote.customQuotes must be non-empty when source is custom at \(path).")
            }

        case .note:
            guard let content = component.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("note.content is required at \(path).")
            }

        case .shortcutLauncher:
            guard let shortcuts = component.shortcuts, !shortcuts.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("shortcut_launcher.shortcuts must be non-empty at \(path).")
            }
            if shortcuts.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                throw AIWidgetServiceError.schemaValidationFailed("shortcut_launcher entries require name/action at \(path).")
            }

        case .linkBookmarks:
            guard let links = component.links, !links.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("link_bookmarks.links must be non-empty at \(path).")
            }
            if links.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || URL(string: $0.url) == nil }) {
                throw AIWidgetServiceError.schemaValidationFailed("link_bookmarks entries require valid name/url at \(path).")
            }

        case .chart:
            guard let source = component.source, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("chart.source is required at \(path).")
            }

        case .vstack, .hstack:
            guard let children = component.children, !children.isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("\(component.type.rawValue).children must be non-empty at \(path).")
            }

            for (index, child) in children.enumerated() {
                try validateComponent(child, path: "\(path).children[\(index)]", depth: depth + 1)
            }

        case .container:
            if let child = component.child {
                try validateComponent(child, path: "\(path).child", depth: depth + 1)
            } else if let children = component.children, let first = children.first {
                try validateComponent(first, path: "\(path).children[0]", depth: depth + 1)
            } else {
                throw AIWidgetServiceError.schemaValidationFailed("container requires child or children at \(path).")
            }

        case .divider, .spacer:
            break
        }

        if component.type != .vstack,
           component.type != .hstack,
           let children = component.children {
            for (index, child) in children.enumerated() {
                try validateComponent(child, path: "\(path).children[\(index)]", depth: depth + 1)
            }
        }

        if component.type != .container,
           let child = component.child {
            try validateComponent(child, path: "\(path).child", depth: depth + 1)
        }
    }

    private func validateColorToken(_ token: String, path: String) throws {
        let lowercased = token.lowercased()

        if semanticColors.contains(lowercased) {
            return
        }

        if lowercased.hasPrefix("#") {
            let fullRange = NSRange(location: 0, length: token.utf16.count)
            if colorRegex?.firstMatch(in: token, options: [], range: fullRange) != nil {
                return
            }
        }

        throw AIWidgetServiceError.schemaValidationFailed("Invalid color token '\(token)' at \(path).")
    }

    private func extractJSONObject(from rawResponse: String) throws -> String {
        let trimmed = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutCodeFence = stripMarkdownCodeFence(from: trimmed)

        guard let firstBrace = withoutCodeFence.firstIndex(of: "{"),
              let lastBrace = withoutCodeFence.lastIndex(of: "}"),
              firstBrace <= lastBrace else {
            throw AIWidgetServiceError.responseParsingFailed
        }

        return String(withoutCodeFence[firstBrace...lastBrace])
    }

    private func stripMarkdownCodeFence(from text: String) -> String {
        guard text.hasPrefix("```") else {
            return text
        }

        var working = text

        if let firstNewline = working.firstIndex(of: "\n") {
            working = String(working[working.index(after: firstNewline)...])
        }

        if let closingFenceRange = working.range(of: "```", options: .backwards) {
            working.removeSubrange(closingFenceRange.lowerBound..<working.endIndex)
        }

        return working.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
