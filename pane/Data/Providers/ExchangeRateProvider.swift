import Foundation

struct ExchangeRateProvider {
    func fetch(base: String, targets: [String]) async throws -> ExchangeRateSnapshot {
        let baseCurrency = base.uppercased()
        let targetList = targets.map { $0.uppercased() }.joined(separator: ",")

        var components = URLComponents(string: "https://api.exchangerate.host/latest")!
        components.queryItems = [
            URLQueryItem(name: "base", value: baseCurrency),
            URLQueryItem(name: "symbols", value: targetList)
        ]

        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            // Fallback to frankfurter.app (also free, no key)
            return try await fetchFromFrankfurter(base: baseCurrency, targets: targets)
        }

        let decoded = try JSONDecoder().decode(ExchangeHostResponse.self, from: data)
        let rates = decoded.rates.map { ExchangeRateEntry(currency: $0.key, rate: $0.value) }
            .sorted { $0.currency < $1.currency }

        return ExchangeRateSnapshot(
            base: baseCurrency,
            rates: rates,
            updatedAt: Date()
        )
    }

    private func fetchFromFrankfurter(base: String, targets: [String]) async throws -> ExchangeRateSnapshot {
        let targetList = targets.map { $0.uppercased() }.joined(separator: ",")
        let url = URL(string: "https://api.frankfurter.app/latest?from=\(base)&to=\(targetList)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
        let rates = decoded.rates.map { ExchangeRateEntry(currency: $0.key, rate: $0.value) }
            .sorted { $0.currency < $1.currency }

        return ExchangeRateSnapshot(
            base: base,
            rates: rates,
            updatedAt: Date()
        )
    }
}

private struct ExchangeHostResponse: Codable {
    let base: String
    let rates: [String: Double]
}

private struct FrankfurterResponse: Codable {
    let base: String
    let rates: [String: Double]
}
