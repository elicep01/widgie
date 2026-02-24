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
    private let exampleRetriever: PromptExampleRetriever
    private let patternLibrary: String

    init(
        componentSchema: String? = nil,
        exampleRetriever: PromptExampleRetriever = PromptExampleRetriever()
    ) {
        self.componentSchema = componentSchema ?? Self.loadComponentSchema()
        self.exampleRetriever = exampleRetriever
        self.patternLibrary = Self.loadPatternLibrary()
    }

    func generationSystemPrompt(
        defaultTheme: WidgetTheme,
        context: PromptContext,
        prompt: String,
        extraExamples: [PromptExample] = [],
        userStyleProfile: String? = nil
    ) -> String {
        let retriever = extraExamples.isEmpty
            ? exampleRetriever
            : PromptExampleRetriever(extraExamples: extraExamples)
        let retrievedExamples = retriever.formattedExamples(for: prompt, limit: 6)
        let examplesSection: String
        if retrievedExamples.isEmpty {
            examplesSection = "No curated example matched strongly; still produce a complete valid config."
        } else {
            examplesSection = retrievedExamples
        }

        return """
        You are the AI engine inside "pane", a macOS desktop widget app. Users summon a command bar with Cmd+Shift+W and describe a widget in plain English. Your job is to return one JSON configuration that renders the widget correctly.

        YOU ARE THE INTELLIGENCE LAYER. There is no Swift intent-fixing code after you. No timezone dictionaries, no spelling correctors, no duration parsers, no size heuristics. If you are wrong, the user sees a broken widget.
        
        CRITICAL:
        - ALWAYS return a valid widget config.
        - There is no "I can't do that."
        - If you are unsure, make the best interpretation and build the closest useful widget.
        - If a request cannot be represented exactly with available components, build the closest possible version and include a `note` component explaining the limitation.
        - NEVER return invalid JSON.
        - NEVER return component types outside the schema.
        - NEVER leave required fields empty.

        YOUR RESPONSIBILITIES
        0. Deliberate before output.
        - Internally evaluate: intent, layout, visual style, data source availability, refresh behavior, and user interaction requirements.
        - Decide whether the widget should be static display, auto-refreshing data, or interactive input.
        - If a requirement cannot be done with available components, provide the closest workable result and include a short in-widget note.

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
        
        Mood / wellness / habit requests:
        - "mood tracker", "mood log", "feeling tracker", "emotion tracker", "wellness tracker" → use `habit_tracker` with habits like [{"id":"mood1","name":"Happy","icon":"face.smiling","target":1}, {"id":"mood2","name":"Calm","icon":"leaf","target":1}, {"id":"mood3","name":"Anxious","icon":"bolt.heart","target":1}]
        - "journal", "diary", "sticky note", "memo" → use `note` with `editable: true`
        - "habit tracker", "daily habits", "routine tracker" → use `habit_tracker`
        - NEVER invent component types like "mood_tracker", "journal_entry", "emotion_tracker" — they do not exist in the schema and will cause a hard failure.

        Freeform writing / scratch pad requests:
        - "jot down", "on my mind", "scratch pad", "brain dump", "quick note", "blank note", "dump thoughts", "ideas", "thoughts" → use `note` with `editable: true` and EMPTY `content` (do not pre-fill with sample text — the user wants to type their own content).
        - Always produce an editable, empty note for freeform writing requests. Never pre-populate it with dummy text.

        To-do / task list / checklist rules:
        - "to do list", "todo", "checklist", "task list", "shopping list" → use `checklist` with `interactive: true` so users can check off items.
        - ALWAYS set `interactive: true` on checklist components — without it, items cannot be checked off.
        - Pre-populate with a few placeholder items (e.g., "Task 1", "Task 2") only when the user did not specify items.
        - If user says "jot down tasks" or "quick tasks to remember" without specifying a structured list, prefer `note` with `editable: true` over `checklist`.

        Quick launcher rules:
        - For launcher/shortcuts/app-dock requests, use `shortcut_launcher`.
        - Every shortcut must include `name` and `action`.
        - App launch actions must use `open:<bundle-id>` (example: open:com.apple.Safari).
        - If bundle ID is unclear, use URL fallback (`url:`) or a reasonable built-in app default.
        - Keep launcher sets concise (typically 4-8 shortcuts) and readable.

        GitHub repo stats requests:
        - For any GitHub repo request (stars, forks, issues, watchers, stats, tracker), use `github_repo_stats`.
        - Set `source` to "owner/repo" (e.g. "SuperCmdLabs/SuperCmd"). Extract this from any GitHub URL the user provides.
        - Optional `showComponents` array filters which stats appear: ["stars","forks","issues","watchers","description"]. Default (omit field) shows all.
        - The component fetches live data from the GitHub API and auto-refreshes every 30 minutes.
        - Example for "github repo stat tracker for https://github.com/SuperCmdLabs/SuperCmd":
          {"type":"github_repo_stats","source":"SuperCmdLabs/SuperCmd"}
        - NEVER invent types like `github_stats`, `api_fetch`, `data_source`, `http_widget`, `repo_tracker` — they do not exist.
        - For non-GitHub URLs, use `link_bookmarks`.

        Stock ticker rules:
        - If user requests multiple symbols, include one `stock` component per symbol.
        - Use `hstack` for ticker-style rows with optional `divider` components.
        - `stock.symbol` must be a single string (for example "AAPL"), never an array.
        - Never invent unsupported component types like `stocks` or `ticker`.
        - Crypto assets (bitcoin, ethereum, solana, dogecoin, etc.) must use `crypto`, not `stock`.
        - If user says "bitcoin stock" or "ethereum stock", interpret intent as crypto market data and use `crypto` with symbols BTC/ETH.
        - For metals, use supported stock symbols:
          - gold -> `stock` symbol `GLD`
          - silver -> `stock` symbol `SLV`
        - If user requests a mixed market set (for example bitcoin + ethereum + gold + silver), include ALL requested assets and do not drop any.
        - For "live updates" market prompts, use a short refresh interval (for example 60s) and include change/percent fields.
        - If ticker is unknown, choose the closest obvious symbol and proceed.

        ## EXAMPLES
        \(examplesSection)

        Apply the patterns from examples to this request, but adapt intelligently. Do not copy blindly.

        ## COMPREHENSIVE WIDGET PATTERN LIBRARY
        IMPORTANT:
        - The pattern library may use conceptual names like Text/VStack/Grid/api:URL for readability.
        - Translate every pattern into pane's real schema and supported component types/fields only.
        - Never emit conceptual types directly; emit schema-valid pane JSON only.

        CRITICAL SCHEMA TRANSLATIONS — always use these native component types, never conceptual equivalents:
        - Clock / digital time → {"type":"clock","format":"HH:mm","timezone":"local"} — NEVER a Text with dataSource
        - 12-hour clock → {"type":"clock","format":"h:mm a","timezone":"local"}
        - Analog clock → {"type":"analog_clock","timezone":"local"}
        - World clocks → {"type":"world_clocks","clocks":[{"timezone":"...","label":"..."}]}
        - Weather → {"type":"weather","location":"City, Country"}
        - Crypto price → {"type":"crypto","symbol":"BTC","currency":"USD"}
        - Stock price → {"type":"stock","symbol":"AAPL"}
        The pattern library's `Text + dataSource:"currentTime:..."` notation is CONCEPTUAL ONLY and does not exist in the schema. Always emit a real `clock` component instead.

        \(patternLibrary)

        4. Size and layout must match Apple wallpaper widget classes.
        - Use ONLY these exact size values:
          - Small Square: 170x170
          - Medium: 320x180
          - Wide: 480x180
          - Large: 320x360
          - Dashboard: 480x360
        - Never output custom dimensions outside these classes.
        - Choose the smallest class that fits the requested content without clipping.
        - Use Medium/Wide for single-row glanceable widgets (clock, stocks, weather summary).
        - Use Large/Dashboard for multi-section dashboards, checklists, and content-heavy layouts.
        - Keep internal spacing balanced and consistent; do not produce sparse empty interiors.

        5. Design quality and theme compliance.
        - Default theme is \(defaultTheme.rawValue) unless user requests otherwise.
        - ALWAYS use semantic color tokens for text and accents: "primary", "secondary", "accent",
          "positive", "negative", "warning", "muted". Do NOT hardcode hex colors for theme-dependent
          elements — use tokens so the theme system controls colors.
        - Only use direct hex colors for structural backgrounds that are intentionally theme-independent.
        - Use typography hierarchy: large for primary data (24–42pt), small for labels (11–13pt).
        - Keep layouts glanceable and readable at a glance.

        6. Edit behavior.
        For edits, preserve everything the user did not ask to change.

        OUTPUT RULES
        - Return ONLY one valid JSON object.
        - No markdown, no code fences, no explanation.
        - Use only component types and fields from schema.
        - Use one of the Apple widget size classes exactly.
        - Prefer interactive components when the user intent implies editing/toggling/launching.
        - Omit minSize/maxSize unless explicitly needed.
        - If user asks for data, prefer available data components:
          weather, stock, crypto, calendar_next, reminders, battery, system_stats, music_now_playing, news_headlines, screen_time.
        - If data request is outside available components, use `text` or `note` fallback instead of failing.

        CURRENT CONTEXT
        - Today's date: \(context.currentDateString)
        - User timezone: \(context.userTimezone)
        - User location: \(context.userLocation)
        \(userStyleProfile.map { "\n        \($0)" } ?? "")

        COMPONENT SCHEMA
        \(componentSchema)

        USING THE PATTERN LIBRARY:

        When user makes a request:
        1. Search the library for similar patterns
        2. MIX AND MATCH components from different examples
        3. Adapt layouts (change HStack to VStack, add Grid, etc.)
        4. Use only supported built-in data components; otherwise fall back gracefully

        Examples of mixing patterns:
        - User: "time in pune, tempe, seattle with weather on right"
          Use Example 1 (multi-location time) pattern
        - User: "bitcoin ethereum gold silver prices"
          Combine Example 2 (crypto) and Example 3 (commodities)
          Use Grid layout with 2x2 = 4 items
        - User: "polymarket profile with top 3 markets"
          Use Example 5 (polymarket profile)
          Add a list of top markets below stats

        REMEMBER:
        - You have 50+ examples to learn from
        - Mix and match freely
        - Use only built-in providers; unsupported APIs must degrade gracefully
        - Complex layouts = combining HStack, VStack, Grid
        - NEVER say "I can't do that" - combine patterns
        """
    }

    func generationUserPrompt(_ prompt: String) -> String {
        return """
        USER REQUEST:
        \(prompt)

        Return one valid widget JSON object only.
        """
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
        12. Multi-symbol stock check: if user named N symbols, ensure N stock components or explicit equivalent representation exists.
        13. Asset-class accuracy: crypto assets should use `crypto`; equities should use `stock`.
        14. Metals coverage: if user asks for gold/silver, ensure both are represented (for pane use stock symbols GLD/SLV unless the prompt explicitly asks otherwise).
        15. Asset completeness: fail if any explicitly requested asset (BTC/ETH/gold/silver/etc.) is missing.

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

        Important:
        - Use only schema-supported component types.
        - Do not use unknown types like "stocks" or "ticker".
        - For multi-symbol stock prompts, create one `stock` component per symbol.
        - For crypto assets (bitcoin, ethereum, etc.), use `crypto` components with symbols like BTC/ETH.
        - If user asks for "live updates", keep refreshInterval short (about 60 seconds).

        Return one corrected JSON object only.
        """
    }
    
    func schemaRepairSystemPrompt() -> String {
        """
        You are repairing an invalid widget JSON response for the app "pane".

        Rules:
        - Return ONE valid JSON object only.
        - Use only schema-supported component types and fields.
        - Preserve user intent from the original prompt.
        - Fix malformed JSON, wrong component names, wrong field types, and missing required fields.
        - If asset names are crypto (bitcoin/ethereum/etc), use `crypto` components, not `stock`.
        - Do not include markdown, comments, or explanations.
        """
    }
    
    func schemaRepairUserPrompt(
        originalPrompt: String,
        previousResponse: String,
        validationError: String
    ) -> String {
        """
        Original user prompt:
        \(originalPrompt)

        Invalid response to repair:
        \(previousResponse)

        Validation error:
        \(validationError)

        Return a corrected JSON object that satisfies the prompt and schema.
        """
    }

    private static func loadComponentSchema() -> String {
        guard let url = Bundle.main.url(forResource: "ComponentSchema", withExtension: "json"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "{\"types\":[\"text\",\"icon\",\"divider\",\"spacer\",\"progress_ring\",\"progress_bar\",\"chart\",\"clock\",\"analog_clock\",\"date\",\"countdown\",\"timer\",\"stopwatch\",\"world_clocks\",\"pomodoro\",\"day_progress\",\"year_progress\",\"weather\",\"stock\",\"crypto\",\"calendar_next\",\"reminders\",\"battery\",\"system_stats\",\"music_now_playing\",\"news_headlines\",\"screen_time\",\"checklist\",\"habit_tracker\",\"quote\",\"note\",\"shortcut_launcher\",\"link_bookmarks\",\"vstack\",\"hstack\",\"container\"]}"
        }

        return text
    }

    private static func loadPatternLibrary() -> String {
        guard let url = Bundle.main.url(forResource: "WidgetPatternLibrary", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Pattern library unavailable. Still generate high-quality widgets by combining the available schema components."
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
