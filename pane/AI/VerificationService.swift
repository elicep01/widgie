import Foundation

struct VerificationResult {
    let passed: Bool
    let issues: [String]
    let rawResponse: String
}

struct VerificationService {
    private let promptBuilder: PromptBuilder

    init(promptBuilder: PromptBuilder) {
        self.promptBuilder = promptBuilder
    }

    func verify(
        originalPrompt: String,
        generatedConfig: WidgetConfig,
        client: AIProviderClient
    ) async throws -> VerificationResult {
        let systemPrompt = promptBuilder.verificationSystemPrompt()
        let userPrompt = promptBuilder.verificationUserPrompt(
            originalPrompt: originalPrompt,
            generatedConfig: generatedConfig
        )

        let response = try await client.generateJSON(systemPrompt: systemPrompt, userPrompt: userPrompt)
        return parseVerificationResponse(response)
    }

    private func parseVerificationResponse(_ response: String) -> VerificationResult {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.uppercased() == "PASS" {
            return VerificationResult(passed: true, issues: [], rawResponse: response)
        }

        var issues: [String] = []
        for line in trimmed.components(separatedBy: .newlines) {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.isEmpty {
                continue
            }

            if normalized.uppercased().hasPrefix("FAIL") {
                continue
            }

            let withoutBullet = normalized.replacingOccurrences(
                of: #"^[-*\d\.\s]+"#,
                with: "",
                options: .regularExpression
            )
            if !withoutBullet.isEmpty {
                issues.append(withoutBullet)
            }
        }

        if issues.isEmpty {
            issues = ["Verification returned FAIL without specific issues."]
        }

        return VerificationResult(passed: false, issues: issues, rawResponse: response)
    }
}
