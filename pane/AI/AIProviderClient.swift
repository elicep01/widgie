import Foundation

protocol AIProviderClient {
    func generateJSON(systemPrompt: String, userPrompt: String) async throws -> String
}
