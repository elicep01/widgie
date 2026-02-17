import Foundation

struct CryptoProvider {
    func fetch(symbol: String, currency: String) async throws -> MarketSnapshot {
        let normalizedSymbol = symbol.uppercased()
        let coingeckoID = mapToCoinID(symbol: normalizedSymbol)
        let quoteCurrency = currency.lowercased()

        var priceComponents = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")!
        priceComponents.queryItems = [
            URLQueryItem(name: "ids", value: coingeckoID),
            URLQueryItem(name: "vs_currencies", value: quoteCurrency),
            URLQueryItem(name: "include_24hr_change", value: "true")
        ]

        var chartComponents = URLComponents(string: "https://api.coingecko.com/api/v3/coins/\(coingeckoID)/market_chart")!
        chartComponents.queryItems = [
            URLQueryItem(name: "vs_currency", value: quoteCurrency),
            URLQueryItem(name: "days", value: "7")
        ]

        guard let priceURL = priceComponents.url, let chartURL = chartComponents.url else {
            throw URLError(.badURL)
        }

        async let priceResult = URLSession.shared.data(from: priceURL)
        async let chartResult = URLSession.shared.data(from: chartURL)

        let ((priceData, priceResponse), (chartData, chartResponse)) = try await (priceResult, chartResult)
        guard let priceHTTP = priceResponse as? HTTPURLResponse, (200...299).contains(priceHTTP.statusCode),
              let chartHTTP = chartResponse as? HTTPURLResponse, (200...299).contains(chartHTTP.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let priceDecoded = try JSONDecoder().decode([String: [String: Double]].self, from: priceData)
        let chartDecoded = try JSONDecoder().decode(CoinGeckoChartResponse.self, from: chartData)

        let price = priceDecoded[coingeckoID]?[quoteCurrency]
        let changePercent = priceDecoded[coingeckoID]?["\(quoteCurrency)_24h_change"]
        let history = chartDecoded.prices.map { $0[1] }
        let change = (changePercent ?? 0) * (price ?? 0) / 100

        return MarketSnapshot(
            symbol: normalizedSymbol,
            currency: currency.uppercased(),
            price: price,
            change: changePercent == nil ? nil : change,
            changePercent: changePercent,
            history: history,
            updatedAt: Date()
        )
    }

    private func mapToCoinID(symbol: String) -> String {
        switch symbol {
        case "BTC":
            return "bitcoin"
        case "ETH":
            return "ethereum"
        case "SOL":
            return "solana"
        case "DOGE":
            return "dogecoin"
        default:
            return symbol.lowercased()
        }
    }
}

private struct CoinGeckoChartResponse: Decodable {
    var prices: [[Double]]
}
