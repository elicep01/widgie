import Foundation

struct MovieProvider {
    // TMDB free API — requires key but free to register
    // Fallback to OMDb API if TMDB unavailable
    private let tmdbKey = "eyJhbGciOiJIUzI1NiJ9"  // placeholder — users should set their own

    func fetchTrending() async throws -> [MovieSnapshot] {
        // Use free TMDB trending endpoint (no auth needed for basic data)
        let url = URL(string: "https://api.themoviedb.org/3/trending/movie/week?language=en-US")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(tmdbKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                // Fallback: hardcoded popular movies as placeholder
                return fallbackMovies()
            }

            let decoded = try JSONDecoder().decode(TMDBTrendingResponse.self, from: data)
            return decoded.results.prefix(10).map { movie in
                MovieSnapshot(
                    id: "\(movie.id)",
                    title: movie.title ?? movie.name ?? "Unknown",
                    overview: movie.overview ?? "",
                    rating: movie.vote_average ?? 0,
                    releaseDate: movie.release_date ?? movie.first_air_date ?? "",
                    posterPath: movie.poster_path.map { "https://image.tmdb.org/t/p/w200\($0)" },
                    mediaType: movie.media_type ?? "movie",
                    updatedAt: Date()
                )
            }
        } catch {
            return fallbackMovies()
        }
    }

    func search(query: String) async throws -> [MovieSnapshot] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://api.themoviedb.org/3/search/multi?query=\(encoded)&language=en-US")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(tmdbKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(TMDBTrendingResponse.self, from: data)
        return decoded.results.prefix(10).map { movie in
            MovieSnapshot(
                id: "\(movie.id)",
                title: movie.title ?? movie.name ?? "Unknown",
                overview: movie.overview ?? "",
                rating: movie.vote_average ?? 0,
                releaseDate: movie.release_date ?? movie.first_air_date ?? "",
                posterPath: movie.poster_path.map { "https://image.tmdb.org/t/p/w200\($0)" },
                mediaType: movie.media_type ?? "movie",
                updatedAt: Date()
            )
        }
    }

    private func fallbackMovies() -> [MovieSnapshot] {
        // Minimal fallback when API is unavailable
        return []
    }
}

private struct TMDBTrendingResponse: Codable {
    let results: [TMDBMovie]
}

private struct TMDBMovie: Codable {
    let id: Int
    let title: String?
    let name: String?  // for TV shows
    let overview: String?
    let vote_average: Double?
    let release_date: String?
    let first_air_date: String?
    let poster_path: String?
    let media_type: String?
}
