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
            allowFallbackWidget: false
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
            content: "I couldn't complete AI generation in time. Edit this widget to refine it.\n\nPrompt: \(prompt)",
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

        if promptToken.contains("weather"), !hasWeather {
            return true
        }

        if promptToken.contains("live"), config.refreshInterval > 120 {
            return true
        }

        if (promptToken.contains("clock") || promptToken.contains("time")), !hasTime {
            return true
        }

        return false
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

    private func heuristicCryptoWidget(
        for prompt: String,
        normalizedPrompt: String,
        theme: WidgetTheme
    ) -> WidgetConfig? {
        var symbols: [String] = []
        let mapping: [(String, String)] = [
            ("bitcoin", "BTC"), ("btc", "BTC"),
            ("ethereum", "ETH"), ("eth", "ETH"),
            ("solana", "SOL"), ("sol", "SOL"),
            ("dogecoin", "DOGE"), ("doge", "DOGE"),
            ("cardano", "ADA"), ("ada", "ADA"),
            ("xrp", "XRP"),
            ("litecoin", "LTC"), ("ltc", "LTC")
        ]

        for (token, symbol) in mapping where normalizedPrompt.contains(token) {
            if !symbols.contains(symbol) {
                symbols.append(symbol)
            }
        }

        let mentionsCrypto = normalizedPrompt.contains("crypto")
            || normalizedPrompt.contains("bitcoin")
            || normalizedPrompt.contains("ethereum")

        if symbols.isEmpty, mentionsCrypto {
            symbols = ["BTC", "ETH"]
        }

        // Interpret "bitcoin stock / ethereum stock" as crypto intent.
        if symbols.isEmpty,
           normalizedPrompt.contains("stock"),
           (normalizedPrompt.contains("btc") || normalizedPrompt.contains("eth") || normalizedPrompt.contains("bitcoin") || normalizedPrompt.contains("ethereum")) {
            symbols = ["BTC", "ETH"]
        }

        guard !symbols.isEmpty else {
            return nil
        }

        symbols = Array(symbols.prefix(4))
        var children: [ComponentConfig] = []
        for (index, symbol) in symbols.enumerated() {
            let crypto = ComponentConfig(type: .crypto)
            crypto.symbol = symbol
            crypto.currency = "USD"
            crypto.showPrice = true
            crypto.showChange = true
            crypto.showChart = false
            crypto.color = "primary"
            children.append(crypto)

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

        let width = Double(max(340, min(760, 150 * symbols.count + 80)))
        return WidgetConfig(
            name: "Crypto Live",
            description: prompt,
            size: WidgetSize(width: width, height: 116),
            minSize: nil,
            maxSize: nil,
            theme: theme,
            background: BackgroundConfig.default(for: theme),
            cornerRadius: 20,
            padding: EdgeInsetsConfig(top: 12, bottom: 12, leading: 14, trailing: 14),
            refreshInterval: 60,
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
            ("amazon", "AMZN")
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
