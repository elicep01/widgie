import Foundation

struct WeatherForecastDay: Codable {
    var date: Date
    var dayName: String
    var high: Double
    var low: Double
    var conditionSymbol: String
    var condition: String
}

struct WeatherSnapshot: Codable {
    var location: String
    var temperature: Double?
    var condition: String
    var conditionSymbol: String
    var high: Double?
    var low: Double?
    var humidity: Double?
    var windSpeed: Double?
    var feelsLike: Double?
    var unitSymbol: String
    var updatedAt: Date
    var forecast: [WeatherForecastDay]?
}

struct MarketSnapshot: Codable {
    var symbol: String
    var currency: String
    var price: Double?
    var change: Double?
    var changePercent: Double?
    var history: [Double]
    var updatedAt: Date
}

struct CalendarEventSnapshot: Codable, Identifiable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarColorHex: String?
}

struct ReminderSnapshot: Codable, Identifiable {
    var id: String
    var title: String
    var dueDate: Date?
    var isCompleted: Bool
}

struct BatterySnapshot: Codable {
    var percentage: Double?
    var isCharging: Bool
    var isLowPower: Bool
    var updatedAt: Date
}

struct SystemStatsSnapshot: Codable {
    var cpuPercent: Double?
    var memoryPercent: Double?
    var storagePercent: Double?
    var updatedAt: Date
}

struct MusicSnapshot: Codable {
    var title: String?
    var artist: String?
    var album: String?
    var progress: Double?
    var isPlaying: Bool
    var source: String?
    var artworkData: Data?
    var elapsedTime: Double?
    var duration: Double?
    var updatedAt: Date
}

struct NewsHeadlineSnapshot: Codable, Identifiable {
    var id: String
    var title: String
    var source: String?
    var link: String?
    var publishedAt: Date?
}

struct ScreenTimeSnapshot: Codable {
    var total: String
    var totalSeconds: TimeInterval
    var topApps: [ScreenTimeAppSnapshot]
    var isAvailable: Bool
    var updatedAt: Date
}

struct ScreenTimeAppSnapshot: Codable, Identifiable {
    var id: String
    var name: String
    var category: String
    var durationSeconds: TimeInterval
    var durationText: String
}

struct GitHubRepoSnapshot: Codable {
    var fullName: String
    var description: String?
    var stars: Int
    var forks: Int
    var openIssues: Int
    var watchers: Int
    var language: String?
    var updatedAt: Date
}

// MARK: - Quote

struct QuoteSnapshot: Codable {
    var text: String
    var author: String
    var tags: [String]
    var updatedAt: Date
}

// MARK: - Joke

struct JokeSnapshot: Codable {
    var text: String
    var category: String
    var type: String
    var updatedAt: Date
}

// MARK: - Exchange Rate

struct ExchangeRateEntry: Codable {
    var currency: String
    var rate: Double
}

struct ExchangeRateSnapshot: Codable {
    var base: String
    var rates: [ExchangeRateEntry]
    var updatedAt: Date
}

// MARK: - Movie / TV

struct MovieSnapshot: Codable, Identifiable {
    var id: String
    var title: String
    var overview: String
    var rating: Double
    var releaseDate: String
    var posterPath: String?
    var mediaType: String
    var updatedAt: Date
}

// MARK: - Sports

struct SportsScoreSnapshot: Codable, Identifiable {
    var id: String
    var league: String
    var homeTeam: String
    var awayTeam: String
    var homeScore: Int?
    var awayScore: Int?
    var status: String
    var dateEvent: String
    var sport: String
    var updatedAt: Date
}

struct SportsTeamSnapshot: Codable {
    var id: String
    var name: String
    var sport: String
    var league: String
    var country: String
    var badgeURL: String?
    var updatedAt: Date
}

// MARK: - NASA APOD

struct NASAAPODSnapshot: Codable {
    var title: String
    var explanation: String
    var imageURL: String
    var date: String
    var mediaType: String
    var copyright: String?
    var updatedAt: Date
}

// MARK: - Dictionary / Word

struct WordDefinition: Codable {
    var partOfSpeech: String
    var definition: String
    var example: String?
}

struct WordSnapshot: Codable {
    var word: String
    var phonetic: String?
    var definitions: [WordDefinition]
    var updatedAt: Date
}
