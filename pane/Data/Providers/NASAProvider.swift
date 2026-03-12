import Foundation

struct NASAProvider {
    // NASA APOD — free, DEMO_KEY works for low-volume usage
    private let apiKey = "DEMO_KEY"

    func fetchAPOD() async throws -> NASAAPODSnapshot {
        let url = URL(string: "https://api.nasa.gov/planetary/apod?api_key=\(apiKey)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(APODResponse.self, from: data)

        return NASAAPODSnapshot(
            title: decoded.title,
            explanation: decoded.explanation,
            imageURL: decoded.hdurl ?? decoded.url,
            date: decoded.date,
            mediaType: decoded.media_type,
            copyright: decoded.copyright,
            updatedAt: Date()
        )
    }
}

private struct APODResponse: Codable {
    let title: String
    let explanation: String
    let url: String
    let hdurl: String?
    let date: String
    let media_type: String
    let copyright: String?
}
