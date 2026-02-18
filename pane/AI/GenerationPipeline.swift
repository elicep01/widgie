import Foundation

struct GenerationPipeline {
    private let promptBuilder: PromptBuilder
    private let validator: SchemaValidator
    private let verificationService: VerificationService
    private let correctionService: CorrectionService
    private let maxTotalCalls = 6
    private let maxGenerationAttempts = 2
    private let maxSchemaRepairAttemptsPerGeneration = 1
    private let callTimeoutSeconds: Double
    private let totalPipelineTimeoutSeconds: Double

    init(
        promptBuilder: PromptBuilder,
        validator: SchemaValidator,
        callTimeoutSeconds: Double = 8.0,
        totalPipelineTimeoutSeconds: Double = 10.0
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
        verificationClient: AIProviderClient? = nil
    ) async throws -> WidgetConfig {
        let systemPrompt = promptBuilder.generationSystemPrompt(defaultTheme: defaultTheme, context: context, prompt: prompt)
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

        return config
    }

    func edit(
        existingConfig: WidgetConfig,
        editPrompt: String,
        defaultTheme: WidgetTheme,
        context: PromptContext,
        generationClient: AIProviderClient,
        verificationClient: AIProviderClient? = nil
    ) async throws -> WidgetConfig {
        let systemPrompt = promptBuilder.generationSystemPrompt(defaultTheme: defaultTheme, context: context, prompt: editPrompt)
        let userPrompt = promptBuilder.editUserPrompt(existingConfig: existingConfig, editPrompt: editPrompt)

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
            if isTimeoutFailure(lastGenerationError) {
                throw AIWidgetServiceError.requestFailed(
                    "Timed out while generating widget."
                )
            }

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
        let headline = ComponentConfig(
            type: .text,
            content: "Fallback Widget",
            font: "sf-pro",
            size: 13,
            weight: .semibold,
            color: "secondary"
        )
        let body = ComponentConfig(
            type: .note,
            content: "Widget generation failed. Edit this widget to refine it.\n\nPrompt: \(prompt)",
            font: "sf-pro",
            size: 13,
            color: "primary"
        )
        body.editable = true
        var children = [headline, body]
        if let error {
            let detail = ComponentConfig(
                type: .text,
                content: error.localizedDescription,
                font: "sf-mono",
                size: 11,
                color: "muted",
                maxLines: 3
            )
            children.append(detail)
        }
        let root = ComponentConfig(
            type: .vstack,
            alignment: "leading",
            spacing: 8,
            children: children
        )

        return WidgetConfig(
            name: "Fallback Widget",
            description: prompt,
            size: WidgetSize(width: 380, height: 190),
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

    private func isLowQualityGeneratedConfig(_ config: WidgetConfig, prompt: String) -> Bool {
        let promptToken = prompt.lowercased()
        let components = flattenedComponents(config.content)
        let nonLayout = components.filter { component in
            component.type != .vstack && component.type != .hstack && component.type != .container
        }

        guard !nonLayout.isEmpty else {
            return true
        }

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

        if promptToken.contains("weather"), !hasWeather {
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

        // Mood / wellness / habit tracker
        let isMood = lower.contains("mood") || lower.contains("feeling") || lower.contains("emotion") || lower.contains("wellness")
        let isHabit = lower.contains("habit") || lower.contains("routine") || lower.contains("daily") || lower.contains("tracker")
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

        // Checklist / todo
        if lower.contains("checklist") || lower.contains("todo") || lower.contains("to-do") || lower.contains("task list") {
            let checklist = ComponentConfig(type: .checklist)
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

        // Journal / note / diary
        if lower.contains("journal") || lower.contains("diary") || lower.contains("note") || lower.contains("memo") {
            let note = ComponentConfig(type: .note)
            note.content = prompt
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

        return nil
    }

    private func heuristicMultiCityTimeWeatherWidget(
        for prompt: String,
        normalizedPrompt: String,
        theme: WidgetTheme,
        context: PromptContext
    ) -> WidgetConfig? {
        let asksTime = normalizedPrompt.contains("time") || normalizedPrompt.contains("clock")
        let asksWeather = normalizedPrompt.contains("weather") || normalizedPrompt.contains("wether")
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
