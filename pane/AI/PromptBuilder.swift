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

    func generationSystemPrompt(defaultTheme: WidgetTheme, context: PromptContext, prompt: String) -> String {
        let retrievedExamples = exampleRetriever.formattedExamples(for: prompt, limit: 6)
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

        \(patternLibrary)

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
        - If user asks for data, prefer available data components:
          weather, stock, crypto, calendar_next, reminders, battery, system_stats, music_now_playing, news_headlines, screen_time.
        - If data request is outside available components, use `text` or `note` fallback instead of failing.

        CURRENT CONTEXT
        - Today's date: \(context.currentDateString)
        - User timezone: \(context.userTimezone)
        - User location: \(context.userLocation)

        COMPONENT SCHEMA
        \(componentSchema)

        USING THE PATTERN LIBRARY:

        When user makes a request:
        1. Search the library for similar patterns
        2. MIX AND MATCH components from different examples
        3. Adapt layouts (change HStack to VStack, add Grid, etc.)
        4. Use the data source patterns for ANY API

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
        - ANY API can be fetched using the generic pattern
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
