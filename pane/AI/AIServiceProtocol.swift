import Foundation

protocol AIWidgetService {
    func generateWidget(prompt: String) async throws -> WidgetConfig
    func editWidget(existingConfig: WidgetConfig, editPrompt: String) async throws -> WidgetConfig
}

enum AIWidgetServiceError: LocalizedError {
    case invalidPrompt
    case missingAPIKey(provider: AIProvider)
    case responseParsingFailed
    case providerReturnedNoContent
    case requestFailed(String)
    case schemaValidationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPrompt:
            return "Prompt is empty."
        case .missingAPIKey(let provider):
            return "\(provider.displayName) API key is missing. Configure it in Settings."
        case .responseParsingFailed:
            return "Provider response could not be parsed."
        case .providerReturnedNoContent:
            return "Provider returned no content."
        case .requestFailed(let message):
            return "Provider request failed: \(message)"
        case .schemaValidationFailed(let message):
            return "Schema validation failed: \(message)"
        }
    }
}
