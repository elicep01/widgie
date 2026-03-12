import Foundation

struct JokeProvider {
    func fetch(category: String? = nil) async throws -> JokeSnapshot {
        var urlString = "https://v2.jokeapi.dev/joke/Any?blacklistFlags=nsfw,racist,sexist,explicit"
        if let cat = category, !cat.isEmpty {
            urlString = "https://v2.jokeapi.dev/joke/\(cat)?blacklistFlags=nsfw,racist,sexist,explicit"
        }
        let url = URL(string: urlString)!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(JokeAPIResponse.self, from: data)

        let jokeText: String
        if decoded.type == "twopart" {
            jokeText = "\(decoded.setup ?? "")\n\(decoded.delivery ?? "")"
        } else {
            jokeText = decoded.joke ?? "No joke found"
        }

        return JokeSnapshot(
            text: jokeText,
            category: decoded.category,
            type: decoded.type,
            updatedAt: Date()
        )
    }
}

private struct JokeAPIResponse: Codable {
    let type: String
    let joke: String?
    let setup: String?
    let delivery: String?
    let category: String
}
