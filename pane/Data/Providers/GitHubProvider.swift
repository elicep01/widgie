import Foundation

struct GitHubProvider {
    func fetch(repo: String) async throws -> GitHubRepoSnapshot {
        let normalized = normalizeRepoSource(repo)
        guard let url = URL(string: "https://api.github.com/repos/\(normalized)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        // GitHub API requires a User-Agent header — requests without it get 403 Forbidden.
        request.setValue("widgie-widget-app/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(GitHubRepoResponse.self, from: data)
        return GitHubRepoSnapshot(
            fullName: decoded.full_name,
            description: decoded.description,
            stars: decoded.stargazers_count,
            forks: decoded.forks_count,
            openIssues: decoded.open_issues_count,
            watchers: decoded.watchers_count,
            language: decoded.language,
            updatedAt: Date()
        )
    }

    private func normalizeRepoSource(_ raw: String) -> String {
        let trailingPunct = CharacterSet(charactersIn: ".,;:!?)\"'")
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: trailingPunct)

        if let parsed = URL(string: trimmed),
           let host = parsed.host?.lowercased(),
           host.contains("github.com") {
            let parts = parsed.pathComponents
                .filter { $0 != "/" }
                .map { $0.trimmingCharacters(in: trailingPunct) }
            if parts.count >= 2 {
                let owner = parts[0]
                var repo = parts[1]
                if repo.hasSuffix(".git") {
                    repo = String(repo.dropLast(4))
                }
                if !owner.isEmpty, !repo.isEmpty {
                    return "\(owner)/\(repo)"
                }
            }
        }

        return trimmed
    }
}

private struct GitHubRepoResponse: Decodable {
    var full_name: String
    var description: String?
    var stargazers_count: Int
    var forks_count: Int
    var open_issues_count: Int
    var watchers_count: Int
    var language: String?
}
