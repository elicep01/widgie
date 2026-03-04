import Foundation

struct AgentWebSearchResult: Equatable {
    let provider: String
    let title: String
    let url: String
    let snippet: String
}

protocol AgentWebSearchConnector {
    func search(query: String, limit: Int) async throws -> [AgentWebSearchResult]
}

struct NoopAgentWebSearchConnector: AgentWebSearchConnector {
    func search(query: String, limit: Int) async throws -> [AgentWebSearchResult] {
        []
    }
}

struct LiveAgentWebSearchConnector: AgentWebSearchConnector {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, limit: Int) async throws -> [AgentWebSearchResult] {
        let safeLimit = max(1, min(limit, 5))
        let duckduckgo = try await searchDuckDuckGo(query: query, limit: safeLimit)
        if !duckduckgo.isEmpty {
            return duckduckgo
        }
        return try await searchWikipedia(query: query, limit: safeLimit)
    }

    private func searchDuckDuckGo(query: String, limit: Int) async throws -> [AgentWebSearchResult] {
        var components = URLComponents(string: "https://api.duckduckgo.com/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "no_html", value: "1"),
            URLQueryItem(name: "no_redirect", value: "1"),
            URLQueryItem(name: "skip_disambig", value: "1")
        ]
        guard let url = components.url else { return [] }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            return []
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var results: [AgentWebSearchResult] = []

        if let abstract = object["AbstractText"] as? String,
           !abstract.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let abstractURL = object["AbstractURL"] as? String {
            let heading = (object["Heading"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            results.append(
                AgentWebSearchResult(
                    provider: "DuckDuckGo",
                    title: heading?.isEmpty == false ? heading! : "DuckDuckGo Result",
                    url: abstractURL,
                    snippet: abstract
                )
            )
        }

        if let related = object["RelatedTopics"] as? [[String: Any]] {
            for entry in related {
                if results.count >= limit { break }
                if let text = entry["Text"] as? String,
                   let firstURL = entry["FirstURL"] as? String {
                    results.append(
                        AgentWebSearchResult(
                            provider: "DuckDuckGo",
                            title: titleFromSnippet(text),
                            url: firstURL,
                            snippet: text
                        )
                    )
                    continue
                }

                if let topics = entry["Topics"] as? [[String: Any]] {
                    for nested in topics where results.count < limit {
                        guard let text = nested["Text"] as? String,
                              let firstURL = nested["FirstURL"] as? String else { continue }
                        results.append(
                            AgentWebSearchResult(
                                provider: "DuckDuckGo",
                                title: titleFromSnippet(text),
                                url: firstURL,
                                snippet: text
                            )
                        )
                    }
                }
            }
        }

        return Array(results.prefix(limit))
    }

    private func searchWikipedia(query: String, limit: Int) async throws -> [AgentWebSearchResult] {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "opensearch"),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "namespace", value: "0"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else { return [] }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            return []
        }

        guard let payload = try JSONSerialization.jsonObject(with: data) as? [Any],
              payload.count >= 4,
              let titles = payload[1] as? [String],
              let snippets = payload[2] as? [String],
              let links = payload[3] as? [String] else {
            return []
        }

        var results: [AgentWebSearchResult] = []
        let count = min(limit, titles.count, snippets.count, links.count)
        for idx in 0..<count {
            results.append(
                AgentWebSearchResult(
                    provider: "Wikipedia",
                    title: titles[idx],
                    url: links[idx],
                    snippet: snippets[idx]
                )
            )
        }
        return results
    }

    private func titleFromSnippet(_ text: String) -> String {
        if let range = text.range(of: " - ") {
            return String(text[..<range.lowerBound])
        }
        return text
    }
}
