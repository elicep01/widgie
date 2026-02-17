import Foundation

struct GenerationPipeline {
    private let promptBuilder: PromptBuilder
    private let validator: SchemaValidator
    private let verificationService: VerificationService
    private let correctionService: CorrectionService
    private let maxTotalCalls = 3
    private let maxGenerationAttempts = 2
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
        let systemPrompt = promptBuilder.generationSystemPrompt(defaultTheme: defaultTheme, context: context)
        let userPrompt = promptBuilder.generationUserPrompt(prompt)

        var config = try await runPipeline(
            originalPrompt: prompt,
            generationSystemPrompt: systemPrompt,
            initialGenerationUserPrompt: userPrompt,
            generationClient: generationClient,
            verificationClient: verificationClient ?? generationClient
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
        let systemPrompt = promptBuilder.generationSystemPrompt(defaultTheme: defaultTheme, context: context)
        let userPrompt = promptBuilder.editUserPrompt(existingConfig: existingConfig, editPrompt: editPrompt)

        var config = try await runPipeline(
            originalPrompt: editPrompt,
            generationSystemPrompt: systemPrompt,
            initialGenerationUserPrompt: userPrompt,
            generationClient: generationClient,
            verificationClient: verificationClient ?? generationClient
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
        verificationClient: AIProviderClient
    ) async throws -> WidgetConfig {
        let deadline = Date().addingTimeInterval(totalPipelineTimeoutSeconds)
        var usedCalls = 0
        var generationUserPrompt = initialGenerationUserPrompt
        var generatedConfig: WidgetConfig?

        for attempt in 0..<maxGenerationAttempts {
            guard usedCalls < maxTotalCalls else {
                throw AIWidgetServiceError.requestFailed("AI call budget exceeded before generation completed.")
            }

            usedCalls += 1
            let generationResponse = try await withTimeout(seconds: remainingSeconds(until: deadline)) {
                try await generationClient.generateJSON(
                    systemPrompt: generationSystemPrompt,
                    userPrompt: generationUserPrompt
                )
            }

            do {
                generatedConfig = try validator.parseAndValidateWidgetConfig(from: generationResponse)
                break
            } catch {
                if attempt == maxGenerationAttempts - 1 {
                    throw error
                }

                generationUserPrompt = promptBuilder.retryUserPrompt(
                    originalPrompt: originalPrompt,
                    previousResponse: generationResponse,
                    validationError: error.localizedDescription
                )
            }
        }

        guard var config = generatedConfig else {
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
            // Generation succeeded; avoid failing the whole UX if the QA pass times out.
            if isTransientStepFailure(error) {
                return config
            }
            throw error
        }

        if verificationResult.passed {
            return config
        }

        guard usedCalls < maxTotalCalls else {
            let issues = verificationResult.issues.joined(separator: "; ")
            throw AIWidgetServiceError.requestFailed("Verification failed: \(issues)")
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
            // If correction fails transiently, show the already-valid generated config.
            if isTransientStepFailure(error) {
                return config
            }
            throw error
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

    private func isTransientStepFailure(_ error: Error) -> Bool {
        guard let serviceError = error as? AIWidgetServiceError else {
            return false
        }

        if case .requestFailed(let message) = serviceError {
            let lower = message.lowercased()
            return lower.contains("timed out")
                || lower.contains("network")
                || lower.contains("connection")
        }

        return false
    }
}
