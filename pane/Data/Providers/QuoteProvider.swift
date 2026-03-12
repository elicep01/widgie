import Foundation

struct QuoteProvider {
    func fetch() async throws -> QuoteSnapshot {
        let url = URL(string: "https://api.quotable.io/quotes/random?limit=1")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode([QuotableResponse].self, from: data)
        guard let first = decoded.first else { throw URLError(.cannotParseResponse) }

        return QuoteSnapshot(
            text: first.content,
            author: first.author,
            tags: first.tags,
            updatedAt: Date()
        )
    }
}

private struct QuotableResponse: Codable {
    let content: String
    let author: String
    let tags: [String]
}
