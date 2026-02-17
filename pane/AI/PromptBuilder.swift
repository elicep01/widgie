import Foundation

struct PromptContext {
    let currentDate: Date
    let userTimezone: String
    let userLocation: String

    var currentDateString: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: userTimezone) ?? .current
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: currentDate)
    }
}

struct PromptBuilder {
    private let componentSchema: String

    init(componentSchema: String? = nil) {
        self.componentSchema = componentSchema ?? Self.loadComponentSchema()
    }

    func generationSystemPrompt(defaultTheme: WidgetTheme, context: PromptContext) -> String {
        """
        You are the AI engine inside "pane", a macOS desktop widget app. Users summon a command bar with Cmd+Shift+W and describe a widget in plain English. Your job is to return one JSON configuration that renders the widget correctly.

        YOU ARE THE INTELLIGENCE LAYER. There is no Swift intent-fixing code after you. No timezone dictionaries, no spelling correctors, no duration parsers, no size heuristics. If you are wrong, the user sees a broken widget.

        YOUR RESPONSIBILITIES
        1. Understand intent, not just keywords.
        Users type casually and make typos. Interpret what they mean.
        - "anolog clock greenland" means analog clock with timezone "America/Nuuk"
        - "wether tempe az" means weather for "Tempe, AZ, USA"
        - "2 min timer" means timer duration 120 seconds
        - "clokc with seconds" means clock with showSeconds true

        2. Resolve real-world knowledge yourself.
        - Use correct IANA timezone strings for place-based time requests.
        - If user names city/country/timezone, do not use "local" unless explicitly requested.
        - Resolve locations as full unambiguous strings when possible.
        - Resolve relative dates from current date context.

        3. Duration and unit accuracy.
        - "2 minutes"/"2 min"/"2m" => duration 120
        - "90 seconds"/"1m30s"/"1:30" => duration 90
        - "1 hour" => duration 3600
        - Pomodoro defaults to 1500 only when user asks for pomodoro/focus-cycle behavior.
        - If user asks celsius/°C, use celsius. If user asks fahrenheit/°F, use fahrenheit.
        - If unit not explicit, infer sensibly from location context.

        4. Size widgets to content density.
        Principle: no wasted space.
        - One-line/single-value content should be compact and usually wide (width > height).
        - Do not make square widgets for single-line countdowns/clocks/timers.
        - Lists/dashboards should scale height to item count.
        - Keep padding and spacing balanced but compact.
        - Target high content density: avoid blank/dead areas; choose the tightest comfortable size.
        - If content is a single row, keep height minimal and increase width only as needed.
        - If content has two short rows, use a shallow rectangle rather than a tall card.

        5. Design quality.
        - Default theme is \(defaultTheme.rawValue) unless user requests otherwise.
        - Use typography hierarchy: large for primary data, small for labels/secondary data.
        - Use semantic colors where possible.
        - Keep layouts glanceable and readable.

        6. Edit behavior.
        For edits, preserve everything the user did not ask to change.

        OUTPUT RULES
        - Return ONLY one valid JSON object.
        - No markdown, no code fences, no explanation.
        - Use only component types and fields from schema.
        - Omit minSize/maxSize unless explicitly needed; keep sizing content-driven and tight.

        CURRENT CONTEXT
        - Today's date: \(context.currentDateString)
        - User timezone: \(context.userTimezone)
        - User location: \(context.userLocation)

        COMPONENT SCHEMA
        \(componentSchema)
        """
    }

    func generationUserPrompt(_ prompt: String) -> String {
        prompt
    }

    func editUserPrompt(existingConfig: WidgetConfig, editPrompt: String) -> String {
        let configJSON = Self.encode(existingConfig)
        return """
        The user wants to modify an existing widget.

        Existing widget config:
        \(configJSON)

        User edit request:
        \(editPrompt)

        Return the complete updated widget JSON only.
        Preserve all fields and structure the user did not ask to change.
        """
    }

    func verificationSystemPrompt() -> String {
        """
        You are a QA reviewer for a widget app called "pane". A user asked for a widget and the AI produced a JSON config.

        Check all of the following:
        1. Intent match: all requested components/features are present.
        2. Timezone accuracy: correct IANA timezone for requested place/timezone.
        3. Duration accuracy: timer/countdown durations exactly match request.
        4. Location accuracy: requested places are represented correctly.
        5. Unit accuracy: celsius/fahrenheit and related unit intent are honored.
        6. Size appropriateness: dimensions fit content density; avoid obvious wasted space.
        7. Style match: dark/minimal/neon/light/etc aligns with user request.
        8. Component correctness: requested component types are correct (e.g., analog_clock vs clock).
        9. Typo handling: user typos were interpreted correctly.
        10. Completeness: no obvious missing expected fields/content.
        11. Empty-space check: fail if large areas are blank and size can be reduced without harming readability.

        RESPONSE FORMAT
        - If everything is correct, respond with exactly: PASS
        - If any issue exists, respond with:
          FAIL
          - Issue 1: ...
          - Issue 2: ...
          - Fix 1: ...
          - Fix 2: ...

        Be concrete. Name exact field/value corrections (for example timezone should be "America/Nuuk").
        """
    }

    func verificationUserPrompt(originalPrompt: String, generatedConfig: WidgetConfig) -> String {
        let configJSON = Self.encode(generatedConfig)
        return """
        THE USER ASKED FOR:
        "\(originalPrompt)"

        THE AI GENERATED THIS CONFIG:
        \(configJSON)
        """
    }

    func correctionSystemPrompt() -> String {
        """
        You are fixing a widget configuration for the app "pane". The previous config failed QA review.

        Rules:
        - Fix ONLY the listed issues.
        - Preserve layout, styling, theme, and all correct fields.
        - Apply exact fixes for timezone/duration/location/unit/size/type/completeness issues.
        - Return ONLY the complete corrected JSON object.
        - No markdown and no explanation.
        """
    }

    func correctionUserPrompt(
        originalPrompt: String,
        currentConfig: WidgetConfig,
        verificationIssues: [String]
    ) -> String {
        let configJSON = Self.encode(currentConfig)
        let issuesText = verificationIssues
            .enumerated()
            .map { index, issue in "- \(index + 1). \(issue)" }
            .joined(separator: "\n")

        return """
        ORIGINAL USER REQUEST:
        "\(originalPrompt)"

        CURRENT CONFIG:
        \(configJSON)

        ISSUES IDENTIFIED:
        \(issuesText)

        Return a corrected JSON config that fixes exactly these issues.
        """
    }

    func retryUserPrompt(originalPrompt: String, previousResponse: String, validationError: String) -> String {
        """
        Your previous response was invalid JSON or failed schema validation.

        Original user prompt:
        \(originalPrompt)

        Previous response:
        \(previousResponse)

        Validation error:
        \(validationError)

        Return one corrected JSON object only.
        """
    }

    private static func loadComponentSchema() -> String {
        guard let url = Bundle.main.url(forResource: "ComponentSchema", withExtension: "json"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "{\"types\":[\"text\",\"icon\",\"divider\",\"spacer\",\"progress_ring\",\"progress_bar\",\"chart\",\"clock\",\"analog_clock\",\"date\",\"countdown\",\"timer\",\"stopwatch\",\"world_clocks\",\"pomodoro\",\"day_progress\",\"year_progress\",\"weather\",\"stock\",\"crypto\",\"calendar_next\",\"reminders\",\"battery\",\"system_stats\",\"music_now_playing\",\"news_headlines\",\"screen_time\",\"checklist\",\"habit_tracker\",\"quote\",\"note\",\"shortcut_launcher\",\"link_bookmarks\",\"vstack\",\"hstack\",\"container\"]}"
        }

        return text
    }

    private static func encode(_ config: WidgetConfig) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(config),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return string
    }
}
