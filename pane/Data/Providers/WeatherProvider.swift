import Foundation
import CoreLocation

struct WeatherProvider {
    func fetch(location: String, fahrenheit: Bool) async throws -> WeatherSnapshot {
        let resolvedLocation = try await WeatherGeocoder.shared.resolve(location: location)
        let unit = fahrenheit ? "fahrenheit" : "celsius"
        let symbol = fahrenheit ? "°F" : "°C"

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(resolvedLocation.latitude)"),
            URLQueryItem(name: "longitude", value: "\(resolvedLocation.longitude)"),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "temperature_unit", value: unit),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenMeteoWeatherResponse.self, from: data)
        let condition = weatherDescription(code: decoded.current.weatherCode)
        let icon = weatherSymbol(code: decoded.current.weatherCode)

        return WeatherSnapshot(
            location: resolvedLocation.displayName,
            temperature: decoded.current.temperature2m,
            condition: condition,
            conditionSymbol: icon,
            high: decoded.daily.temperatureMax.first,
            low: decoded.daily.temperatureMin.first,
            humidity: decoded.current.humidity,
            windSpeed: decoded.current.windSpeed,
            feelsLike: decoded.current.apparentTemperature,
            unitSymbol: symbol,
            updatedAt: Date()
        )
    }

    private func weatherDescription(code: Int) -> String {
        switch code {
        case 0:
            return "Clear"
        case 1, 2, 3:
            return "Partly Cloudy"
        case 45, 48:
            return "Fog"
        case 51, 53, 55, 56, 57:
            return "Drizzle"
        case 61, 63, 65, 66, 67:
            return "Rain"
        case 71, 73, 75, 77:
            return "Snow"
        case 80, 81, 82:
            return "Showers"
        case 95, 96, 99:
            return "Thunderstorm"
        default:
            return "Unknown"
        }
    }

    private func weatherSymbol(code: Int) -> String {
        switch code {
        case 0:
            return "sun.max.fill"
        case 1, 2, 3:
            return "cloud.sun.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "cloud.rain.fill"
        case 71, 73, 75, 77:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }
}

private struct ResolvedWeatherLocation: Sendable {
    let latitude: Double
    let longitude: Double
    let displayName: String
}

private actor WeatherGeocoder {
    static let shared = WeatherGeocoder()

    private let geocoder = CLGeocoder()
    private var cache: [String: ResolvedWeatherLocation] = [:]

    func resolve(location: String) async throws -> ResolvedWeatherLocation {
        let normalized = normalizedQuery(location)
        guard !normalized.isEmpty else {
            throw URLError(.badURL)
        }

        if let cached = cache[normalized] {
            return cached
        }

        for query in queryVariants(from: normalized) {
            if let cached = cache[query] {
                cache[normalized] = cached
                return cached
            }

            // Prefer API geocoding first; avoids CLGeocoder cancellation edge cases.
            if let resolved = try await geocodeWithOpenMeteo(query) {
                cache[normalized] = resolved
                cache[query] = resolved
                return resolved
            }

            if let resolved = try await geocodeWithCoreLocation(query) {
                cache[normalized] = resolved
                cache[query] = resolved
                return resolved
            }
        }

        throw URLError(.resourceUnavailable)
    }

    private func geocodeWithCoreLocation(_ query: String) async throws -> ResolvedWeatherLocation? {
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.geocodeAddressString(query)
        } catch {
            return nil
        }

        guard let placemark = placemarks.first,
              let location = placemark.location else {
            return nil
        }

        let displayParts = [
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ]
            .compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let displayName = displayParts.isEmpty ? query : displayParts.joined(separator: ", ")

        return ResolvedWeatherLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            displayName: displayName
        )
    }

    private func geocodeWithOpenMeteo(_ query: String) async throws -> ResolvedWeatherLocation? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenMeteoGeoResponse.self, from: data)
        guard let first = decoded.results?.first else {
            return nil
        }

        let displayParts = [first.name, first.admin1, first.country]
            .compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let displayName = displayParts.isEmpty ? query : displayParts.joined(separator: ", ")

        return ResolvedWeatherLocation(
            latitude: first.latitude,
            longitude: first.longitude,
            displayName: displayName
        )
    }

    private func normalizedQuery(_ query: String) -> String {
        query
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func queryVariants(from normalized: String) -> [String] {
        var variants: [String] = [normalized]

        let commaParts = normalized
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if commaParts.count > 1 {
            for count in stride(from: commaParts.count - 1, through: 1, by: -1) {
                variants.append(commaParts.prefix(count).joined(separator: ", "))
            }
        }

        let noCommas = normalized.replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !noCommas.isEmpty {
            variants.append(noCommas)
        }

        var seen = Set<String>()
        var unique: [String] = []
        for variant in variants {
            let canonical = variant.lowercased()
            if seen.insert(canonical).inserted {
                unique.append(variant)
            }
        }
        return unique
    }
}

private struct OpenMeteoGeoResponse: Decodable {
    struct Result: Decodable {
        var name: String?
        var admin1: String?
        var country: String?
        var latitude: Double
        var longitude: Double
    }

    var results: [Result]?
}

private struct OpenMeteoWeatherResponse: Decodable {
    struct Current: Decodable {
        var temperature2m: Double?
        var humidity: Double?
        var apparentTemperature: Double?
        var windSpeed: Double?
        var weatherCode: Int

        private enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case humidity = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case windSpeed = "wind_speed_10m"
            case weatherCode = "weather_code"
        }
    }

    struct Daily: Decodable {
        var temperatureMax: [Double]
        var temperatureMin: [Double]

        private enum CodingKeys: String, CodingKey {
            case temperatureMax = "temperature_2m_max"
            case temperatureMin = "temperature_2m_min"
        }
    }

    var timezone: String?
    var current: Current
    var daily: Daily
}
