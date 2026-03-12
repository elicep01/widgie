import Foundation

@MainActor
final class ProviderBackedAIService: AIWidgetService {
    private enum ClientStage {
        case generation
        case verification
    }

    private let settingsStore: SettingsStore
    private let rateLimiter: AIRateLimiter
    private let pipeline: GenerationPipeline
    let learnedExampleStore: LearnedExampleStore
    let userPreferenceStore: UserPreferenceStore

    init(
        settingsStore: SettingsStore,
        promptBuilder: PromptBuilder = PromptBuilder(),
        validator: SchemaValidator = SchemaValidator(),
        rateLimiter: AIRateLimiter? = nil,
        pipeline: GenerationPipeline? = nil,
        learnedExampleStore: LearnedExampleStore? = nil
    ) {
        self.settingsStore = settingsStore
        self.rateLimiter = rateLimiter ?? .shared
        self.learnedExampleStore = learnedExampleStore ?? LearnedExampleStore()
        self.userPreferenceStore = UserPreferenceStore()
        self.pipeline = pipeline ?? GenerationPipeline(
            promptBuilder: promptBuilder,
            validator: validator,
            callTimeoutSeconds: 90.0,   // reasoning models (o3-mini, o1) need up to 60–90s to think
            totalPipelineTimeoutSeconds: 300.0
        )
    }

    func generateWidget(prompt: String) async throws -> WidgetConfig {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIWidgetServiceError.invalidPrompt
        }

        try rateLimiter.reservePipelineRun()
        let generationClient = try activeClient(for: .generation)
        let verificationClient = try activeClient(for: .verification)

        return try await pipeline.generate(
            prompt: trimmed,
            defaultTheme: settingsStore.defaultTheme,
            context: promptContext(),
            generationClient: generationClient,
            verificationClient: verificationClient,
            extraExamples: learnedExampleStore.examples,
            userStyleProfile: userPreferenceStore.styleProfile
        )
    }

    func editWidget(existingConfig: WidgetConfig, editPrompt: String, conversationHistory: [String] = []) async throws -> WidgetConfig {
        let trimmed = editPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIWidgetServiceError.invalidPrompt
        }

        try rateLimiter.reservePipelineRun()
        let generationClient = try activeClient(for: .generation)
        let verificationClient = try activeClient(for: .verification)

        return try await pipeline.edit(
            existingConfig: existingConfig,
            editPrompt: trimmed,
            defaultTheme: settingsStore.defaultTheme,
            context: promptContext(),
            generationClient: generationClient,
            verificationClient: verificationClient,
            extraExamples: learnedExampleStore.examples,
            userStyleProfile: userPreferenceStore.styleProfile,
            conversationHistory: conversationHistory
        )
    }

    private func promptContext() -> PromptContext {
        let timezoneID = TimeZone.current.identifier
        let location = settingsStore.defaultLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        return PromptContext(
            currentDate: Date(),
            userTimezone: timezoneID,
            userLocation: location.isEmpty ? "Unknown" : location
        )
    }

    private func activeClient(for stage: ClientStage) throws -> AIProviderClient {
        switch settingsStore.selectedProvider {
        case .openAI:
            let key = settingsStore.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw AIWidgetServiceError.missingAPIKey(provider: .openAI)
            }

            let model = stage == .verification
                ? openAIVerificationModel(from: settingsStore.openAIModel)
                : settingsStore.openAIModel
            return OpenAIService(apiKey: key, model: model)

        case .claude:
            let key = settingsStore.claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw AIWidgetServiceError.missingAPIKey(provider: .claude)
            }

            let model = stage == .verification
                ? claudeVerificationModel(from: settingsStore.claudeModel)
                : settingsStore.claudeModel
            return ClaudeService(apiKey: key, model: model)
        }
    }

    /// Returns a lightweight AI client for pre-generation tasks (e.g. clarification).
    /// Uses the same fast/mini model as verification. Does NOT consume a rate-limit run.
    func makeClarificationClient() throws -> AIProviderClient {
        try activeClient(for: .verification)
    }

    private func openAIVerificationModel(from model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if trimmed.isEmpty { return "gpt-4.1-mini" }
        // o-series reasoning models are too slow/expensive for the fast QA verification pass.
        // Always pair them with the fast GPT-4.1 mini verifier.
        if lower.hasPrefix("o1") || lower.hasPrefix("o3") || lower.hasPrefix("o4") {
            return "gpt-4.1-mini"
        }
        if lower.contains("mini") || lower.contains("nano") { return trimmed }
        if lower.hasPrefix("gpt-5")   { return "gpt-5-mini" }
        if lower.hasPrefix("gpt-4.1") { return "gpt-4.1-mini" }
        if lower.hasPrefix("gpt-4o")  { return "gpt-4o-mini" }
        return "gpt-4.1-mini"
    }

    private func claudeVerificationModel(from model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if trimmed.isEmpty { return "claude-haiku-4-5-20251001" }
        if lower.contains("haiku") { return trimmed }
        // Pair Claude 4 generation models with Claude 4 Haiku for fast, cheap verification
        if lower.hasPrefix("claude-opus-4") || lower.hasPrefix("claude-sonnet-4") {
            return "claude-haiku-4-5-20251001"
        }
        return "claude-haiku-4-5-20251001"
    }
}
