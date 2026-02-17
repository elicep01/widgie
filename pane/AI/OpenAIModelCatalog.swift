import Foundation

@MainActor
final class OpenAIModelCatalog: ObservableObject {
    @Published private(set) var models: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var lastLoadedKey: String = ""

    func refreshModels(apiKey: String, force: Bool = false) async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            models = []
            errorMessage = nil
            lastLoadedKey = ""
            return
        }

        if !force, trimmed == lastLoadedKey, !models.isEmpty {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await fetchModels(apiKey: trimmed)
            models = fetched
            errorMessage = nil
            lastLoadedKey = trimmed
        } catch {
            models = fallbackModels
            errorMessage = error.localizedDescription
            lastLoadedKey = trimmed
        }
    }

    private func fetchModels(apiKey: String) async throws -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw AIWidgetServiceError.requestFailed("Invalid OpenAI models URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIWidgetServiceError.requestFailed("OpenAI models response was not HTTP")
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AIWidgetServiceError.requestFailed("OpenAI models HTTP \(http.statusCode): \(body)")
        }

        let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)

        var ids = decoded.data.map(\.id)
        ids = ids.filter { $0.hasPrefix("gpt-") }
        ids = ids.filter { id in
            let lower = id.lowercased()
            return !lower.contains("realtime")
                && !lower.contains("audio")
                && !lower.contains("tts")
                && !lower.contains("whisper")
                && !lower.contains("image")
                && !lower.contains("embedding")
                && !lower.contains("moderation")
        }

        let uniqueSorted = Array(Set(ids)).sorted(by: modelSort)
        return uniqueSorted.isEmpty ? fallbackModels : uniqueSorted
    }

    private func modelSort(lhs: String, rhs: String) -> Bool {
        let leftPriority = modelPriority(lhs)
        let rightPriority = modelPriority(rhs)

        if leftPriority == rightPriority {
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return leftPriority < rightPriority
    }

    private func modelPriority(_ model: String) -> Int {
        switch model {
        case "gpt-5": return 0
        case "gpt-5-mini": return 1
        case "gpt-4.1": return 2
        case "gpt-4.1-mini": return 3
        case "gpt-4o": return 4
        case "gpt-4o-mini": return 5
        default: return 100
        }
    }

    private var fallbackModels: [String] {
        ["gpt-5", "gpt-5-mini", "gpt-4.1", "gpt-4.1-mini", "gpt-4o", "gpt-4o-mini"]
    }
}

private struct ModelListResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}
