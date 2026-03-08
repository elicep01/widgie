import Foundation

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
    var topApps: [ScreenTimeAppSnapshot]
    var isAvailable: Bool
    var updatedAt: Date
}

struct ScreenTimeAppSnapshot: Codable, Identifiable {
    var id: String
    var name: String
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
