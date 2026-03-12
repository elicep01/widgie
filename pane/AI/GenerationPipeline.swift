import Foundation

struct GenerationPipeline {
    private let promptBuilder: PromptBuilder
    private let validator: SchemaValidator
    private let verificationService: VerificationService
    private let correctionService: CorrectionService
    private let maxTotalCalls = 10
    private let maxGenerationAttempts = 3
    private let maxSchemaRepairAttemptsPerGeneration = 2
    private let callTimeoutSeconds: Double
    private let totalPipelineTimeoutSeconds: Double

    init(
        promptBuilder: PromptBuilder,
        validator: SchemaValidator,
        callTimeoutSeconds: Double = 30.0,
        totalPipelineTimeoutSeconds: Double = 60.0
    ) {
        self.promptBuilder = promptBuilder
        self.validator = validator
        self.verificationService = VerificationService(promptBuilder: promptBuilder)
        self.correctionService = CorrectionService(promptBuilder: promptBuilder, validator: validator)
        self.callTimeoutSeconds = callTimeoutSeconds
        self.totalPipelineTimeoutSeconds = totalPipelineTimeoutSeconds
    }

    func generate(
        prompt: String,
        defaultTheme: WidgetTheme,
        context: PromptContext,
        generationClient: AIProviderClient,
        verificationClient: AIProviderClient? = nil,
        extraExamples: [PromptExample] = [],
        userStyleProfile: String? = nil
    ) async throws -> WidgetConfig {
        // Fast path: GitHub repo URLs bypass the AI entirely so the AI can't invent
        // placeholder syntax like {{dynamic.github.stars}}.
        let lowerPrompt = prompt.lowercased()
        if lowerPrompt.contains("github.com"),
           let earlyHeuristic = heuristicWidget(for: prompt, theme: defaultTheme, context: context) {
            var widget = earlyHeuristic
            if widget.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                widget.description = prompt
            }
            return widget
        }

        let systemPrompt = promptBuilder.generationSystemPrompt(defaultTheme: defaultTheme, context: context, prompt: prompt, extraExamples: extraExamples, userStyleProfile: userStyleProfile)
        let userPrompt = promptBuilder.generationUserPrompt(prompt)

        var config = try await runPipeline(
            originalPrompt: prompt,
            generationSystemPrompt: systemPrompt,
            initialGenerationUserPrompt: userPrompt,
            generationClient: generationClient,
            verificationClient: verificationClient ?? generationClient,
            context: context,
            fallbackTheme: defaultTheme,
            allowFallbackWidget: true
        )

        if config.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            config.description = prompt
        }

        applyPromptPreferences(to: &config, prompt: prompt)
        ensureMinimumPadding(&config)
        ensureSizeFitsContent(&config)

        return config
    }

    func edit(
        existingConfig: WidgetConfig,
        editPrompt: String,
        defaultTheme: WidgetTheme,
        context: PromptContext,
        generationClient: AIProviderClient,
        verificationClient: AIProviderClient? = nil,
        extraExamples: [PromptExample] = [],
        userStyleProfile: String? = nil,
        conversationHistory: [String] = []
    ) async throws -> WidgetConfig {
        let systemPrompt = promptBuilder.generationSystemPrompt(defaultTheme: defaultTheme, context: context, prompt: editPrompt, extraExamples: extraExamples, userStyleProfile: userStyleProfile)
        let userPrompt = promptBuilder.editUserPrompt(existingConfig: existingConfig, editPrompt: editPrompt, conversationHistory: conversationHistory)

        var config = try await runPipeline(
            originalPrompt: editPrompt,
            generationSystemPrompt: systemPrompt,
            initialGenerationUserPrompt: userPrompt,
            generationClient: generationClient,
            verificationClient: verificationClient ?? generationClient,
            context: context,
            fallbackTheme: defaultTheme,
            allowFallbackWidget: true
        )

        config.id = existingConfig.id
        if config.position == nil {
            config.position = existingConfig.position
        }
        if config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            config.name = existingConfig.name
        }
        if config.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            config.description = existingConfig.description
        }

        // Preserve user-set component properties that the AI may have dropped
        // during regeneration (e.g., temperatureUnit, startHour, location, etc.)
        preserveUserProperties(from: existingConfig.content, into: config.content)

        applyPromptPreferences(to: &config, prompt: editPrompt)

        return config
    }

    private func runPipeline(
        originalPrompt: String,
        generationSystemPrompt: String,
        initialGenerationUserPrompt: String,
        generationClient: AIProviderClient,
        verificationClient: AIProviderClient,
        context: PromptContext,
        fallbackTheme: WidgetTheme,
        allowFallbackWidget: Bool
    ) async throws -> WidgetConfig {
        let deadline = Date().addingTimeInterval(totalPipelineTimeoutSeconds)
        var usedCalls = 0
        var generationUserPrompt = initialGenerationUserPrompt
        var generatedConfig: WidgetConfig?
        var lastGenerationResponse = ""
        var lastGenerationError: Error?

        for attempt in 0..<maxGenerationAttempts {
            guard usedCalls < maxTotalCalls, generatedConfig == nil else {
                break
            }

            do {
                usedCalls += 1
                let generationResponse = try await withTimeout(seconds: remainingSeconds(until: deadline)) {
                    try await generationClient.generateJSON(
                        systemPrompt: generationSystemPrompt,
                        userPrompt: generationUserPrompt
                    )
                }
                lastGenerationResponse = generationResponse

                do {
                    let parsed = try validator.parseAndValidateWidgetConfig(from: generationResponse)
                    if isLowQualityGeneratedConfig(parsed, prompt: originalPrompt) {
                        throw AIWidgetServiceError.schemaValidationFailed(
                            "Generated config was a generic placeholder and did not satisfy prompt intent."
                        )
                    }
                    generatedConfig = parsed
                } catch {
                    lastGenerationError = error

                    for _ in 0..<maxSchemaRepairAttemptsPerGeneration {
                        guard usedCalls < maxTotalCalls else {
                            break
                        }

                        usedCalls += 1
                        let repairResponse = try await withTimeout(seconds: remainingSeconds(until: deadline)) {
                            try await generationClient.generateJSON(
                                systemPrompt: promptBuilder.schemaRepairSystemPrompt(),
                                userPrompt: promptBuilder.schemaRepairUserPrompt(
                                    originalPrompt: originalPrompt,
                                    previousResponse: lastGenerationResponse,
                                    validationError: lastGenerationError?.localizedDescription ?? "Unknown schema validation failure."
                                )
                            )
                        }
                        lastGenerationResponse = repairResponse

                        do {
                            let repaired = try validator.parseAndValidateWidgetConfig(from: repairResponse)
                            if isLowQualityGeneratedConfig(repaired, prompt: originalPrompt) {
                                throw AIWidgetServiceError.schemaValidationFailed(
                                    "Schema repair produced generic placeholder output."
                                )
                            }
                            generatedConfig = repaired
                            break
                        } catch {
                            lastGenerationError = error
                        }
                    }
                }
            } catch {
                lastGenerationError = error
            }

            if generatedConfig != nil {
                break
            }

            if attempt < maxGenerationAttempts - 1, !lastGenerationResponse.isEmpty {
                generationUserPrompt = promptBuilder.retryUserPrompt(
                    originalPrompt: originalPrompt,
                    previousResponse: lastGenerationResponse,
                    validationError: lastGenerationError?.localizedDescription ?? "Unknown generation failure."
                )
            } else {
                generationUserPrompt = initialGenerationUserPrompt
            }
        }

        guard var config = generatedConfig else {
            // Always try to produce a functional widget — never return empty-handed
            if allowFallbackWidget {
                if let heuristic = heuristicWidget(
                    for: originalPrompt,
                    theme: fallbackTheme,
                    context: context
                ) {
                    return heuristic
                }
                return fallbackWidget(
                    for: originalPrompt,
                    theme: fallbackTheme,
                    error: lastGenerationError
                )
            }
            if let lastGenerationError {
                throw lastGenerationError
            }
            throw AIWidgetServiceError.requestFailed("Generation failed without producing a valid config.")
        }

        guard usedCalls < maxTotalCalls else {
            return config
        }

        usedCalls += 1
        let verificationResult: VerificationResult
        do {
            verificationResult = try await withTimeout(seconds: remainingSeconds(until: deadline)) {
                try await verificationService.verify(
                    originalPrompt: originalPrompt,
                    generatedConfig: config,
                    client: verificationClient
                )
            }
        } catch {
            // Verification is best-effort; return usable output instead of failing UX.
            return config
        }

        if verificationResult.passed {
            return config
        }

        guard usedCalls < maxTotalCalls else {
            return config
        }

        usedCalls += 1
        do {
            config = try await withTimeout(seconds: remainingSeconds(until: deadline)) {
                try await correctionService.correct(
                    originalPrompt: originalPrompt,
                    currentConfig: config,
                    verificationIssues: verificationResult.issues,
                    client: generationClient
                )
            }
        } catch {
            // Correction is best-effort; preserve already-usable widget.
            return config
        }

        if allowFallbackWidget,
           isLowQualityGeneratedConfig(config, prompt: originalPrompt),
           let heuristic = heuristicWidget(for: originalPrompt, theme: fallbackTheme, context: context) {
            return heuristic
        }

        return config
    }

    private func remainingSeconds(until deadline: Date) throws -> Double {
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else {
            throw AIWidgetServiceError.requestFailed("Timed out after \(Int(totalPipelineTimeoutSeconds))s")
        }
        return min(callTimeoutSeconds, remaining)
    }

    private func isTimeoutFailure(_ error: Error?) -> Bool {
        guard let error else {
            return false
        }

        if let urlError = error as? URLError, urlError.code == .timedOut {
            return true
        }

        if let serviceError = error as? AIWidgetServiceError,
           case .requestFailed(let message) = serviceError {
            let lower = message.lowercased()
            return lower.contains("timed out")
                || lower.contains("request timed out")
                || lower.contains("code=-1001")
        }

        let lower = error.localizedDescription.lowercased()
        return lower.contains("timed out")
            || lower.contains("request timed out")
            || lower.contains("code=-1001")
    }

    private func withTimeout<T>(
        seconds: Double,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                let nanoseconds = UInt64(seconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw AIWidgetServiceError.requestFailed("Timed out after \(Int(seconds))s")
            }

            guard let result = try await group.next() else {
                throw AIWidgetServiceError.requestFailed("Timed out")
            }

            group.cancelAll()
            return result
        }
    }

    private func fallbackWidget(
        for prompt: String,
        theme: WidgetTheme,
        error: Error?
    ) -> WidgetConfig {
        // Last resort: build the closest functional widget we can.
        // Extract meaningful content from the prompt to populate the widget.
        let lower = prompt.lowercased()

        // If the prompt mentions any data type, build a minimal but FUNCTIONAL widget
        // that actually fetches and displays real data.

        // Multi-component: try to combine the most obvious elements
        let wantsWeather = lower.contains("weather") || lower.contains("temperature") || lower.contains("forecast")
        let wantsClock = lower.contains("clock") || lower.contains("time")
        let wantsDate = lower.contains("date")

        if wantsWeather || wantsClock || wantsDate {
            var children: [ComponentConfig] = []

            if wantsClock || wantsDate {
                let clock = ComponentConfig(type: .clock)
                clock.timezone = "local"
                clock.format = lower.contains("12") ? "h:mm a" : "HH:mm"
                clock.font = "sf-mono"
                clock.size = 32
                clock.weight = .light
                clock.color = "primary"
                children.append(clock)
            }

            if wantsDate || (!wantsClock && !wantsWeather) {
                let date = ComponentConfig(
                    type: .text,
                    content: "{date}",
                    font: "sf-pro",
                    size: 12,
                    color: "secondary"
                )
                children.append(date)
            }

            if wantsWeather {
                let location = heuristicExtractCity(from: lower) ?? "New York"
                let weather = ComponentConfig(type: .weather)
                weather.location = location
                weather.temperatureUnit = explicitTemperatureUnit(in: lower) ?? "fahrenheit"
                children.append(weather)
            }

            let root = ComponentConfig(
                type: .vstack,
                alignment: "leading",
                spacing: 8,
                children: children
            )
            return WidgetConfig(
                name: wantsWeather ? "Weather" : "Clock",
                description: prompt,
                size: WidgetSize(width: 300, height: CGFloat(80 + children.count * 60)),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 300,
                content: root
            )
        }

        // Generic: editable note seeded with the user's intent so they can refine
        let note = ComponentConfig(type: .note)
        note.content = ""
        note.editable = true
        note.color = "primary"

        let title = ComponentConfig(
            type: .text,
            content: titleFromPrompt(prompt),
            font: "sf-pro",
            size: 14,
            weight: .semibold,
            color: "primary"
        )

        let hint = ComponentConfig(
            type: .text,
            content: "Edit this widget to refine it",
            font: "sf-pro",
            size: 11,
            color: "muted"
        )

        let root = ComponentConfig(
            type: .vstack,
            alignment: "leading",
            spacing: 8,
            children: [title, note, hint]
        )

        return WidgetConfig(
            name: titleFromPrompt(prompt),
            description: prompt,
            size: WidgetSize(width: 300, height: 190),
            minSize: nil,
            maxSize: nil,
            theme: theme,
            background: BackgroundConfig.default(for: theme),
            cornerRadius: 20,
            padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
            refreshInterval: 60,
            content: root
        )
    }

    /// Derive a reasonable widget title from the user's prompt
    private func titleFromPrompt(_ prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("weather") { return "Weather" }
        if lower.contains("clock") || lower.contains("time") { return "Clock" }
        if lower.contains("stock") { return "Stock" }
        if lower.contains("crypto") || lower.contains("bitcoin") { return "Crypto" }
        if lower.contains("calendar") || lower.contains("event") { return "Calendar" }
        if lower.contains("reminder") { return "Reminders" }
        if lower.contains("note") || lower.contains("memo") { return "Note" }
        if lower.contains("checklist") || lower.contains("todo") { return "Checklist" }
        if lower.contains("news") || lower.contains("headline") { return "News" }
        if lower.contains("music") || lower.contains("playing") { return "Now Playing" }
        if lower.contains("battery") { return "Battery" }
        if lower.contains("quote") { return "Quote" }
        if lower.contains("pomodoro") { return "Pomodoro" }
        if lower.contains("pet") { return "Virtual Pet" }
        // Capitalize first few words of the prompt
        let words = prompt.components(separatedBy: .whitespaces).prefix(4)
        let title = words.joined(separator: " ")
        return title.isEmpty ? "Widget" : title
    }

    private func isLowQualityGeneratedConfig(_ config: WidgetConfig, prompt: String) -> Bool {
        let promptToken = prompt.lowercased()
        let components = flattenedComponents(config.content)
        let nonLayout = components.filter { component in
            component.type != .vstack && component.type != .hstack && component.type != .container
        }

        guard !nonLayout.isEmpty else {
            return true
        }

        // Reject any config that contains template/dynamic placeholder syntax
        // (e.g. "{{dynamic.github.stars}}" or "{{value}}") — the AI invented these; they don't render.
        let hasPlaceholders = nonLayout.contains { component in
            let text = component.content ?? component.title ?? component.label ?? ""
            return text.contains("{{") && text.contains("}}")
        }
        if hasPlaceholders { return true }

        let genericWords = Set(["widget", "widgets", "fallback widget", "placeholder"])
        let genericTextCount = nonLayout.filter { component in
            guard component.type == .text || component.type == .note else { return false }
            let text = component.content?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            return text.isEmpty || genericWords.contains(text) || text.hasPrefix("widget ")
        }.count

        if genericTextCount == nonLayout.count {
            return true
        }

        let genericName = config.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if genericName == "custom widget" || genericName == "widget" {
            // Reject bland "Custom Widget" outputs unless there is clearly rich, non-generic content.
            let richContentCount = nonLayout.filter { component in
                switch component.type {
                case .clock, .analogClock, .weather, .worldClocks, .stock, .crypto, .calendarNext, .reminders, .checklist:
                    return true
                case .text, .note:
                    let text = (component.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.count >= 16 && !text.lowercased().hasPrefix("widget")
                default:
                    return false
                }
            }.count
            if richContentCount < 2 {
                return true
            }
        }

        let hasCrypto = nonLayout.contains { $0.type == .crypto }
        let hasStock = nonLayout.contains { $0.type == .stock }
        let hasWeather = nonLayout.contains { $0.type == .weather }
        let hasBTC = nonLayout.contains {
            ($0.type == .crypto || $0.type == .stock)
                && (["btc", "bitcoin"].contains(($0.symbol ?? "").lowercased()))
        }
        let hasETH = nonLayout.contains {
            ($0.type == .crypto || $0.type == .stock)
                && (["eth", "ethereum"].contains(($0.symbol ?? "").lowercased()))
        }
        let hasGold = nonLayout.contains { component in
            let symbol = normalizedAssetSymbol(component.symbol)
            return component.type == .stock
                && ["gld", "gc=f", "xauusd=x", "xau", "gold"].contains(symbol)
        }
        let hasSilver = nonLayout.contains { component in
            let symbol = normalizedAssetSymbol(component.symbol)
            return component.type == .stock
                && ["slv", "si=f", "xagusd=x", "xag", "silver"].contains(symbol)
        }
        let hasTime = nonLayout.contains {
            $0.type == .clock
                || $0.type == .analogClock
                || $0.type == .worldClocks
                || $0.type == .countdown
                || $0.type == .timer
                || $0.type == .stopwatch
        }

        let asksBTC = promptToken.contains("bitcoin") || promptToken.contains("btc")
        let asksETH = promptToken.contains("ethereum") || promptToken.contains("eth")
        let asksGold = promptToken.contains("gold") || promptToken.contains("xau")
        let asksSilver = promptToken.contains("silver") || promptToken.contains("xag")
        let asksCrypto = promptToken.contains("crypto") || asksBTC || asksETH

        if asksCrypto {
            if !hasCrypto && !hasStock {
                return true
            }
        }
        if asksBTC && !hasBTC {
            return true
        }
        if asksETH && !hasETH {
            return true
        }
        if asksGold && !hasGold {
            return true
        }
        if asksSilver && !hasSilver {
            return true
        }

        if (promptToken.contains("weather") || promptToken.contains("temperature") || promptToken.contains("temp")), !hasWeather {
            return true
        }

        if promptToken.contains("live"), config.refreshInterval > 120 {
            return true
        }

        if (promptToken.contains("clock") || promptToken.contains("time")), !hasTime {
            return true
        }

        let asksMultiCityTimeWeather = (promptToken.contains("clock") || promptToken.contains("time"))
            && (promptToken.contains("weather") || promptToken.contains("wether"))
        let requestedCities = detectTimeWeatherCities(in: promptToken)
        if asksMultiCityTimeWeather, requestedCities.count >= 2 {
            let requiredCityCount = min(max(2, requestedCities.count), 4)
            let weatherCount = nonLayout.filter { $0.type == .weather }.count
            let timeCoverage = nonLayout.reduce(into: 0) { running, component in
                switch component.type {
                case .clock, .analogClock:
                    running += 1
                case .worldClocks:
                    running += max(component.clocks?.count ?? 0, 1)
                default:
                    break
                }
            }

            if weatherCount < requiredCityCount || timeCoverage < requiredCityCount {
                return true
            }

            let asks12Hour = promptToken.contains("12 hour")
                || promptToken.contains("12-hour")
                || promptToken.contains("12h")
            if asks12Hour {
                let hasTwelveHourClock = nonLayout.contains { component in
                    guard component.type == .clock || component.type == .worldClocks else {
                        return false
                    }
                    guard let format = component.format?.lowercased() else {
                        // world_clocks renders as 12h by default in this app when size is compact.
                        return component.type == .worldClocks
                    }
                    return format.contains("h:mm a")
                        || format.contains("h:mm")
                        || format.contains("a")
                }
                if !hasTwelveHourClock {
                    return true
                }
            }
        }

        return false
    }

    private func normalizedAssetSymbol(_ raw: String?) -> String {
        (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private struct CityTimeWeatherSpec {
        let label: String
        let timezone: String
        let weatherLocation: String
        let defaultTemperatureUnit: String
        let matchIndex: Int
    }

    private func detectTimeWeatherCities(in normalizedPrompt: String) -> [CityTimeWeatherSpec] {
        let candidates: [(tokens: [String], label: String, timezone: String, weatherLocation: String, defaultTemperatureUnit: String)] = [
            (["pune"], "Pune", "Asia/Kolkata", "Pune, Maharashtra, India", "celsius"),
            (["nagpur"], "Nagpur", "Asia/Kolkata", "Nagpur, Maharashtra, India", "celsius"),
            (["bangalore", "banglore", "bengaluru", "bengalooru"], "Bangalore", "Asia/Kolkata", "Bangalore, Karnataka, India", "celsius"),
            (["tempe"], "Tempe", "America/Phoenix", "Tempe, AZ, USA", "fahrenheit"),
            (["seattle"], "Seattle", "America/Los_Angeles", "Seattle, WA, USA", "fahrenheit"),
            (["tokyo"], "Tokyo", "Asia/Tokyo", "Tokyo, Japan", "celsius"),
            (["london"], "London", "Europe/London", "London, UK", "celsius"),
            (["dubai"], "Dubai", "Asia/Dubai", "Dubai, UAE", "celsius"),
            (["new york", "nyc"], "New York", "America/New_York", "New York, NY, USA", "fahrenheit"),
            (["madison"], "Madison", "America/Chicago", "Madison, WI, USA", "fahrenheit"),
            (["san francisco", "sf"], "San Francisco", "America/Los_Angeles", "San Francisco, CA, USA", "fahrenheit")
        ]

        var matches: [CityTimeWeatherSpec] = []
        for candidate in candidates {
            var firstIndex: Int?
            for token in candidate.tokens {
                guard let range = normalizedPrompt.range(of: token) else {
                    continue
                }
                let index = normalizedPrompt.distance(from: normalizedPrompt.startIndex, to: range.lowerBound)
                if firstIndex == nil || index < firstIndex! {
                    firstIndex = index
                }
            }

            if let firstIndex {
                matches.append(
                    CityTimeWeatherSpec(
                        label: candidate.label,
                        timezone: candidate.timezone,
                        weatherLocation: candidate.weatherLocation,
                        defaultTemperatureUnit: candidate.defaultTemperatureUnit,
                        matchIndex: firstIndex
                    )
                )
            }
        }

        return matches.sorted { lhs, rhs in
            lhs.matchIndex < rhs.matchIndex
        }
    }

    private func explicitTemperatureUnit(in normalizedPrompt: String) -> String? {
        if normalizedPrompt.contains("celsius") || normalizedPrompt.contains("celcius") || normalizedPrompt.contains("°c") {
            return "celsius"
        }
        if normalizedPrompt.contains("fahrenheit") || normalizedPrompt.contains("fahreneit") || normalizedPrompt.contains("°f") {
            return "fahrenheit"
        }
        return nil
    }

    private func flattenedComponents(_ component: ComponentConfig) -> [ComponentConfig] {
        var items: [ComponentConfig] = [component]
        if let child = component.child {
            items.append(contentsOf: flattenedComponents(child))
        }
        if let children = component.children {
            for nested in children {
                items.append(contentsOf: flattenedComponents(nested))
            }
        }
        return items
    }

    /// Ensure no widget goes out with tiny padding — minimum 12px on all sides.
    private func ensureMinimumPadding(_ config: inout WidgetConfig) {
        let minPad: Double = 12
        config.padding.top = max(config.padding.top, minPad)
        config.padding.bottom = max(config.padding.bottom, minPad)
        config.padding.leading = max(config.padding.leading, minPad)
        config.padding.trailing = max(config.padding.trailing, minPad)
    }

    /// If the widget has many leaf components but a small size class, bump it up
    /// so content isn't cramped or clipped.
    private func ensureSizeFitsContent(_ config: inout WidgetConfig) {
        let leafCount = countLeafComponents(config.content)
        let w = config.size.width
        let h = config.size.height

        // 5+ leaf components in a Medium (320x180) → bump to Large
        if leafCount >= 5, w <= 320, h <= 180 {
            config.size = WidgetSize(width: 320, height: 360)
        }
        // 8+ leaf components in a Large → bump to Dashboard
        else if leafCount >= 8, w <= 320, h <= 360 {
            config.size = WidgetSize(width: 480, height: 360)
        }
    }

    private func countLeafComponents(_ component: ComponentConfig) -> Int {
        let isLayout = component.type == .vstack || component.type == .hstack
            || component.type == .container
            || component.type == .spacer || component.type == .divider
        let selfCount = isLayout ? 0 : 1
        let childCount = (component.child.map { countLeafComponents($0) } ?? 0)
        let childrenCount = (component.children ?? []).reduce(0) { $0 + countLeafComponents($1) }
        return selfCount + childCount + childrenCount
    }

    private func applyPromptPreferences(to config: inout WidgetConfig, prompt: String) {
        let normalized = prompt.lowercased()
        guard let explicitUnit = explicitTemperatureUnit(in: normalized) else { return }
        applyTemperatureUnit(explicitUnit, to: config.content)
    }

    private func applyTemperatureUnit(_ unit: String, to component: ComponentConfig) {
        if component.type == .weather {
            component.temperatureUnit = unit
        }
        if let child = component.child {
            applyTemperatureUnit(unit, to: child)
        }
        if let children = component.children {
            for nested in children {
                applyTemperatureUnit(unit, to: nested)
            }
        }
    }

    /// After an AI edit, the generated config may drop user-set properties that weren't
    /// part of the edit request (e.g., temperatureUnit, location, startHour).
    /// Walk both trees by component type and preserve properties the AI left nil.
    private func preserveUserProperties(from existing: ComponentConfig, into generated: ComponentConfig) {
        // Only merge if the component type matches (same kind of widget)
        if existing.type == generated.type {
            // Preserve data/display settings the user may have customized
            if generated.temperatureUnit == nil, let v = existing.temperatureUnit { generated.temperatureUnit = v }
            if generated.location == nil,        let v = existing.location        { generated.location = v }
            if generated.symbol == nil,          let v = existing.symbol          { generated.symbol = v }
            if generated.currency == nil,        let v = existing.currency        { generated.currency = v }
            if generated.startHour == nil,       let v = existing.startHour       { generated.startHour = v }
            if generated.endHour == nil,         let v = existing.endHour         { generated.endHour = v }
            if generated.feedUrl == nil,         let v = existing.feedUrl         { generated.feedUrl = v }
            if generated.feedUrls == nil,        let v = existing.feedUrls        { generated.feedUrls = v }
            if generated.timezone == nil,        let v = existing.timezone        { generated.timezone = v }
            if generated.sourceSystem == nil,    let v = existing.sourceSystem    { generated.sourceSystem = v }
            if generated.list == nil,            let v = existing.list            { generated.list = v }
            if generated.device == nil,          let v = existing.device          { generated.device = v }
            if generated.timeRange == nil,       let v = existing.timeRange       { generated.timeRange = v }
            if generated.forecastDays == nil,    let v = existing.forecastDays    { generated.forecastDays = v }
            if generated.items == nil,           let v = existing.items           { generated.items = v }
            if generated.habits == nil,          let v = existing.habits          { generated.habits = v }
            if generated.links == nil,           let v = existing.links           { generated.links = v }
            if generated.shortcuts == nil,       let v = existing.shortcuts       { generated.shortcuts = v }
            if generated.customQuotes == nil,    let v = existing.customQuotes    { generated.customQuotes = v }
            if generated.clocks == nil,          let v = existing.clocks          { generated.clocks = v }
        }

        // Recurse into child
        if let existChild = existing.child, let genChild = generated.child {
            preserveUserProperties(from: existChild, into: genChild)
        }

        // Recurse into children by matching type + position
        if let existChildren = existing.children, let genChildren = generated.children {
            // Match by position when counts are equal, or by type otherwise
            if existChildren.count == genChildren.count {
                for (ec, gc) in zip(existChildren, genChildren) {
                    preserveUserProperties(from: ec, into: gc)
                }
            } else {
                // Best-effort: for each generated child, find first matching existing by type
                var used = Set<Int>()
                for gc in genChildren {
                    if let matchIdx = existChildren.indices.first(where: { !used.contains($0) && existChildren[$0].type == gc.type }) {
                        preserveUserProperties(from: existChildren[matchIdx], into: gc)
                        used.insert(matchIdx)
                    }
                }
            }
        }
    }

    private func heuristicWidget(
        for prompt: String,
        theme: WidgetTheme,
        context: PromptContext
    ) -> WidgetConfig? {
        let lower = prompt.lowercased()

        if let timeWeather = heuristicMultiCityTimeWeatherWidget(
            for: prompt,
            normalizedPrompt: lower,
            theme: theme,
            context: context
        ) {
            return timeWeather
        }

        if let crypto = heuristicCryptoWidget(for: prompt, normalizedPrompt: lower, theme: theme) {
            return crypto
        }

        if let stock = heuristicStockWidget(for: prompt, normalizedPrompt: lower, theme: theme) {
            return stock
        }

        // General clock request (digital or analog) — catches cases where AI failed
        // due to pattern library confusion (e.g., generating Text+dataSource instead of clock component)
        if lower.contains("clock") {
            let isAnalog = lower.contains("analog") || lower.contains("analogue") || lower.contains("anolog")
            if isAnalog {
                let clock = ComponentConfig(type: .analogClock)
                clock.timezone = "local"
                clock.showSecondHand = lower.contains("second")
                return WidgetConfig(
                    name: "Clock",
                    description: prompt,
                    size: WidgetSize(width: 200, height: 200),
                    minSize: nil,
                    maxSize: nil,
                    theme: theme,
                    background: BackgroundConfig.default(for: theme),
                    cornerRadius: 20,
                    padding: EdgeInsetsConfig(top: 16, bottom: 16, leading: 16, trailing: 16),
                    refreshInterval: 60,
                    content: clock
                )
            } else {
                let wantsSeconds = lower.contains("second")
                let wants12h = lower.contains("12") || lower.contains(" am") || lower.contains(" pm")
                let clock = ComponentConfig(type: .clock)
                clock.timezone = "local"
                clock.format = wants12h ? "h:mm a" : "HH:mm"
                clock.showSeconds = wantsSeconds
                clock.font = "sf-mono"
                clock.size = wantsSeconds ? 34 : 48
                clock.weight = .light
                clock.color = "primary"
                return WidgetConfig(
                    name: "Clock",
                    description: prompt,
                    size: WidgetSize(width: wantsSeconds ? 240 : 210, height: 100),
                    minSize: nil,
                    maxSize: nil,
                    theme: theme,
                    background: BackgroundConfig.default(for: theme),
                    cornerRadius: 20,
                    padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 20, trailing: 20),
                    refreshInterval: 60,
                    content: clock
                )
            }
        }

        if (lower.contains("just show me the time") || lower.contains("nothing else"))
            && (lower.contains("tiny") || lower.contains("minimal")) {
            let clock = ComponentConfig(type: .clock)
            clock.timezone = "local"
            clock.format = lower.contains("seconds") ? "HH:mm:ss" : "HH:mm"
            clock.showSeconds = lower.contains("seconds")
            clock.font = "sf-mono"
            clock.size = 34
            clock.weight = .light
            clock.color = "primary"
            return WidgetConfig(
                name: "Tiny Clock",
                description: prompt,
                size: WidgetSize(width: 184, height: 94),
                minSize: nil,
                maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 12, bottom: 12, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: clock
            )
        }

        // GitHub repo → github_repo_stats widget; other URLs → link_bookmarks
        let isGitHubCom = lower.contains("github.com")
        let isGitHub = lower.contains("github") || lower.contains("gitlab") || lower.contains("bitbucket")
        let hasURL = lower.contains("https://") || lower.contains("http://")
        if isGitHub || hasURL {
            let words = prompt.components(separatedBy: .whitespaces)
            // Strip trailing sentence punctuation that may have been appended to the URL
            // e.g. "https://github.com/owner/repo. Which stats..." → URL word includes the period.
            let trailingPunct = CharacterSet(charactersIn: ".,;:!?)\"'")
            let urlStr = (words.first { $0.hasPrefix("https://") || $0.hasPrefix("http://") } ?? "")
                .trimmingCharacters(in: trailingPunct)

            // Extract "owner/repo" from a GitHub URL
            var repoPath: String?
            if !urlStr.isEmpty, let parsed = URL(string: urlStr) {
                let parts = parsed.pathComponents.filter { $0 != "/" }
                if parts.count >= 2 {
                    let owner = parts[0].trimmingCharacters(in: trailingPunct)
                    let repo  = parts[1].trimmingCharacters(in: trailingPunct)
                    if !owner.isEmpty && !repo.isEmpty {
                        repoPath = "\(owner)/\(repo)"
                    }
                }
            }

            if isGitHubCom, let repoPath {
                // Native github_repo_stats component with live data.
                // Parse which stats the user selected from synthesized prompt tokens.
                let stats = ComponentConfig(type: .githubRepoStats)
                stats.source = repoPath
                let statTokens = ["stars", "forks", "issues", "watchers", "language", "description"]
                let selectedStats = statTokens.filter { lower.contains($0) }
                if !selectedStats.isEmpty {
                    stats.showComponents = selectedStats
                }
                return WidgetConfig(
                    name: repoPath.components(separatedBy: "/").last ?? "GitHub",
                    description: prompt,
                    size: .medium,
                    minSize: nil,
                    maxSize: nil,
                    theme: theme,
                    background: BackgroundConfig.default(for: theme),
                    cornerRadius: 20,
                    padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 16, trailing: 16),
                    refreshInterval: 1800,
                    content: stats
                )
            } else {
                // Non-GitHub URL → bookmark link
                let repoName = repoPath ?? (isGitHub ? "Repository" : urlStr)
                let link = ComponentConfig(type: .linkBookmarks)
                link.style = "list"
                link.links = [LinkBookmarkConfig(
                    name: repoName,
                    url: urlStr.isEmpty ? "https://github.com" : urlStr,
                    icon: "chevron.left.forwardslash.chevron.right"
                )]
                return WidgetConfig(
                    name: isGitHub ? "GitHub" : "Bookmark",
                    description: prompt,
                    size: WidgetSize(width: 280, height: 80),
                    minSize: nil,
                    maxSize: nil,
                    theme: theme,
                    background: BackgroundConfig.default(for: theme),
                    cornerRadius: 20,
                    padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 16, trailing: 16),
                    refreshInterval: 3600,
                    content: link
                )
            }
        }

        // Mood / wellness / habit tracker
        let isMood = lower.contains("mood") || lower.contains("feeling") || lower.contains("emotion") || lower.contains("wellness")
        // "tracker" alone is too broad — exclude contexts like "stat tracker", "repo tracker", "bug tracker"
        let trackerIsHabit = lower.contains("tracker")
            && !lower.contains("stat") && !lower.contains("repo") && !lower.contains("git")
            && !lower.contains("bug") && !lower.contains("issue") && !lower.contains("project")
            && !lower.contains("http") && !lower.contains("progress")
        let isHabit = lower.contains("habit") || lower.contains("routine") || lower.contains("daily") || trackerIsHabit
        if isMood || isHabit {
            let moods: [(id: String, name: String, icon: String)] = isMood
                ? [("mood1", "Happy", "face.smiling"), ("mood2", "Calm", "leaf"), ("mood3", "Anxious", "bolt.heart"), ("mood4", "Sad", "cloud.rain"), ("mood5", "Focused", "scope")]
                : [("h1", "Habit 1", "checkmark.circle"), ("h2", "Habit 2", "checkmark.circle"), ("h3", "Habit 3", "checkmark.circle")]
            let tracker = ComponentConfig(type: .habitTracker)
            tracker.habits = moods.map { HabitConfig(id: $0.id, name: $0.name, icon: $0.icon, target: 1, unit: nil) }
            tracker.showStreak = true
            return WidgetConfig(
                name: isMood ? "Mood Tracker" : "Habit Tracker",
                description: prompt,
                size: WidgetSize(width: 280, height: 260),
                minSize: nil,
                maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: tracker
            )
        }

        // Freeform writing: "jot down", "scratch pad", "brain dump", "on my mind" → editable note
        let isFreeformWrite = lower.contains("jot") || lower.contains("scratch") || lower.contains("brain dump")
            || lower.contains("on my mind") || lower.contains("dump") || lower.contains("thoughts")
            || lower.contains("ideas") || lower.contains("quick note") || lower.contains("blank note")
        if isFreeformWrite || lower.contains("journal") || lower.contains("diary") || lower.contains("memo") {
            let note = ComponentConfig(type: .note)
            note.content = ""
            note.editable = true
            return WidgetConfig(
                name: isFreeformWrite ? "Quick Notes" : "Journal",
                description: prompt,
                size: WidgetSize(width: 300, height: 200),
                minSize: nil,
                maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: note
            )
        }

        // Checklist / todo (structured task list, not freeform)
        if lower.contains("checklist") || lower.contains("todo") || lower.contains("to-do") || lower.contains("task list") {
            let checklist = ComponentConfig(type: .checklist)
            checklist.interactive = true
            checklist.items = [
                ChecklistItemConfig(id: "t1", text: "Task 1", checked: false),
                ChecklistItemConfig(id: "t2", text: "Task 2", checked: false),
                ChecklistItemConfig(id: "t3", text: "Task 3", checked: false)
            ]
            return WidgetConfig(
                name: "Checklist",
                description: prompt,
                size: WidgetSize(width: 260, height: 200),
                minSize: nil,
                maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: checklist
            )
        }

        // Note / sticky note
        if lower.contains("note") {
            let note = ComponentConfig(type: .note)
            note.content = ""
            note.editable = true
            return WidgetConfig(
                name: "Note",
                description: prompt,
                size: WidgetSize(width: 280, height: 180),
                minSize: nil,
                maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: note
            )
        }

        if lower.contains("countdown") || lower.contains("count down") {
            let formatter = ISO8601DateFormatter()
            let target = Calendar(identifier: .gregorian).date(byAdding: .day, value: 7, to: context.currentDate) ?? context.currentDate
            let countdown = ComponentConfig(type: .countdown)
            countdown.targetDate = formatter.string(from: target)
            countdown.showComponents = ["days", "hours", "minutes"]
            countdown.style = "compact"
            countdown.font = "sf-mono"
            countdown.size = 18
            countdown.color = "accent"
            return WidgetConfig(
                name: "Countdown",
                description: prompt,
                size: WidgetSize(width: 270, height: 100),
                minSize: nil,
                maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 12, bottom: 12, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: countdown
            )
        }

        // ── Weather-only (no time requirement) ──
        let asksWeatherOnly = lower.contains("weather") || lower.contains("wether")
            || lower.contains("temperature") || lower.contains("temp")
            || lower.contains("forecast")
        if asksWeatherOnly {
            let location = heuristicExtractCity(from: lower) ?? "New York"
            let unit = explicitTemperatureUnit(in: lower) ?? "fahrenheit"
            let isForecast = lower.contains("forecast") || lower.contains("3 day") || lower.contains("5 day") || lower.contains("week")
            let weather = ComponentConfig(type: .weather)
            weather.location = location
            weather.temperatureUnit = unit
            if isForecast {
                weather.style = "forecast"
                weather.forecastDays = lower.contains("5") ? 5 : 3
            }
            return WidgetConfig(
                name: "\(location) Weather",
                description: prompt,
                size: WidgetSize(width: 320, height: isForecast ? 200 : 170),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 300,
                content: weather
            )
        }

        // ── Time-only (digital clock, no weather) ──
        let asksTimeOnly = lower.contains("time") && !lower.contains("screen time")
        if asksTimeOnly {
            let clock = ComponentConfig(type: .clock)
            clock.timezone = "local"
            clock.format = lower.contains("12") ? "h:mm a" : "HH:mm"
            clock.showSeconds = lower.contains("second")
            clock.font = "sf-mono"
            clock.size = 42
            clock.weight = .light
            clock.color = "primary"
            return WidgetConfig(
                name: "Clock",
                description: prompt,
                size: WidgetSize(width: 220, height: 100),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 20, trailing: 20),
                refreshInterval: 60,
                content: clock
            )
        }

        // ── Calendar / schedule ──
        if lower.contains("calendar") || lower.contains("event") || lower.contains("schedule") || lower.contains("meeting") {
            let cal = ComponentConfig(type: .calendarNext)
            cal.maxEvents = 5
            cal.showCalendarColor = true
            return WidgetConfig(
                name: "Upcoming Events",
                description: prompt,
                size: WidgetSize(width: 320, height: 240),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 300,
                content: cal
            )
        }

        // ── Reminders ──
        if lower.contains("reminder") {
            let rem = ComponentConfig(type: .reminders)
            rem.maxItems = 5
            return WidgetConfig(
                name: "Reminders",
                description: prompt,
                size: WidgetSize(width: 300, height: 220),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 300,
                content: rem
            )
        }

        // ── News / headlines ──
        if lower.contains("news") || lower.contains("headline") || lower.contains("rss") {
            let news = ComponentConfig(type: .newsHeadlines)
            news.maxItems = 5
            news.feedUrl = "https://feeds.bbci.co.uk/news/rss.xml"
            news.showFavicon = true
            return WidgetConfig(
                name: "News Headlines",
                description: prompt,
                size: WidgetSize(width: 340, height: 260),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 600,
                content: news
            )
        }

        // ── Battery ──
        if lower.contains("battery") {
            let bat = ComponentConfig(type: .battery)
            return WidgetConfig(
                name: "Battery",
                description: prompt,
                size: WidgetSize(width: 200, height: 100),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: bat
            )
        }

        // ── System stats (CPU, RAM, disk) ──
        if lower.contains("cpu") || lower.contains("ram") || lower.contains("memory") || lower.contains("system") || lower.contains("disk") {
            let sys = ComponentConfig(type: .systemStats)
            return WidgetConfig(
                name: "System Stats",
                description: prompt,
                size: WidgetSize(width: 280, height: 160),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 10,
                content: sys
            )
        }

        // ── Music / now playing ──
        if lower.contains("music") || lower.contains("now playing") || lower.contains("spotify") || lower.contains("apple music") || lower.contains("song") {
            let music = ComponentConfig(type: .musicNowPlaying)
            music.showAlbumArt = true
            music.showArtist = true
            music.showTitle = true
            music.showProgress = true
            return WidgetConfig(
                name: "Now Playing",
                description: prompt,
                size: WidgetSize(width: 320, height: 160),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 5,
                content: music
            )
        }

        // ── Pomodoro / timer ──
        if lower.contains("pomodoro") || lower.contains("focus timer") {
            let pom = ComponentConfig(type: .pomodoro)
            pom.workDuration = 25
            pom.breakDuration = 5
            pom.showSessionCount = true
            return WidgetConfig(
                name: "Pomodoro Timer",
                description: prompt,
                size: WidgetSize(width: 240, height: 200),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 1,
                content: pom
            )
        }

        // ── Timer / stopwatch ──
        if lower.contains("timer") || lower.contains("stopwatch") {
            let isStopwatch = lower.contains("stopwatch")
            let comp = ComponentConfig(type: isStopwatch ? .stopwatch : .timer)
            if !isStopwatch {
                comp.duration = 300 // 5 min default
            }
            comp.showControls = true
            return WidgetConfig(
                name: isStopwatch ? "Stopwatch" : "Timer",
                description: prompt,
                size: WidgetSize(width: 220, height: 160),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 1,
                content: comp
            )
        }

        // ── Quote / inspiration ──
        if lower.contains("quote") || lower.contains("inspiration") || lower.contains("motivat") {
            let quote = ComponentConfig(type: .quote)
            quote.category = "inspirational"
            quote.showQuotationMarks = true
            return WidgetConfig(
                name: "Daily Quote",
                description: prompt,
                size: WidgetSize(width: 320, height: 160),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 3600,
                content: quote
            )
        }

        // ── Day/year progress ──
        if lower.contains("progress") || lower.contains("day progress") || lower.contains("year progress") {
            let isYear = lower.contains("year")
            let prog = ComponentConfig(type: isYear ? .yearProgress : .dayProgress)
            prog.showPercentage = true
            return WidgetConfig(
                name: isYear ? "Year Progress" : "Day Progress",
                description: prompt,
                size: WidgetSize(width: 260, height: 100),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: prog
            )
        }

        // ── Screen time ──
        if lower.contains("screen time") {
            let st = ComponentConfig(type: .screenTime)
            st.maxApps = 5
            return WidgetConfig(
                name: "Screen Time",
                description: prompt,
                size: WidgetSize(width: 300, height: 220),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 300,
                content: st
            )
        }

        // ── Breathing exercise ──
        if lower.contains("breath") || lower.contains("meditat") || lower.contains("relax") || lower.contains("calm") {
            let breath = ComponentConfig(type: .breathingExercise)
            return WidgetConfig(
                name: "Breathing Exercise",
                description: prompt,
                size: WidgetSize(width: 240, height: 240),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: breath
            )
        }

        // ── Shortcut launcher ──
        if lower.contains("shortcut") || lower.contains("launcher") || lower.contains("app launcher") {
            let launcher = ComponentConfig(type: .shortcutLauncher)
            return WidgetConfig(
                name: "Shortcuts",
                description: prompt,
                size: WidgetSize(width: 280, height: 160),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 60,
                content: launcher
            )
        }

        // ── Bookmark links ──
        if lower.contains("bookmark") || lower.contains("link") || lower.contains("favorite") {
            let links = ComponentConfig(type: .linkBookmarks)
            links.style = "grid"
            return WidgetConfig(
                name: "Bookmarks",
                description: prompt,
                size: WidgetSize(width: 280, height: 160),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 14, trailing: 14),
                refreshInterval: 3600,
                content: links
            )
        }

        // ── Virtual pet ──
        if lower.contains("pet") || lower.contains("tamagotchi") || lower.contains("virtual pet") {
            let pet = ComponentConfig(type: .virtualPet)
            return WidgetConfig(
                name: "Virtual Pet",
                description: prompt,
                size: WidgetSize(width: 300, height: 300),
                minSize: nil, maxSize: nil,
                theme: theme,
                background: BackgroundConfig.default(for: theme),
                cornerRadius: 20,
                padding: EdgeInsetsConfig(top: 8, bottom: 8, leading: 8, trailing: 8),
                refreshInterval: 60,
                content: pet
            )
        }

        return nil
    }

    /// Try to extract a recognizable city name from the prompt
    private func heuristicExtractCity(from normalizedPrompt: String) -> String? {
        let knownCities: [(tokens: [String], label: String)] = [
            (["new york", "nyc"], "New York"),
            (["los angeles", "la"], "Los Angeles"),
            (["san francisco", "sf"], "San Francisco"),
            (["chicago"], "Chicago"),
            (["seattle"], "Seattle"),
            (["london"], "London"),
            (["paris"], "Paris"),
            (["tokyo"], "Tokyo"),
            (["dubai"], "Dubai"),
            (["mumbai", "bombay"], "Mumbai"),
            (["bangalore", "banglore", "bengaluru"], "Bangalore"),
            (["pune"], "Pune"),
            (["delhi", "new delhi"], "New Delhi"),
            (["singapore"], "Singapore"),
            (["sydney"], "Sydney"),
            (["toronto"], "Toronto"),
            (["berlin"], "Berlin"),
            (["amsterdam"], "Amsterdam"),
            (["hong kong"], "Hong Kong"),
            (["shanghai"], "Shanghai"),
            (["seoul"], "Seoul"),
            (["bangkok"], "Bangkok"),
            (["rome"], "Rome"),
            (["madrid"], "Madrid"),
            (["lisbon"], "Lisbon"),
            (["vienna"], "Vienna"),
            (["zurich"], "Zurich"),
            (["stockholm"], "Stockholm"),
            (["tempe"], "Tempe"),
            (["madison"], "Madison"),
            (["austin"], "Austin"),
            (["boston"], "Boston"),
            (["denver"], "Denver"),
            (["portland"], "Portland"),
            (["miami"], "Miami"),
            (["atlanta"], "Atlanta"),
            (["dallas"], "Dallas"),
            (["houston"], "Houston"),
            (["phoenix"], "Phoenix"),
            (["nagpur"], "Nagpur"),
        ]
        for city in knownCities {
            for token in city.tokens {
                if normalizedPrompt.contains(token) { return city.label }
            }
        }
        return nil
    }

    private func heuristicMultiCityTimeWeatherWidget(
        for prompt: String,
        normalizedPrompt: String,
        theme: WidgetTheme,
        context: PromptContext
    ) -> WidgetConfig? {
        let asksTime = normalizedPrompt.contains("time") || normalizedPrompt.contains("clock")
        let asksWeather = normalizedPrompt.contains("weather")
            || normalizedPrompt.contains("wether")
            || normalizedPrompt.contains("temperature")
            || normalizedPrompt.contains("temp")
        guard asksTime && asksWeather else {
            return nil
        }

        var cities = detectTimeWeatherCities(in: normalizedPrompt)
        guard cities.count >= 2 else {
            return nil
        }
        cities = Array(cities.prefix(4))

        let globalUnit = explicitTemperatureUnit(in: normalizedPrompt)
        let clockFormat: String = (normalizedPrompt.contains("12 hour")
            || normalizedPrompt.contains("12-hour")
            || normalizedPrompt.contains("12h")) ? "h:mm a" : "HH:mm"
        let showSeconds = normalizedPrompt.contains("seconds") || normalizedPrompt.contains("sec")

        var rows: [ComponentConfig] = []
        for (index, city) in cities.enumerated() {
            let title = ComponentConfig(
                type: .text,
                content: city.label,
                font: "sf-pro",
                size: 13,
                weight: .semibold,
                color: "secondary"
            )

            let clock = ComponentConfig(type: .clock)
            clock.style = "digital"
            clock.timezone = city.timezone
            clock.format = clockFormat
            clock.showSeconds = showSeconds
            clock.font = "sf-mono"
            clock.size = showSeconds ? 24 : 30
            clock.weight = .light
            clock.color = "primary"

            let left = ComponentConfig(
                type: .vstack,
                alignment: "leading",
                spacing: 4,
                children: [title, clock]
            )

            let spacer = ComponentConfig(type: .spacer)

            let weather = ComponentConfig(type: .weather)
            weather.location = city.weatherLocation
            weather.showIcon = true
            weather.showTemperature = true
            weather.showCondition = true
            weather.showHighLow = false
            weather.showHumidity = false
            weather.showWind = false
            weather.showFeelsLike = false
            weather.temperatureUnit = globalUnit ?? city.defaultTemperatureUnit
            weather.style = "compact"
            weather.color = "primary"

            let row = ComponentConfig(
                type: .hstack,
                alignment: "center",
                spacing: 12,
                children: [left, spacer, weather]
            )
            rows.append(row)

            if index < cities.count - 1 {
                rows.append(ComponentConfig(
                    type: .divider,
                    color: "muted",
                    direction: "horizontal",
                    thickness: 0.5
                ))
            }
        }

        let root = ComponentConfig(
            type: .vstack,
            alignment: "leading",
            spacing: 10,
            children: rows
        )

        let width = Double(max(440, min(680, 420 + (cities.count - 2) * 40)))
        let height = Double(max(190, min(520, 66 * cities.count + 72)))

        return WidgetConfig(
            name: "Time + Weather",
            description: prompt,
            size: WidgetSize(width: width, height: height),
            minSize: nil,
            maxSize: nil,
            theme: theme,
            background: BackgroundConfig.default(for: theme),
            cornerRadius: 20,
            padding: EdgeInsetsConfig(top: 14, bottom: 14, leading: 16, trailing: 16),
            refreshInterval: 900,
            content: root,
            dataSources: nil
        )
    }

    private func heuristicCryptoWidget(
        for prompt: String,
        normalizedPrompt: String,
        theme: WidgetTheme
    ) -> WidgetConfig? {
        enum MarketItem {
            case crypto(String)
            case stock(String)
        }

        var marketItems: [MarketItem] = []

        func appendCrypto(_ symbol: String) {
            if !marketItems.contains(where: { item in
                if case .crypto(symbol) = item { return true }
                return false
            }) {
                marketItems.append(.crypto(symbol))
            }
        }

        func appendStock(_ symbol: String) {
            if !marketItems.contains(where: { item in
                if case .stock(symbol) = item { return true }
                return false
            }) {
                marketItems.append(.stock(symbol))
            }
        }

        let cryptoMapping: [(String, String)] = [
            ("bitcoin", "BTC"), ("btc", "BTC"),
            ("ethereum", "ETH"), ("eth", "ETH"),
            ("solana", "SOL"), ("sol", "SOL"),
            ("dogecoin", "DOGE"), ("doge", "DOGE"),
            ("cardano", "ADA"), ("ada", "ADA"),
            ("xrp", "XRP"),
            ("litecoin", "LTC"), ("ltc", "LTC")
        ]

        for (token, symbol) in cryptoMapping where normalizedPrompt.contains(token) {
            appendCrypto(symbol)
        }

        if normalizedPrompt.contains("gold") || normalizedPrompt.contains("xau") {
            appendStock("GLD")
        }
        if normalizedPrompt.contains("silver") || normalizedPrompt.contains("xag") {
            appendStock("SLV")
        }

        let mentionsCrypto = normalizedPrompt.contains("crypto")
            || normalizedPrompt.contains("bitcoin")
            || normalizedPrompt.contains("ethereum")

        if marketItems.isEmpty, mentionsCrypto {
            appendCrypto("BTC")
            appendCrypto("ETH")
        }

        // Interpret "bitcoin stock / ethereum stock" as crypto intent.
        if marketItems.isEmpty,
           normalizedPrompt.contains("stock"),
           (normalizedPrompt.contains("btc") || normalizedPrompt.contains("eth") || normalizedPrompt.contains("bitcoin") || normalizedPrompt.contains("ethereum")) {
            appendCrypto("BTC")
            appendCrypto("ETH")
        }

        guard !marketItems.isEmpty else {
            return nil
        }

        marketItems = Array(marketItems.prefix(6))

        func marketComponent(for item: MarketItem) -> ComponentConfig {
            switch item {
            case .crypto(let symbol):
                let crypto = ComponentConfig(type: .crypto)
                crypto.symbol = symbol
                crypto.currency = "USD"
                crypto.showPrice = true
                crypto.showChange = true
                crypto.showChart = false
                crypto.color = "primary"
                return crypto
            case .stock(let symbol):
                let stock = ComponentConfig(type: .stock)
                stock.symbol = symbol
                stock.showPrice = true
                stock.showChange = true
                stock.showChangePercent = true
                stock.showChart = false
                stock.color = "primary"
                stock.positiveColor = "positive"
                stock.negativeColor = "negative"
                return stock
            }
        }

        func row(for items: [MarketItem]) -> ComponentConfig {
            var children: [ComponentConfig] = []
            for (index, item) in items.enumerated() {
                children.append(marketComponent(for: item))
                if index < items.count - 1 {
                    children.append(ComponentConfig(
                        type: .divider,
                        color: "muted",
                        direction: "vertical",
                        thickness: 0.5
                    ))
                }
            }
            return ComponentConfig(
                type: .hstack,
                alignment: "center",
                spacing: 12,
                children: children
            )
        }

        let wantsGrid = normalizedPrompt.contains("grid")
        let root: ComponentConfig
        let size: WidgetSize

        if wantsGrid && marketItems.count >= 4 {
            let firstRow = row(for: Array(marketItems.prefix(2)))
            let secondRow = row(for: Array(marketItems.dropFirst(2).prefix(2)))
            root = ComponentConfig(
                type: .vstack,
                alignment: "leading",
                spacing: 10,
                children: [firstRow, secondRow]
            )
            size = WidgetSize(width: 420, height: 210)
        } else {
            root = row(for: marketItems)
            let width = Double(max(340, min(980, 160 * marketItems.count + 80)))
            size = WidgetSize(width: width, height: 118)
        }

        return WidgetConfig(
            name: "Markets Live",
            description: prompt,
            size: size,
            minSize: nil,
            maxSize: nil,
            theme: theme,
            background: BackgroundConfig.default(for: theme),
            cornerRadius: 20,
            padding: EdgeInsetsConfig(top: 12, bottom: 12, leading: 14, trailing: 14),
            refreshInterval: normalizedPrompt.contains("live") ? 60 : 120,
            content: root
        )
    }

    private func heuristicStockWidget(
        for prompt: String,
        normalizedPrompt: String,
        theme: WidgetTheme
    ) -> WidgetConfig? {
        guard normalizedPrompt.contains("stock") || normalizedPrompt.contains("ticker") else {
            return nil
        }

        if normalizedPrompt.contains("bitcoin") || normalizedPrompt.contains("ethereum") || normalizedPrompt.contains("crypto") {
            return nil
        }

        var symbols: [String] = []
        let namedMap: [(String, String)] = [
            ("apple", "AAPL"),
            ("google", "GOOGL"),
            ("alphabet", "GOOGL"),
            ("microsoft", "MSFT"),
            ("tesla", "TSLA"),
            ("nvidia", "NVDA"),
            ("meta", "META"),
            ("amazon", "AMZN"),
            ("gold", "GLD"),
            ("silver", "SLV")
        ]
        for (token, symbol) in namedMap where normalizedPrompt.contains(token) {
            if !symbols.contains(symbol) {
                symbols.append(symbol)
            }
        }

        let regex = try? NSRegularExpression(pattern: "\\b[A-Z]{1,5}\\b")
        let ns = prompt as NSString
        let range = NSRange(location: 0, length: ns.length)
        regex?.matches(in: prompt, range: range).forEach { match in
            let value = ns.substring(with: match.range)
            if !symbols.contains(value) {
                symbols.append(value)
            }
        }

        guard !symbols.isEmpty else {
            return nil
        }

        symbols = Array(symbols.prefix(5))
        var children: [ComponentConfig] = []
        for (index, symbol) in symbols.enumerated() {
            let stock = ComponentConfig(type: .stock)
            stock.symbol = symbol
            stock.showPrice = true
            stock.showChange = true
            stock.showChangePercent = true
            stock.showChart = false
            stock.color = "primary"
            stock.positiveColor = "positive"
            stock.negativeColor = "negative"
            children.append(stock)

            if index < symbols.count - 1 {
                let divider = ComponentConfig(
                    type: .divider,
                    color: "muted",
                    direction: "vertical",
                    thickness: 0.5
                )
                children.append(divider)
            }
        }

        let root = ComponentConfig(
            type: .hstack,
            alignment: "center",
            spacing: 12,
            children: children
        )

        let width = Double(max(360, min(860, 155 * symbols.count + 80)))
        return WidgetConfig(
            name: "Stock Ticker",
            description: prompt,
            size: WidgetSize(width: width, height: 120),
            minSize: nil,
            maxSize: nil,
            theme: theme,
            background: BackgroundConfig.default(for: theme),
            cornerRadius: 20,
            padding: EdgeInsetsConfig(top: 12, bottom: 12, leading: 14, trailing: 14),
            refreshInterval: normalizedPrompt.contains("live") ? 60 : 120,
            content: root
        )
    }

}
