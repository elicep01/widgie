import Foundation

struct SchemaValidator {
    private let semanticColors: Set<String> = ["primary", "secondary", "accent", "positive", "negative", "warning", "muted"]
    private let colorRegex = try? NSRegularExpression(pattern: "^#(?:[A-Fa-f0-9]{3}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$")

    private let allowedThemes: Set<String> = Set(WidgetTheme.allCases.map(\.rawValue))
    private let allowedComponentTypes: Set<String> = [
        "text", "icon", "divider", "spacer", "progress_ring", "progress_bar", "chart",
        "clock", "analog_clock", "date", "countdown", "timer", "stopwatch", "world_clocks",
        "pomodoro", "day_progress", "year_progress",
        "weather", "stock", "crypto", "calendar_next", "reminders", "battery", "system_stats",
        "music_now_playing", "news_headlines", "screen_time",
        "checklist", "habit_tracker", "quote", "note", "shortcut_launcher", "link_bookmarks", "github_repo_stats",
        "vstack", "hstack", "container"
    ]
    private let orderedComponentTypes: [String] = [
        "text", "icon", "divider", "spacer", "progress_ring", "progress_bar", "chart",
        "clock", "analog_clock", "date", "countdown", "timer", "stopwatch", "world_clocks",
        "pomodoro", "day_progress", "year_progress",
        "weather", "stock", "crypto", "calendar_next", "reminders", "battery", "system_stats",
        "music_now_playing", "news_headlines", "screen_time",
        "checklist", "habit_tracker", "quote", "note", "shortcut_launcher", "link_bookmarks", "github_repo_stats",
        "vstack", "hstack", "container"
    ]

    private let componentTypeAliases: [String: String] = [
        "cryptocurrency": "crypto",
        "crypto_currency": "crypto",
        "cryptoasset": "crypto",
        "crypto_asset": "crypto",
        "coin": "crypto",
        "coins": "crypto",
        "token": "crypto",
        "tokens": "crypto",
        "stock_ticker": "stock",
        "stockticker": "stock",
        "stocks": "stock",
        "ticker": "stock",
        "equity": "stock",
        "equities": "stock",
        "commodity": "stock",
        "commodities": "stock",
        "metal": "stock",
        "metals": "stock",
        "analog": "analog_clock",
        "anolog": "analog_clock",
        "analogclock": "analog_clock",
        "analogue_clock": "analog_clock",
        "timer_countdown": "countdown",
        "count_down": "countdown",
        "countdown_timer": "countdown",
        "worldclock": "world_clocks",
        "worldclocks": "world_clocks",
        "calendar": "calendar_next",
        "events": "calendar_next",
        "todo": "checklist",
        "todos": "checklist",
        "vertical_stack": "vstack",
        "horizontal_stack": "hstack",
        "stack_v": "vstack",
        "stack_h": "hstack",
        "grid": "vstack",
        "matrix": "vstack",
        "table": "vstack",
        "zstack": "vstack",
        // Mood / wellness aliases → habit_tracker
        "mood_tracker": "habit_tracker",
        "moodtracker": "habit_tracker",
        "mood": "habit_tracker",
        "moods": "habit_tracker",
        "wellness_tracker": "habit_tracker",
        "wellnesstracker": "habit_tracker",
        "feeling_tracker": "habit_tracker",
        "emotion_tracker": "habit_tracker",
        "daily_tracker": "habit_tracker",
        "tracker": "habit_tracker",
        // Journal / notes aliases → note
        "journal": "note",
        "diary": "note",
        "memo": "note",
        "sticky": "note",
        "sticky_note": "note",
        // Habits
        "habits": "habit_tracker",
        "routine": "habit_tracker",
        "daily_habits": "habit_tracker",
        // GitHub repo stats aliases
        "githubstats": "github_repo_stats",
        "github_stats": "github_repo_stats",
        "github_repo": "github_repo_stats",
        "repo_stats": "github_repo_stats",
        "repo_tracker": "github_repo_stats",
    ]

    private let widgetAllowedKeys: Set<String> = [
        "version", "id", "name", "description",
        "size", "minSize", "maxSize", "position",
        "theme", "background", "cornerRadius", "padding",
        "refreshInterval", "content", "dataSources"
    ]

    private let componentAllowedKeys: Set<String> = [
        "type", "id",
        "content", "title", "name", "font", "size", "weight", "color", "alignment", "maxLines", "opacity",
        "timezone", "format", "showSeconds", "showSecondHand", "showControls", "showLaps", "showSessionCount",
        "showAlbumArt", "showArtist", "showTitle", "showProgress", "showTime", "showSource", "showIcon",
        "showTemperature", "showCondition", "showHighLow", "showHumidity", "showWind", "showFeelsLike",
        "showStreak", "showFavicon", "showQuotationMarks", "showChange", "showPrice", "showChangePercent",
        "showChart", "showDueDate", "showCheckbox", "showCalendarColor", "showPercentage", "showTimeRemaining",
        "label", "source", "targetDate", "showComponents", "style", "category", "editable", "resetsDaily",
        "refreshInterval",
        "strikethrough", "completedText", "clocks", "items", "habits", "shortcuts", "links", "customQuotes",
        "checkedColor", "uncheckedColor", "authorColor", "iconSize", "chartType", "chartPeriod",
        "duration", "autoStart", "workDuration", "breakDuration", "longBreakDuration", "sessionsBeforeLongBreak",
        "workColor", "breakColor", "trackColor", "fillColor", "positiveColor", "negativeColor", "lowColor",
        "startHour", "endHour", "location", "symbol", "currency", "temperatureUnit", "sourceSystem", "feedUrl",
        "list", "emptyText", "timeRange", "device", "interactive", "maxEvents", "maxItems", "maxApps",
        "forecastDays", "rotateInterval", "albumArtSize", "lineWidth", "height", "lowThreshold", "showMetrics",
        "direction", "thickness", "spacing", "padding", "background", "cornerRadius", "border", "shadow",
        "owner", "repo", "showStars", "showForks", "showIssues", "showWatchers", "showDescription",
        "child", "children"
    ]

    private let componentStringKeys: Set<String> = [
        "id", "content", "title", "name", "font", "weight", "color", "alignment", "timezone", "format",
        "label", "source", "targetDate", "style", "category", "completedText", "checkedColor", "uncheckedColor",
        "refreshInterval",
        "authorColor", "chartType", "chartPeriod", "workColor", "breakColor", "trackColor", "fillColor",
        "positiveColor", "negativeColor", "lowColor", "location", "symbol", "currency", "temperatureUnit",
        "sourceSystem", "feedUrl", "list", "emptyText", "timeRange", "device", "direction", "background"
    ]

    private let componentIntKeys: Set<String> = [
        "maxLines", "duration", "workDuration", "breakDuration", "longBreakDuration",
        "sessionsBeforeLongBreak", "startHour", "endHour", "maxEvents", "maxItems", "maxApps",
        "forecastDays", "rotateInterval"
    ]

    private let componentDoubleKeys: Set<String> = [
        "size", "opacity", "iconSize", "albumArtSize", "lineWidth", "height", "lowThreshold",
        "thickness", "spacing", "cornerRadius"
    ]

    private let componentBoolKeys: Set<String> = [
        "showSeconds", "showSecondHand", "showControls", "showLaps", "showSessionCount",
        "showAlbumArt", "showArtist", "showTitle", "showProgress", "showTime", "showSource",
        "showIcon", "showTemperature", "showCondition", "showHighLow", "showHumidity", "showWind",
        "showFeelsLike", "showStreak", "showFavicon", "showQuotationMarks", "showChange", "showPrice",
        "showChangePercent", "showChart", "showDueDate", "showCheckbox", "showCalendarColor",
        "showPercentage", "showTimeRemaining", "editable", "resetsDaily", "strikethrough",
        "autoStart", "interactive"
    ]

    private let componentStringArrayKeys: Set<String> = [
        "showComponents", "customQuotes", "showMetrics"
    ]

    func parseAndValidateWidgetConfig(from rawResponse: String) throws -> WidgetConfig {
        let candidates = extractJSONObjectCandidates(from: rawResponse)
        var errors: [String] = []

        for candidate in candidates {
            for variant in cleanupVariants(for: candidate) {
                do {
                    let normalizedData = try normalizedWidgetJSONData(from: variant)
                    let config = try decodeWidgetConfig(from: normalizedData)
                    try validate(config)
                    return config
                } catch let serviceError as AIWidgetServiceError {
                    errors.append(serviceError.localizedDescription)
                } catch {
                    errors.append(error.localizedDescription)
                }
            }
        }

        if let last = errors.last, !last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AIWidgetServiceError.schemaValidationFailed(last)
        }

        throw AIWidgetServiceError.responseParsingFailed
    }

    private func decodeWidgetConfig(from data: Data) throws -> WidgetConfig {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(WidgetConfig.self, from: data)
        } catch let decodingError as DecodingError {
            throw AIWidgetServiceError.schemaValidationFailed(Self.describe(decodingError))
        } catch {
            throw AIWidgetServiceError.schemaValidationFailed("Unable to decode JSON into WidgetConfig: \(error.localizedDescription)")
        }
    }

    private func normalizedWidgetJSONData(from jsonText: String) throws -> Data {
        guard let data = jsonText.data(using: .utf8) else {
            throw AIWidgetServiceError.responseParsingFailed
        }

        let rawObject: Any
        do {
            rawObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw AIWidgetServiceError.responseParsingFailed
        }

        guard var widget = rawObject as? [String: Any] else {
            throw AIWidgetServiceError.schemaValidationFailed("Top-level JSON must be an object.")
        }

        normalizeWidgetDictionary(&widget)

        do {
            return try JSONSerialization.data(withJSONObject: widget, options: [])
        } catch {
            throw AIWidgetServiceError.schemaValidationFailed("Unable to serialize normalized widget JSON: \(error.localizedDescription)")
        }
    }

    private func normalizeWidgetDictionary(_ widget: inout [String: Any]) {
        applyWidgetKeyAliases(&widget)
        widget = filterDictionary(widget, allowedKeys: widgetAllowedKeys)

        let theme = sanitizeTheme(widget["theme"])
        widget["theme"] = theme
        widget["version"] = nonEmptyString(widget["version"]) ?? "1.0"
        widget["id"] = sanitizeUUID(widget["id"])
        widget["name"] = nonEmptyString(widget["name"]) ?? "Custom Widget"
        widget["description"] = nonEmptyString(widget["description"]) ?? (widget["name"] as? String ?? "Custom Widget")
        widget["size"] = sanitizeSize(widget["size"], defaultWidth: 320, defaultHeight: 180)
        widget["padding"] = sanitizePadding(widget["padding"], defaults: (16, 16, 16, 16))
        widget["background"] = sanitizeBackground(widget["background"], theme: theme)
        widget["cornerRadius"] = max(0, coerceDouble(widget["cornerRadius"]) ?? 20)
        widget["refreshInterval"] = max(1, coerceInt(widget["refreshInterval"]) ?? 60)

        if let minSizeRaw = widget["minSize"] {
            widget["minSize"] = sanitizeSize(minSizeRaw, defaultWidth: 120, defaultHeight: 80)
        }

        if let maxSizeRaw = widget["maxSize"] {
            widget["maxSize"] = sanitizeSize(maxSizeRaw, defaultWidth: 1200, defaultHeight: 900)
        }

        if let positionRaw = widget["position"] {
            if let position = sanitizePosition(positionRaw) {
                widget["position"] = position
            } else {
                widget.removeValue(forKey: "position")
            }
        }

        if let dataSourcesRaw = widget["dataSources"] {
            if let dataSources = sanitizeDataSources(dataSourcesRaw), !dataSources.isEmpty {
                widget["dataSources"] = dataSources
            } else {
                widget.removeValue(forKey: "dataSources")
            }
        }

        if var content = widget["content"] as? [String: Any] {
            normalizeComponentDictionary(&content)
            widget["content"] = content
        } else if let contentText = nonEmptyString(widget["content"]) {
            var content = defaultTextComponent(contentText)
            normalizeComponentDictionary(&content)
            widget["content"] = content
        } else {
            var content = defaultTextComponent("Widget")
            normalizeComponentDictionary(&content)
            widget["content"] = content
        }
    }

    private func applyWidgetKeyAliases(_ widget: inout [String: Any]) {
        let aliases: [String: String] = [
            "corner_radius": "cornerRadius",
            "refresh_interval": "refreshInterval",
            "data_sources": "dataSources",
            "min_size": "minSize",
            "max_size": "maxSize",
            "target_date": "targetDate"
        ]

        for (from, to) in aliases where widget[to] == nil {
            if let value = widget[from] {
                widget[to] = value
            }
        }
    }

    private func sanitizeDataSources(_ raw: Any) -> [String: Any]? {
        guard let dictionary = raw as? [String: Any] else {
            return nil
        }

        var result: [String: Any] = [:]
        for (name, value) in dictionary {
            guard let source = value as? [String: Any] else {
                continue
            }

            var cleaned: [String: Any] = [:]
            if let provider = nonEmptyString(source["provider"]) {
                cleaned["provider"] = provider
            }
            if let refresh = coerceInt(source["refreshInterval"]), refresh > 0 {
                cleaned["refreshInterval"] = refresh
            }
            if let location = nonEmptyString(source["location"]) {
                cleaned["location"] = location
            }
            if let symbols = coerceStringArray(source["symbols"]), !symbols.isEmpty {
                let lowerName = name.lowercased()
                if lowerName.contains("crypto") {
                    cleaned["symbols"] = symbols.map { canonicalCryptoSymbol($0) }
                } else {
                    cleaned["symbols"] = symbols.map { canonicalStockSymbol($0) }
                }
            }

            if !cleaned.isEmpty {
                result[name] = cleaned
            }
        }

        return result
    }

    private func sanitizePosition(_ raw: Any) -> [String: Any]? {
        guard let dictionary = raw as? [String: Any] else {
            return nil
        }

        guard let x = coerceDouble(dictionary["x"]),
              let y = coerceDouble(dictionary["y"]) else {
            return nil
        }

        return ["x": x, "y": y]
    }

    private func sanitizeTheme(_ raw: Any?) -> String {
        let theme = normalizedToken(raw)
        if let theme, allowedThemes.contains(theme) {
            return theme
        }
        return "obsidian"
    }

    private func sanitizeUUID(_ raw: Any?) -> String {
        if let text = nonEmptyString(raw), UUID(uuidString: text) != nil {
            return text
        }
        return UUID().uuidString
    }

    private func sanitizeSize(_ raw: Any?, defaultWidth: Double, defaultHeight: Double) -> [String: Any] {
        guard let dictionary = raw as? [String: Any] else {
            return ["width": defaultWidth, "height": defaultHeight]
        }

        let width = max(1, coerceDouble(dictionary["width"]) ?? defaultWidth)
        let height = max(1, coerceDouble(dictionary["height"]) ?? defaultHeight)
        return ["width": width, "height": height]
    }

    private func sanitizePadding(_ raw: Any?, defaults: (Double, Double, Double, Double)) -> [String: Any] {
        guard let dictionary = raw as? [String: Any] else {
            return [
                "top": defaults.0,
                "bottom": defaults.1,
                "leading": defaults.2,
                "trailing": defaults.3
            ]
        }

        let top = coerceDouble(dictionary["top"]) ?? defaults.0
        let bottom = coerceDouble(dictionary["bottom"]) ?? defaults.1
        let leading = coerceDouble(dictionary["leading"]) ?? defaults.2
        let trailing = coerceDouble(dictionary["trailing"]) ?? defaults.3

        return [
            "top": max(0, top),
            "bottom": max(0, bottom),
            "leading": max(0, leading),
            "trailing": max(0, trailing)
        ]
    }

    private func sanitizeBackground(_ raw: Any?, theme: String) -> [String: Any] {
        var background = (raw as? [String: Any]) ?? defaultBackground(theme: theme)

        if let type = normalizedToken(background["type"]), ["blur", "solid", "gradient"].contains(type) {
            background["type"] = type
        } else {
            background["type"] = (background["color"] != nil || background["colors"] != nil) ? "solid" : "blur"
        }

        if let material = nonEmptyString(background["material"]) {
            background["material"] = material
        } else if (background["type"] as? String) == "blur" {
            background["material"] = theme == "frosted" ? "popover" : "hudWindow"
        } else {
            background.removeValue(forKey: "material")
        }

        if let tint = nonEmptyString(background["tintColor"]) {
            if !isValidColorToken(tint) {
                background["tintColor"] = defaultBackground(theme: theme)["tintColor"]
            } else {
                background["tintColor"] = tint
            }
        }

        if let tintOpacity = coerceDouble(background["tintOpacity"]) {
            background["tintOpacity"] = min(max(tintOpacity, 0), 1)
        }

        if let color = nonEmptyString(background["color"]) {
            if isValidColorToken(color) {
                background["color"] = color
            } else {
                background.removeValue(forKey: "color")
            }
        }

        if let colors = coerceStringArray(background["colors"]) {
            let validColors = colors.filter { isValidColorToken($0) }
            if validColors.isEmpty {
                background.removeValue(forKey: "colors")
            } else {
                background["colors"] = validColors
            }
        }

        if (background["type"] as? String) == "gradient", background["colors"] == nil {
            background["colors"] = ["#0D1117", "#161B22"]
        }

        return background
    }

    private func defaultBackground(theme: String) -> [String: Any] {
        let widgetTheme = WidgetTheme(rawValue: theme) ?? .obsidian
        let bg = BackgroundConfig.default(for: widgetTheme)

        var result: [String: Any] = ["type": bg.type]
        if let material = bg.material { result["material"] = material }
        if let tintColor = bg.tintColor { result["tintColor"] = tintColor }
        if let tintOpacity = bg.tintOpacity { result["tintOpacity"] = tintOpacity }
        if let color = bg.color { result["color"] = color }
        return result
    }

    private func normalizeComponentDictionary(_ component: inout [String: Any]) {
        applyComponentKeyAliases(&component)
        component = filterDictionary(component, allowedKeys: componentAllowedKeys)

        if let rawType = nonEmptyString(component["type"]), let canonical = canonicalComponentType(rawType) {
            component["type"] = canonical
        } else if let canonical = canonicalComponentType(normalizedToken(component["type"]) ?? "") {
            component["type"] = canonical
        } else {
            component["type"] = "text"
        }

        if let id = nonEmptyString(component["id"]) {
            component["id"] = id
        } else {
            component.removeValue(forKey: "id")
        }

        for key in componentStringKeys {
            guard component[key] != nil else { continue }
            if let value = nonEmptyString(component[key]) {
                component[key] = value
            } else {
                component.removeValue(forKey: key)
            }
        }

        for key in componentIntKeys {
            guard component[key] != nil else { continue }
            if let value = coerceInt(component[key]) {
                component[key] = value
            } else {
                component.removeValue(forKey: key)
            }
        }

        for key in componentDoubleKeys {
            guard component[key] != nil else { continue }
            if let value = coerceDouble(component[key]) {
                component[key] = value
            } else {
                component.removeValue(forKey: key)
            }
        }

        for key in componentBoolKeys {
            guard component[key] != nil else { continue }
            if let value = coerceBool(component[key]) {
                component[key] = value
            } else {
                component.removeValue(forKey: key)
            }
        }

        for key in componentStringArrayKeys {
            guard component[key] != nil else { continue }
            if let value = coerceStringArray(component[key]), !value.isEmpty {
                component[key] = value
            } else {
                component.removeValue(forKey: key)
            }
        }

        if let padding = component["padding"] {
            component["padding"] = sanitizePadding(padding, defaults: (12, 12, 12, 12))
        }

        if let border = component["border"] as? [String: Any] {
            var sanitized: [String: Any] = [:]
            if let color = nonEmptyString(border["color"]), isValidColorToken(color) {
                sanitized["color"] = color
            }
            if let width = coerceDouble(border["width"]), width >= 0 {
                sanitized["width"] = width
            }
            component["border"] = sanitized.isEmpty ? nil : sanitized
        }

        if let shadow = component["shadow"] as? [String: Any] {
            var sanitized: [String: Any] = [:]
            if let color = nonEmptyString(shadow["color"]), isValidColorToken(color) {
                sanitized["color"] = color
            }
            if let opacity = coerceDouble(shadow["opacity"]) {
                sanitized["opacity"] = min(max(opacity, 0), 1)
            }
            if let radius = coerceDouble(shadow["radius"]) {
                sanitized["radius"] = max(0, radius)
            }
            if let x = coerceDouble(shadow["x"]) {
                sanitized["x"] = x
            }
            if let y = coerceDouble(shadow["y"]) {
                sanitized["y"] = y
            }
            component["shadow"] = sanitized.isEmpty ? nil : sanitized
        }

        if let clocksRaw = component["clocks"] {
            component["clocks"] = sanitizeWorldClocks(clocksRaw)
        }
        if let itemsRaw = component["items"] {
            component["items"] = sanitizeChecklistItems(itemsRaw)
        }
        if let habitsRaw = component["habits"] {
            component["habits"] = sanitizeHabits(habitsRaw)
        }
        if let shortcutsRaw = component["shortcuts"] {
            component["shortcuts"] = sanitizeShortcuts(shortcutsRaw)
        }
        if let linksRaw = component["links"] {
            component["links"] = sanitizeLinks(linksRaw)
        }

        if let child = component["child"] as? [String: Any] {
            var normalizedChild = child
            normalizeComponentDictionary(&normalizedChild)
            component["child"] = normalizedChild
        } else {
            component.removeValue(forKey: "child")
        }

        if let children = coerceComponentArray(component["children"]) {
            var normalizedChildren: [[String: Any]] = []
            for child in children {
                var normalizedChild = child
                normalizeComponentDictionary(&normalizedChild)
                normalizedChildren.append(normalizedChild)
            }
            component["children"] = normalizedChildren
        } else {
            component.removeValue(forKey: "children")
        }

        let type = (component["type"] as? String) ?? "text"
        fillRequiredDefaults(component: &component, type: type)
    }

    private func applyComponentKeyAliases(_ component: inout [String: Any]) {
        if component["showMetrics"] == nil, component["show"] != nil {
            component["showMetrics"] = component["show"]
        }

        let aliases: [String: String] = [
            "show_seconds": "showSeconds",
            "show_second_hand": "showSecondHand",
            "show_controls": "showControls",
            "show_session_count": "showSessionCount",
            "show_album_art": "showAlbumArt",
            "show_artist": "showArtist",
            "show_title": "showTitle",
            "show_progress": "showProgress",
            "show_time": "showTime",
            "show_source": "showSource",
            "show_icon": "showIcon",
            "show_temperature": "showTemperature",
            "show_condition": "showCondition",
            "show_high_low": "showHighLow",
            "show_humidity": "showHumidity",
            "show_wind": "showWind",
            "show_feels_like": "showFeelsLike",
            "show_streak": "showStreak",
            "show_favicon": "showFavicon",
            "show_quotation_marks": "showQuotationMarks",
            "show_change": "showChange",
            "show_price": "showPrice",
            "show_change_percent": "showChangePercent",
            "show_chart": "showChart",
            "show_due_date": "showDueDate",
            "show_checkbox": "showCheckbox",
            "show_calendar_color": "showCalendarColor",
            "show_percentage": "showPercentage",
            "show_time_remaining": "showTimeRemaining",
            "target_date": "targetDate",
            "show_components": "showComponents",
            "custom_quotes": "customQuotes",
            "chart_type": "chartType",
            "chart_period": "chartPeriod",
            "auto_start": "autoStart",
            "work_duration": "workDuration",
            "break_duration": "breakDuration",
            "long_break_duration": "longBreakDuration",
            "sessions_before_long_break": "sessionsBeforeLongBreak",
            "start_hour": "startHour",
            "end_hour": "endHour",
            "temperature_unit": "temperatureUnit",
            "max_events": "maxEvents",
            "max_items": "maxItems",
            "max_apps": "maxApps",
            "forecast_days": "forecastDays",
            "rotate_interval": "rotateInterval",
            "album_art_size": "albumArtSize",
            "icon_size": "iconSize",
            "line_width": "lineWidth",
            "low_threshold": "lowThreshold",
            "source_system": "sourceSystem"
        ]

        for (from, to) in aliases where component[to] == nil {
            if let value = component[from] {
                component[to] = value
            }
        }

        // Legacy/template GitHub fields.
        if component["source"] == nil {
            let owner = nonEmptyString(component["owner"])
            let repo = nonEmptyString(component["repo"])
            if let owner, let repo {
                component["source"] = "\(owner)/\(repo)"
            } else if let repo {
                component["source"] = repo
            }
        }

        if component["showComponents"] == nil {
            var fields: [String] = []
            if coerceBool(component["showStars"]) == true { fields.append("stars") }
            if coerceBool(component["showForks"]) == true { fields.append("forks") }
            if coerceBool(component["showIssues"]) == true { fields.append("issues") }
            if coerceBool(component["showWatchers"]) == true { fields.append("watchers") }
            if coerceBool(component["showDescription"]) == true { fields.append("description") }
            if !fields.isEmpty {
                component["showComponents"] = fields
            }
        }
    }

    private func fillRequiredDefaults(component: inout [String: Any], type: String) {
        switch type {
        case "text":
            component["content"] = nonEmptyString(component["content"]) ?? "Widget"
            if component["font"] == nil { component["font"] = "sf-pro" }
            if component["size"] == nil { component["size"] = 14 }
            if component["color"] == nil { component["color"] = "primary" }

        case "icon":
            component["name"] = nonEmptyString(component["name"]) ?? "sparkles"

        case "clock":
            component["format"] = nonEmptyString(component["format"]) ?? "HH:mm"
            component["timezone"] = sanitizeTimezone(component["timezone"])

        case "analog_clock":
            component["timezone"] = sanitizeTimezone(component["timezone"])

        case "date":
            component["format"] = nonEmptyString(component["format"]) ?? "EEEE, MMM d"
            component["timezone"] = sanitizeTimezone(component["timezone"])

        case "countdown":
            component["targetDate"] = sanitizeISO8601(component["targetDate"]) ?? defaultCountdownTargetDate()

        case "timer":
            component["duration"] = max(1, coerceInt(component["duration"]) ?? 60)

        case "world_clocks":
            let clocks = sanitizeWorldClocks(component["clocks"])
            component["clocks"] = clocks.isEmpty ? [["timezone": "local", "label": "Local"]] : clocks

        case "pomodoro":
            component["workDuration"] = max(1, coerceInt(component["workDuration"]) ?? 1500)
            component["breakDuration"] = max(1, coerceInt(component["breakDuration"]) ?? 300)
            component["longBreakDuration"] = max(1, coerceInt(component["longBreakDuration"]) ?? 900)
            component["sessionsBeforeLongBreak"] = max(1, coerceInt(component["sessionsBeforeLongBreak"]) ?? 4)

        case "day_progress":
            let start = coerceInt(component["startHour"]) ?? 8
            let end = coerceInt(component["endHour"]) ?? 23
            component["startHour"] = min(max(start, 0), 23)
            component["endHour"] = min(max(end, (component["startHour"] as? Int ?? 8) + 1), 24)

        case "weather":
            component["location"] = nonEmptyString(component["location"]) ?? "Current Location"

        case "stock":
            component["symbol"] = canonicalStockSymbol(nonEmptyString(component["symbol"]) ?? "AAPL")

        case "crypto":
            component["symbol"] = canonicalCryptoSymbol(nonEmptyString(component["symbol"]) ?? "BTC")
            component["currency"] = nonEmptyString(component["currency"]) ?? "USD"

        case "calendar_next":
            component["maxEvents"] = max(1, coerceInt(component["maxEvents"]) ?? 3)

        case "reminders":
            component["maxItems"] = max(1, coerceInt(component["maxItems"]) ?? 5)

        case "battery":
            let threshold = coerceDouble(component["lowThreshold"]) ?? 20
            component["lowThreshold"] = min(max(threshold, 0), 100)

        case "news_headlines":
            if let feedURL = nonEmptyString(component["feedUrl"]),
               URL(string: feedURL) != nil {
                component["feedUrl"] = feedURL
            } else {
                component.removeValue(forKey: "feedUrl")
            }

        case "screen_time":
            component["maxApps"] = max(1, coerceInt(component["maxApps"]) ?? 3)

        case "checklist":
            let items = sanitizeChecklistItems(component["items"])
            component["items"] = items.isEmpty
                ? [["id": "item1", "text": "New item", "checked": false]]
                : items

        case "habit_tracker":
            let habits = sanitizeHabits(component["habits"])
            component["habits"] = habits.isEmpty
                ? [["id": "habit1", "name": "Habit", "target": 1, "unit": "times"]]
                : habits

        case "quote":
            if normalizedToken(component["source"]) == "custom" {
                let custom = coerceStringArray(component["customQuotes"]) ?? []
                component["customQuotes"] = custom.isEmpty ? ["Keep going."] : custom
            }

        case "note":
            let isEditable = coerceBool(component["editable"]) == true
            if !isEditable {
                component["content"] = nonEmptyString(component["content"]) ?? "Note"
            } else if component["content"] == nil {
                component["content"] = ""
            }

        case "shortcut_launcher":
            let shortcuts = sanitizeShortcuts(component["shortcuts"])
            component["shortcuts"] = shortcuts.isEmpty
                ? [["name": "Terminal", "icon": "terminal.fill", "action": "open:com.apple.Terminal"]]
                : shortcuts

        case "link_bookmarks":
            let links = sanitizeLinks(component["links"])
            component["links"] = links.isEmpty
                ? [["name": "GitHub", "url": "https://github.com", "icon": "link"]]
                : links

        case "github_repo_stats":
            let source = nonEmptyString(component["source"]) ?? "apple/swift"
            component["source"] = sanitizeGitHubSource(source)
            if let fields = coerceStringArray(component["showComponents"]) {
                let allowed = Set(["stars", "forks", "issues", "watchers", "description"])
                let normalized = fields.map { $0.lowercased() }.filter { allowed.contains($0) }
                if normalized.isEmpty {
                    component.removeValue(forKey: "showComponents")
                } else {
                    component["showComponents"] = normalized
                }
            }

        case "progress_ring", "progress_bar":
            component["source"] = nonEmptyString(component["source"]) ?? "placeholder.value"
            if type == "progress_ring" {
                component["lineWidth"] = max(1, coerceDouble(component["lineWidth"]) ?? 6)
            } else {
                component["height"] = max(1, coerceDouble(component["height"]) ?? 6)
            }

        case "chart":
            component["source"] = nonEmptyString(component["source"]) ?? "stocks.AAPL.history7d"

        case "vstack", "hstack":
            let children = coerceComponentArray(component["children"]) ?? []
            if children.isEmpty {
                component["children"] = [defaultTextComponent("Widget")]
            }

        case "container":
            if component["child"] == nil {
                if let children = coerceComponentArray(component["children"]), let first = children.first {
                    component["child"] = first
                } else {
                    component["child"] = defaultTextComponent("Widget")
                }
            }

        default:
            break
        }

        if type == "vstack" || type == "hstack" {
            if let children = component["children"] as? [[String: Any]] {
                var normalized: [[String: Any]] = []
                for child in children {
                    var mutableChild = child
                    normalizeComponentDictionary(&mutableChild)
                    normalized.append(mutableChild)
                }
                component["children"] = normalized.isEmpty ? [defaultTextComponent("Widget")] : normalized
            }
        }

        if type == "container", let child = component["child"] as? [String: Any] {
            var normalizedChild = child
            normalizeComponentDictionary(&normalizedChild)
            component["child"] = normalizedChild
        }
    }

    private func sanitizeWorldClocks(_ raw: Any?) -> [[String: Any]] {
        guard let rawArray = raw as? [Any] else {
            return []
        }

        var result: [[String: Any]] = []
        for item in rawArray {
            guard let dictionary = item as? [String: Any] else {
                continue
            }
            let timezone = sanitizeTimezone(dictionary["timezone"])
            var entry: [String: Any] = ["timezone": timezone]
            if let label = nonEmptyString(dictionary["label"]) {
                entry["label"] = label
            }
            result.append(entry)
        }
        return result
    }

    private func sanitizeChecklistItems(_ raw: Any?) -> [[String: Any]] {
        guard let rawArray = raw as? [Any] else {
            return []
        }

        var result: [[String: Any]] = []
        for (index, item) in rawArray.enumerated() {
            guard let dictionary = item as? [String: Any] else {
                continue
            }
            let id = nonEmptyString(dictionary["id"]) ?? "item\(index + 1)"
            let text = nonEmptyString(dictionary["text"]) ?? "Item \(index + 1)"
            let checked = coerceBool(dictionary["checked"]) ?? false
            result.append(["id": id, "text": text, "checked": checked])
        }
        return result
    }

    private func sanitizeHabits(_ raw: Any?) -> [[String: Any]] {
        guard let rawArray = raw as? [Any] else {
            return []
        }

        var result: [[String: Any]] = []
        for (index, item) in rawArray.enumerated() {
            guard let dictionary = item as? [String: Any] else {
                continue
            }
            let id = nonEmptyString(dictionary["id"]) ?? "habit\(index + 1)"
            let name = nonEmptyString(dictionary["name"]) ?? "Habit \(index + 1)"
            let target = max(1, coerceInt(dictionary["target"]) ?? 1)

            var entry: [String: Any] = [
                "id": id,
                "name": name,
                "target": target
            ]
            if let icon = nonEmptyString(dictionary["icon"]) {
                entry["icon"] = icon
            }
            if let unit = nonEmptyString(dictionary["unit"]) {
                entry["unit"] = unit
            }
            result.append(entry)
        }
        return result
    }

    private func sanitizeShortcuts(_ raw: Any?) -> [[String: Any]] {
        guard let rawArray = raw as? [Any] else {
            return []
        }

        var result: [[String: Any]] = []
        for item in rawArray {
            guard let dictionary = item as? [String: Any] else {
                continue
            }
            guard let name = nonEmptyString(dictionary["name"]),
                  let action = nonEmptyString(dictionary["action"]) else {
                continue
            }
            var entry: [String: Any] = ["name": name, "action": action]
            if let icon = nonEmptyString(dictionary["icon"]) {
                entry["icon"] = icon
            }
            result.append(entry)
        }
        return result
    }

    private func sanitizeLinks(_ raw: Any?) -> [[String: Any]] {
        guard let rawArray = raw as? [Any] else {
            return []
        }

        var result: [[String: Any]] = []
        for item in rawArray {
            guard let dictionary = item as? [String: Any] else {
                continue
            }
            guard let name = nonEmptyString(dictionary["name"]) else {
                continue
            }
            var url = nonEmptyString(dictionary["url"]) ?? ""
            if !url.isEmpty, URL(string: url) == nil, !url.contains("://") {
                url = "https://\(url)"
            }
            guard !url.isEmpty, URL(string: url) != nil else {
                continue
            }
            var entry: [String: Any] = ["name": name, "url": url]
            if let icon = nonEmptyString(dictionary["icon"]) {
                entry["icon"] = icon
            }
            result.append(entry)
        }
        return result
    }

    private func coerceComponentArray(_ raw: Any?) -> [[String: Any]]? {
        if let array = raw as? [[String: Any]] {
            return array
        }
        if let array = raw as? [Any] {
            let mapped = array.compactMap { $0 as? [String: Any] }
            return mapped.isEmpty ? nil : mapped
        }
        if let dictionary = raw as? [String: Any] {
            return [dictionary]
        }
        return nil
    }

    private func canonicalComponentType(_ raw: String) -> String? {
        let normalized = normalizedToken(raw) ?? ""
        guard !normalized.isEmpty else { return nil }

        if let alias = componentTypeAliases[normalized] {
            return alias
        }

        if allowedComponentTypes.contains(normalized) {
            return normalized
        }

        if normalized.hasSuffix("s") {
            let singular = String(normalized.dropLast())
            if allowedComponentTypes.contains(singular) {
                return singular
            }
        }

        let closest = orderedComponentTypes
            .map { ($0, editDistance(normalized, $0)) }
            .min { lhs, rhs in lhs.1 < rhs.1 }

        // Keep auto-repair conservative to avoid mapping unrelated layout words (e.g. "grid")
        // to unrelated atomic components (e.g. "icon").
        if let closest, closest.1 <= 2 {
            return closest.0
        }

        return nil
    }

    private func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)

        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var costs = Array(0...b.count)
        for i in 1...a.count {
            var previous = costs[0]
            costs[0] = i
            for j in 1...b.count {
                let current = costs[j]
                let substitutionCost = (a[i - 1] == b[j - 1]) ? 0 : 1
                costs[j] = min(
                    costs[j] + 1,
                    costs[j - 1] + 1,
                    previous + substitutionCost
                )
                previous = current
            }
        }
        return costs[b.count]
    }

    private func defaultCountdownTargetDate() -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(86_400))
    }

    private func sanitizeISO8601(_ raw: Any?) -> String? {
        guard let text = nonEmptyString(raw) else {
            return nil
        }
        return ISO8601DateFormatter().date(from: text) == nil ? nil : text
    }

    private func sanitizeGitHubSource(_ raw: String) -> String {
        let trailingPunct = CharacterSet(charactersIn: ".,;:!?)\"'")
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: trailingPunct)

        if let parsed = URL(string: trimmed),
           let host = parsed.host?.lowercased(),
           host.contains("github.com") {
            let parts = parsed.pathComponents
                .filter { $0 != "/" }
                .map { $0.trimmingCharacters(in: trailingPunct) }
            if parts.count >= 2 {
                let owner = parts[0]
                var repo = parts[1]
                if repo.hasSuffix(".git") {
                    repo = String(repo.dropLast(4))
                }
                if !owner.isEmpty, !repo.isEmpty {
                    return "\(owner)/\(repo)"
                }
            }
        }

        return trimmed
    }

    private func sanitizeTimezone(_ raw: Any?) -> String {
        guard let timezone = nonEmptyString(raw) else {
            return "local"
        }
        if timezone.lowercased() == "local" {
            return "local"
        }
        return TimeZone(identifier: timezone) == nil ? "local" : timezone
    }

    private func defaultTextComponent(_ text: String) -> [String: Any] {
        [
            "type": "text",
            "content": text,
            "font": "sf-pro",
            "size": 14,
            "color": "primary"
        ]
    }

    private func filterDictionary(_ dictionary: [String: Any], allowedKeys: Set<String>) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dictionary where allowedKeys.contains(key) {
            result[key] = value
        }
        return result
    }

    private func nonEmptyString(_ raw: Any?) -> String? {
        guard let value = coerceString(raw) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedToken(_ raw: Any?) -> String? {
        guard let string = coerceString(raw) else {
            return nil
        }
        let normalized = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return normalized.isEmpty ? nil : normalized
    }

    private func coerceString(_ raw: Any?) -> String? {
        switch raw {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        case let value as Int:
            return String(value)
        case let value as Double:
            return String(value)
        case let value as Bool:
            return value ? "true" : "false"
        default:
            return nil
        }
    }

    private func coerceDouble(_ raw: Any?) -> Double? {
        switch raw {
        case let value as Double:
            return value
        case let value as Float:
            return Double(value)
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private func coerceInt(_ raw: Any?) -> Int? {
        switch raw {
        case let value as Int:
            return value
        case let value as Double:
            return Int(value)
        case let value as Float:
            return Int(value)
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let integer = Int(trimmed) {
                return integer
            }
            if let double = Double(trimmed) {
                return Int(double)
            }
            return nil
        default:
            return nil
        }
    }

    private func coerceBool(_ raw: Any?) -> Bool? {
        switch raw {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as String:
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "yes", "1", "on"].contains(normalized) {
                return true
            }
            if ["false", "no", "0", "off"].contains(normalized) {
                return false
            }
            return nil
        default:
            return nil
        }
    }

    private func coerceStringArray(_ raw: Any?) -> [String]? {
        if let array = raw as? [String] {
            return array.compactMap { nonEmptyString($0) }
        }
        if let array = raw as? [Any] {
            let mapped = array.compactMap { nonEmptyString($0) }
            return mapped.isEmpty ? nil : mapped
        }
        if let single = nonEmptyString(raw) {
            return [single]
        }
        return nil
    }

    private func extractJSONObjectCandidates(from rawResponse: String) -> [String] {
        let trimmed = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutCodeFence = stripMarkdownCodeFence(from: trimmed)
        let withoutComments = removeJSONComments(from: withoutCodeFence)

        var candidates = balancedJSONObjectCandidates(in: withoutComments)
        if candidates.isEmpty {
            if let firstBrace = withoutComments.firstIndex(of: "{") {
                candidates.append(String(withoutComments[firstBrace...]))
            }
            if let firstBrace = withoutComments.firstIndex(of: "{"),
               let lastBrace = withoutComments.lastIndex(of: "}"),
               firstBrace <= lastBrace {
                candidates.append(String(withoutComments[firstBrace...lastBrace]))
            }
        }

        if candidates.isEmpty {
            candidates.append(withoutComments)
        }

        var seen = Set<String>()
        candidates = candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }

        return candidates.sorted { $0.count > $1.count }
    }

    private func balancedJSONObjectCandidates(in text: String) -> [String] {
        var candidates: [String] = []
        var startIndex: String.Index?
        var depth = 0
        var inString = false
        var escaped = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    if depth == 0 {
                        startIndex = index
                    }
                    depth += 1
                } else if character == "}" {
                    guard depth > 0 else {
                        index = text.index(after: index)
                        continue
                    }
                    depth -= 1
                    if depth == 0, let start = startIndex {
                        candidates.append(String(text[start...index]))
                        startIndex = nil
                    }
                }
            }

            index = text.index(after: index)
        }

        return candidates
    }

    private func cleanupVariants(for candidate: String) -> [String] {
        let base = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        var variants: [String] = []
        var seen = Set<String>()

        func add(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if seen.insert(trimmed).inserted {
                variants.append(trimmed)
            }
        }

        let commaFixed = removeTrailingCommas(in: base)
        let keyQuoted = quoteUnquotedKeys(in: commaFixed)
        let singleQuoted = replaceSingleQuotedStrings(in: keyQuoted)
        let autoClosedBase = autoCloseJSONDelimiters(in: base)
        let autoClosedComma = autoCloseJSONDelimiters(in: commaFixed)
        let autoClosedQuoted = autoCloseJSONDelimiters(in: keyQuoted)
        let autoClosedSingleQuoted = autoCloseJSONDelimiters(in: singleQuoted)

        add(base)
        add(trimToOuterBraces(base))
        add(commaFixed)
        add(trimToOuterBraces(commaFixed))
        add(keyQuoted)
        add(trimToOuterBraces(keyQuoted))
        add(singleQuoted)
        add(trimToOuterBraces(singleQuoted))
        add(autoClosedBase)
        add(autoClosedComma)
        add(autoClosedQuoted)
        add(autoClosedSingleQuoted)

        return variants.sorted { $0.count > $1.count }
    }

    private func trimToOuterBraces(_ text: String) -> String {
        guard let firstBrace = text.firstIndex(of: "{") else {
            return text
        }
        guard let lastBrace = text.lastIndex(of: "}") else {
            return String(text[firstBrace...])
        }
        if firstBrace <= lastBrace {
            return String(text[firstBrace...lastBrace])
        }
        return text
    }

    private func removeTrailingCommas(in text: String) -> String {
        text.replacingOccurrences(
            of: ",\\s*([}\\]])",
            with: "$1",
            options: .regularExpression
        )
    }

    private func quoteUnquotedKeys(in text: String) -> String {
        text.replacingOccurrences(
            of: #"([{\[,]\s*)([A-Za-z_][A-Za-z0-9_\-]*)(\s*:)"#,
            with: "$1\"$2\"$3",
            options: .regularExpression
        )
    }

    private func replaceSingleQuotedStrings(in text: String) -> String {
        text.replacingOccurrences(
            of: #"\'([^\'\\]*(?:\\.[^\'\\]*)*)\'"#,
            with: "\"$1\"",
            options: .regularExpression
        )
    }

    private func removeJSONComments(from text: String) -> String {
        var output = ""
        var index = text.startIndex
        var inString = false
        var escaped = false

        while index < text.endIndex {
            let ch = text[index]
            let next = text.index(after: index)

            if inString {
                output.append(ch)
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "\"" {
                    inString = false
                }
                index = next
                continue
            }

            if ch == "\"" {
                inString = true
                output.append(ch)
                index = next
                continue
            }

            if ch == "/", next < text.endIndex {
                let nextChar = text[next]
                if nextChar == "/" {
                    // Skip line comment until newline.
                    index = text.index(after: next)
                    while index < text.endIndex, text[index] != "\n" {
                        index = text.index(after: index)
                    }
                    continue
                }
                if nextChar == "*" {
                    // Skip block comment.
                    index = text.index(after: next)
                    while index < text.endIndex {
                        let c = text[index]
                        let n = text.index(after: index)
                        if c == "*", n < text.endIndex, text[n] == "/" {
                            index = text.index(after: n)
                            break
                        }
                        index = n
                    }
                    continue
                }
            }

            output.append(ch)
            index = next
        }

        return output
    }

    private func autoCloseJSONDelimiters(in text: String) -> String {
        var result = text
        var stack: [Character] = []
        var inString = false
        var escaped = false

        for character in text {
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            if character == "\"" {
                inString = true
            } else if character == "{" {
                stack.append("}")
            } else if character == "[" {
                stack.append("]")
            } else if character == "}" || character == "]" {
                if let expected = stack.last, expected == character {
                    _ = stack.popLast()
                }
            }
        }

        while let closer = stack.popLast() {
            result.append(closer)
        }

        return result
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

    private func isValidColorToken(_ token: String) -> Bool {
        let lower = token.lowercased()
        if semanticColors.contains(lower) {
            return true
        }
        if lower.hasPrefix("#") {
            let range = NSRange(location: 0, length: token.utf16.count)
            return colorRegex?.firstMatch(in: token, options: [], range: range) != nil
        }
        return false
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
            // Editable notes may start empty — the user will type their own content.
            if component.editable != true {
                guard let content = component.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AIWidgetServiceError.schemaValidationFailed("note.content is required at \(path).")
                }
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

        case .fileClipboard:
            break

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

        case .githubRepoStats:
            guard let source = component.source, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("github_repo_stats.source (owner/repo) is required at \(path).")
            }

        case .periodTracker, .moodTracker, .breathingExercise, .virtualPet:
            break

        case .dailyQuote, .joke, .nasaApod, .wordOfDay, .trendingMovies:
            break

        case .exchangeRate:
            guard let currency = component.currency, !currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIWidgetServiceError.schemaValidationFailed("exchange_rate.currency (base) is required at \(path).")
            }

        case .sportsScores:
            break

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

    private func canonicalStockSymbol(_ raw: String) -> String {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        switch normalized {
        case "GOLD", "XAU", "XAUUSD", "XAUUSD=X", "GC", "GC=F":
            return "GLD"
        case "SILVER", "XAG", "XAGUSD", "XAGUSD=X", "SI", "SI=F":
            return "SLV"
        case "BITCOIN":
            return "BTC"
        case "ETHEREUM":
            return "ETH"
        default:
            return normalized
        }
    }

    private func canonicalCryptoSymbol(_ raw: String) -> String {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        switch normalized {
        case "BITCOIN":
            return "BTC"
        case "ETHEREUM":
            return "ETH"
        case "DOGECOIN":
            return "DOGE"
        case "SOLANA":
            return "SOL"
        case "CARDANO":
            return "ADA"
        case "RIPPLE":
            return "XRP"
        default:
            return normalized
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(let context):
            return "Decoding failed at \(codingPathString(context.codingPath)): \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "Missing required key '\(key.stringValue)' at \(codingPathString(context.codingPath))."
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(codingPathString(context.codingPath)): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Missing value for \(type) at \(codingPathString(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding failure."
        }
    }

    private static func codingPathString(_ path: [CodingKey]) -> String {
        guard !path.isEmpty else {
            return "root"
        }

        return path
            .map { key in
                if let intValue = key.intValue {
                    return "[\(intValue)]"
                }
                return key.stringValue
            }
            .joined(separator: ".")
    }
}
