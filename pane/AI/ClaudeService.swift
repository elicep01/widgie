import Foundation

struct ClaudeService: AIProviderClient {
    let apiKey: String
    let model: String
    let session: URLSession

    init(apiKey: String, model: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    func generateJSON(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIWidgetServiceError.requestFailed("Invalid Claude URL")
        }

        let requestBody = ClaudeRequest(
            model: model,
            maxTokens: 1400,
            temperature: 0.2,
            system: systemPrompt,
            messages: [
                ClaudeMessage(role: "user", content: userPrompt)
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 75
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw AIWidgetServiceError.requestFailed("Timed out while waiting for Claude response.")
        } catch {
            throw AIWidgetServiceError.requestFailed(error.localizedDescription)
        }
        try validateHTTP(response: response, data: data, provider: "Claude")

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIWidgetServiceError.providerReturnedNoContent
        }

        return text
    }

    private func validateHTTP(response: URLResponse, data: Data, provider: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIWidgetServiceError.requestFailed("\(provider) response was not HTTP")
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AIWidgetServiceError.requestFailed("\(provider) HTTP \(http.statusCode): \(body)")
        }
    }
}

private struct ClaudeRequest: Encodable {
    var model: String
    var maxTokens: Int
    var temperature: Double
    var system: String
    var messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case temperature
        case system
        case messages
    }
}

private struct ClaudeMessage: Codable {
    var role: String
    var content: String
}

private struct ClaudeResponse: Decodable {
    struct Content: Decodable {
        let type: String
        let text: String?
    }

    let content: [Content]
}
