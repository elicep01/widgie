import Foundation

struct CorrectionService {
    private let promptBuilder: PromptBuilder
    private let validator: SchemaValidator

    init(promptBuilder: PromptBuilder, validator: SchemaValidator) {
        self.promptBuilder = promptBuilder
        self.validator = validator
    }

    func correct(
        originalPrompt: String,
        currentConfig: WidgetConfig,
        verificationIssues: [String],
        client: AIProviderClient
    ) async throws -> WidgetConfig {
        let systemPrompt = promptBuilder.correctionSystemPrompt()
        let userPrompt = promptBuilder.correctionUserPrompt(
            originalPrompt: originalPrompt,
            currentConfig: currentConfig,
            verificationIssues: verificationIssues
        )

        let response = try await client.generateJSON(systemPrompt: systemPrompt, userPrompt: userPrompt)
        return try validator.parseAndValidateWidgetConfig(from: response)
    }
}
