import Foundation

struct OpenAIService: AIProviderClient {
    let apiKey: String
    let model: String
    let session: URLSession

    init(apiKey: String, model: String, session: URLSession = .shared) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)

        self.apiKey = trimmedKey
        self.model = trimmedModel.isEmpty ? "gpt-4.1-mini" : trimmedModel
        self.session = session
    }

    func generateJSON(systemPrompt: String, userPrompt: String) async throws -> String {
        var lastModelError: Error?
        for candidateModel in candidateModels() {
            do {
                return try await generateJSON(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    model: candidateModel
                )
            } catch {
                if shouldTryAlternateModel(after: error) {
                    lastModelError = error
                    continue
                }
                throw error
            }
        }

        if let lastModelError {
            throw lastModelError
        }

        throw AIWidgetServiceError.requestFailed("OpenAI request failed before a model could produce output.")
    }

    private func generateJSON(systemPrompt: String, userPrompt: String, model: String) async throws -> String {
        let preferChatCompletions = shouldPreferChatCompletions(for: model)

        if preferChatCompletions {
            do {
                return try await generateUsingChatCompletions(systemPrompt: systemPrompt, userPrompt: userPrompt, model: model)
            } catch {
                guard shouldFallbackToResponses(after: error) else {
                    throw error
                }
                return try await generateUsingResponsesAPI(systemPrompt: systemPrompt, userPrompt: userPrompt, model: model)
            }
        }

        do {
            return try await generateUsingResponsesAPI(systemPrompt: systemPrompt, userPrompt: userPrompt, model: model)
        } catch {
            guard shouldFallbackToChatCompletions(after: error) else {
                throw error
            }
            return try await generateUsingChatCompletions(systemPrompt: systemPrompt, userPrompt: userPrompt, model: model)
        }
    }

    private func generateUsingResponsesAPI(systemPrompt: String, userPrompt: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw AIWidgetServiceError.requestFailed("Invalid OpenAI Responses URL")
        }

        let requestBody = OpenAIResponsesRequest(
            model: model,
            maxOutputTokens: 1200,
            input: [
                OpenAIResponsesInputMessage(
                    role: "system",
                    content: [OpenAIResponsesInputContent(type: "input_text", text: systemPrompt)]
                ),
                OpenAIResponsesInputMessage(
                    role: "user",
                    content: [OpenAIResponsesInputContent(type: "input_text", text: userPrompt)]
                )
            ]
        )

        let data = try await performRequest(url: url, requestBody: requestBody, provider: "OpenAI Responses")
        let decoded: OpenAIResponsesResponse
        do {
            decoded = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        } catch {
            throw AIWidgetServiceError.responseParsingFailed
        }

        if let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !outputText.isEmpty {
            return outputText
        }

        for item in decoded.output ?? [] {
            for content in item.content ?? [] {
                guard let text = content.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else {
                    continue
                }
                return text
            }
        }

        throw AIWidgetServiceError.providerReturnedNoContent
    }

    private func generateUsingChatCompletions(systemPrompt: String, userPrompt: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIWidgetServiceError.requestFailed("Invalid OpenAI Chat Completions URL")
        }

        let requestBody = OpenAIChatRequest(
            model: model,
            temperature: 0.2,
            maxTokens: 1200,
            messages: [
                OpenAIChatMessage(role: "system", content: systemPrompt),
                OpenAIChatMessage(role: "user", content: userPrompt)
            ]
        )

        let data = try await performRequest(url: url, requestBody: requestBody, provider: "OpenAI")
        let decoded: OpenAIResponse
        do {
            decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            throw AIWidgetServiceError.responseParsingFailed
        }
        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIWidgetServiceError.providerReturnedNoContent
        }

        return content
    }

    private func shouldFallbackToChatCompletions(after error: Error) -> Bool {
        guard let serviceError = error as? AIWidgetServiceError else {
            return false
        }

        switch serviceError {
        case .providerReturnedNoContent, .responseParsingFailed:
            return true
        case .requestFailed(let message):
            let lower = message.lowercased()
            return lower.contains("openai responses http 400")
                || lower.contains("openai responses http 404")
                || lower.contains("openai responses http 405")
                || lower.contains("timed out while waiting for openai responses")
                || lower.contains("network connection was lost")
                || lower.contains("could not connect to the server")
                || lower.contains("request timed out")
        default:
            return false
        }
    }

    private func shouldFallbackToResponses(after error: Error) -> Bool {
        guard let serviceError = error as? AIWidgetServiceError else {
            return false
        }

        switch serviceError {
        case .providerReturnedNoContent, .responseParsingFailed:
            return true
        case .requestFailed(let message):
            let lower = message.lowercased()
            return lower.contains("openai http 400")
                || lower.contains("openai http 404")
                || lower.contains("openai http 405")
                || lower.contains("timed out while waiting for openai")
                || lower.contains("network connection was lost")
                || lower.contains("could not connect to the server")
                || lower.contains("request timed out")
        default:
            return false
        }
    }

    private func shouldTryAlternateModel(after error: Error) -> Bool {
        guard let serviceError = error as? AIWidgetServiceError else {
            return false
        }

        guard case .requestFailed(let message) = serviceError else {
            return false
        }

        let lower = message.lowercased()
        let looksLikeModelError = lower.contains("model")
            || lower.contains("unsupported")
            || lower.contains("not found")
            || lower.contains("does not exist")
            || lower.contains("not available")
            || lower.contains("doesn't support")
        let looksTransient = lower.contains("timed out")
            || lower.contains("network")
            || lower.contains("connection")
            || lower.contains("could not connect")

        guard looksLikeModelError || looksTransient else {
            return false
        }

        return lower.contains("http 400")
            || lower.contains("http 404")
            || lower.contains("http 422")
            || looksTransient
    }

    private func candidateModels() -> [String] {
        let requested = model.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [String] = []

        if !requested.isEmpty {
            candidates.append(requested)
        }

        for fallback in ["gpt-5", "gpt-5-mini", "gpt-4.1", "gpt-4.1-mini", "gpt-4o", "gpt-4o-mini"] {
            if fallback.caseInsensitiveCompare(requested) != .orderedSame {
                candidates.append(fallback)
            }
        }

        var seen = Set<String>()
        return candidates.filter { candidate in
            let key = candidate.lowercased()
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    private func shouldPreferChatCompletions(for model: String) -> Bool {
        let lower = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.isEmpty {
            return true
        }

        // gpt-4.x and gpt-4o variants are generally fast/stable on Chat Completions.
        if lower.hasPrefix("gpt-4") {
            return true
        }

        // Keep gpt-5 family on Responses by default.
        return false
    }

    private func performRequest<RequestBody: Encodable>(
        url: URL,
        requestBody: RequestBody,
        provider: String
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let (data, response) = try await session.data(for: request)
                try validateHTTP(response: response, data: data, provider: provider)
                return data
            } catch let urlError as URLError where urlError.code == .timedOut {
                lastError = AIWidgetServiceError.requestFailed("Timed out while waiting for \(provider) response.")
            } catch {
                lastError = AIWidgetServiceError.requestFailed(error.localizedDescription)
            }

            if attempt == 0 {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }

        throw lastError ?? AIWidgetServiceError.requestFailed("Unknown request failure for \(provider).")
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

private struct OpenAIChatRequest: Encodable {
    var model: String
    var temperature: Double
    var maxTokens: Int?
    var messages: [OpenAIChatMessage]

    private enum CodingKeys: String, CodingKey {
        case model
        case temperature
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct OpenAIChatMessage: Codable {
    var role: String
    var content: String
}

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        let message: OpenAIChatMessage
    }

    let choices: [Choice]
}

private struct OpenAIResponsesRequest: Encodable {
    let model: String
    let maxOutputTokens: Int?
    let input: [OpenAIResponsesInputMessage]

    private enum CodingKeys: String, CodingKey {
        case model
        case maxOutputTokens = "max_output_tokens"
        case input
    }
}

private struct OpenAIResponsesInputMessage: Encodable {
    let role: String
    let content: [OpenAIResponsesInputContent]
}

private struct OpenAIResponsesInputContent: Encodable {
    let type: String
    let text: String
}

private struct OpenAIResponsesResponse: Decodable {
    struct OutputItem: Decodable {
        let content: [OutputContent]?
    }

    struct OutputContent: Decodable {
        let text: String?
    }

    let output: [OutputItem]?
    let outputText: String?

    private enum CodingKeys: String, CodingKey {
        case output
        case outputText = "output_text"
    }
}
