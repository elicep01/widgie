import Foundation

struct StockProvider {
    func fetch(symbol: String, range: String = "7d") async throws -> MarketSnapshot {
        let upper = symbol.uppercased()
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(upper)")!
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: normalizeRange(range))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
        guard let result = decoded.chart.result?.first else {
            throw URLError(.cannotParseResponse)
        }

        let closes = result.indicators.quote.first?.close ?? []
        let history = closes.compactMap { $0 }
        let price = result.meta.regularMarketPrice ?? history.last
        let previousClose = result.meta.chartPreviousClose ?? history.dropLast().last

        let change: Double?
        let changePercent: Double?
        if let price, let previousClose, previousClose != 0 {
            change = price - previousClose
            changePercent = (change ?? 0) / previousClose * 100
        } else {
            change = nil
            changePercent = nil
        }

        return MarketSnapshot(
            symbol: upper,
            currency: result.meta.currency ?? "USD",
            price: price,
            change: change,
            changePercent: changePercent,
            history: history,
            updatedAt: Date()
        )
    }

    private func normalizeRange(_ range: String) -> String {
        switch range.lowercased() {
        case "1d", "5d", "1mo", "3mo", "6mo", "1y":
            return range.lowercased()
        default:
            return "7d"
        }
    }
}

private struct YahooChartResponse: Decodable {
    struct Chart: Decodable {
        struct Result: Decodable {
            struct Meta: Decodable {
                var currency: String?
                var regularMarketPrice: Double?
                var chartPreviousClose: Double?
            }

            struct Indicators: Decodable {
                struct Quote: Decodable {
                    var close: [Double?]
                }

                var quote: [Quote]
            }

            var meta: Meta
            var indicators: Indicators
        }

        var result: [Result]?
    }

    var chart: Chart
}
