import Foundation

actor DataServiceManager {
    static let shared = DataServiceManager()

    private let cache = CacheManager()
    private let weatherProvider = WeatherProvider()
    private let stockProvider = StockProvider()
    private let cryptoProvider = CryptoProvider()
    private let batteryProvider = BatteryProvider()
    private let systemStatsProvider = SystemStatsProvider()
    private let musicProvider = MusicProvider()
    private let rssProvider = RSSProvider()
    private let screenTimeProvider = ScreenTimeProvider.shared
    private let gitHubProvider = GitHubProvider()
    private let quoteProvider = QuoteProvider()
    private let jokeProvider = JokeProvider()
    private let exchangeRateProvider = ExchangeRateProvider()
    private let movieProvider = MovieProvider()
    private let sportsProvider = SportsProvider()
    private let nasaProvider = NASAProvider()
    private let dictionaryProvider = DictionaryProvider()

    func weather(location: String, fahrenheit: Bool, forceRefresh: Bool = false) async -> WeatherSnapshot? {
        let normalizedLocation = location
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "weather_\(normalizedLocation.lowercased())_\(fahrenheit)"
        if !forceRefresh, let cached = await cache.load(WeatherSnapshot.self, key: key) {
            return cached
        }

        for attempt in 0..<3 {
            do {
                let value = try await weatherProvider.fetch(location: normalizedLocation, fahrenheit: fahrenheit)
                await cache.store(value, key: key, ttl: 30 * 60)
                return value
            } catch {
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                }
            }
        }
        return await cache.load(WeatherSnapshot.self, key: key)
    }

    func stock(symbol: String, period: String, forceRefresh: Bool = false) async -> MarketSnapshot? {
        let normalized = symbol.uppercased()
        let key = "stock_\(normalized)_\(period)"
        if !forceRefresh, let cached = await cache.load(MarketSnapshot.self, key: key) {
            return cached
        }

        do {
            let value = try await stockProvider.fetch(symbol: normalized, range: period)
            await cache.store(value, key: key, ttl: 60)
            return value
        } catch {
            return await cache.load(MarketSnapshot.self, key: key)
        }
    }

    func crypto(symbol: String, currency: String, forceRefresh: Bool = false) async -> MarketSnapshot? {
        let normalized = symbol.uppercased()
        let normalizedCurrency = currency.uppercased()
        let key = "crypto_\(normalized)_\(normalizedCurrency)"
        if !forceRefresh, let cached = await cache.load(MarketSnapshot.self, key: key) {
            return cached
        }

        do {
            let value = try await cryptoProvider.fetch(symbol: normalized, currency: normalizedCurrency)
            await cache.store(value, key: key, ttl: 2 * 60)
            return value
        } catch {
            return await cache.load(MarketSnapshot.self, key: key)
        }
    }

    @MainActor
    func calendarNext(maxEvents: Int, timeRange: String, forceRefresh: Bool = false) async -> [CalendarEventSnapshot] {
        let calendarProvider = CalendarProvider()
        let key = "calendar_\(maxEvents)_\(timeRange)"
        if !forceRefresh, let cached = await cache.load([CalendarEventSnapshot].self, key: key) {
            return cached
        }

        let value = await calendarProvider.fetch(maxEvents: maxEvents, timeRange: timeRange)
        await cache.store(value, key: key, ttl: 5 * 60)
        return value
    }

    @MainActor
    func reminders(maxItems: Int, forceRefresh: Bool = false) async -> [ReminderSnapshot] {
        let reminderProvider = ReminderProvider()
        let key = "reminders_\(maxItems)"
        if !forceRefresh, let cached = await cache.load([ReminderSnapshot].self, key: key) {
            return cached
        }

        let value = await reminderProvider.fetch(maxItems: maxItems)
        await cache.store(value, key: key, ttl: 5 * 60)
        return value
    }

    func battery(forceRefresh: Bool = false) async -> BatterySnapshot {
        let key = "battery"
        if !forceRefresh, let cached = await cache.load(BatterySnapshot.self, key: key) {
            return cached
        }

        let value = batteryProvider.fetch()
        await cache.store(value, key: key, ttl: 60)
        return value
    }

    func systemStats(forceRefresh: Bool = false) async -> SystemStatsSnapshot {
        let key = "system_stats"
        if !forceRefresh, let cached = await cache.load(SystemStatsSnapshot.self, key: key) {
            return cached
        }

        let value = systemStatsProvider.fetch()
        await cache.store(value, key: key, ttl: 30)
        return value
    }

    func musicNowPlaying(forceRefresh: Bool = false) async -> MusicSnapshot {
        let key = "music_now_playing"
        if !forceRefresh, let cached = await cache.load(MusicSnapshot.self, key: key) {
            return cached
        }

        let value = await musicProvider.fetch()
        await cache.store(value, key: key, ttl: 1)
        return value
    }

    nonisolated func musicPlayPause() {
        musicProvider.playPause()
    }

    nonisolated func musicNextTrack() {
        musicProvider.nextTrack()
    }

    nonisolated func musicPreviousTrack() {
        musicProvider.previousTrack()
    }

    nonisolated func musicSeek(to position: Double) {
        musicProvider.seek(to: position)
    }

    func news(feedURL: String, maxItems: Int, forceRefresh: Bool = false) async -> [NewsHeadlineSnapshot] {
        let key = "rss_\(feedURL)_\(maxItems)"
        if !forceRefresh, let cached = await cache.load([NewsHeadlineSnapshot].self, key: key) {
            return cached
        }

        do {
            let value = try await rssProvider.fetch(feedURL: feedURL, maxItems: maxItems)
            await cache.store(value, key: key, ttl: 5 * 60)
            return value
        } catch {
            print("[RSS] Failed to fetch \(feedURL): \(error.localizedDescription)")
            return await cache.load([NewsHeadlineSnapshot].self, key: key) ?? []
        }
    }

    func newsMultiFeed(feedURLs: [String], maxPerFeed: Int = 5, totalMax: Int = 20, forceRefresh: Bool = false) async -> [NewsHeadlineSnapshot] {
        let key = "rss_multi_\(feedURLs.sorted().joined(separator: "|"))_\(totalMax)"
        if !forceRefresh, let cached = await cache.load([NewsHeadlineSnapshot].self, key: key) {
            return cached
        }
        let value = await rssProvider.fetchMultiple(feedURLs: feedURLs, maxPerFeed: maxPerFeed, totalMax: totalMax)
        if !value.isEmpty {
            await cache.store(value, key: key, ttl: 5 * 60)
        }
        return value
    }

    func githubRepo(repo: String, forceRefresh: Bool = false) async -> GitHubRepoSnapshot? {
        let key = "github_\(repo.lowercased())"
        if !forceRefresh, let cached = await cache.load(GitHubRepoSnapshot.self, key: key) {
            return cached
        }

        do {
            let value = try await gitHubProvider.fetch(repo: repo)
            await cache.store(value, key: key, ttl: 30 * 60)
            return value
        } catch {
            print("[DataServiceManager] GitHub fetch failed for '\(repo)': \(error)")
            return await cache.load(GitHubRepoSnapshot.self, key: key)
        }
    }

    func screenTime(maxApps: Int, forceRefresh: Bool = false) async -> ScreenTimeSnapshot {
        let key = "screen_time_\(maxApps)"
        if !forceRefresh, let cached = await cache.load(ScreenTimeSnapshot.self, key: key) {
            return cached
        }

        let value = screenTimeProvider.fetch(maxApps: maxApps)
        await cache.store(value, key: key, ttl: 30)
        return value
    }

    func dailyQuote(forceRefresh: Bool = false) async -> QuoteSnapshot? {
        let key = "daily_quote"
        if !forceRefresh, let cached = await cache.load(QuoteSnapshot.self, key: key) {
            return cached
        }

        do {
            let value = try await quoteProvider.fetch()
            await cache.store(value, key: key, ttl: 60 * 60)
            return value
        } catch {
            print("[DataServiceManager] Quote fetch failed: \(error)")
            return await cache.load(QuoteSnapshot.self, key: key)
        }
    }

    func joke(category: String = "Any", forceRefresh: Bool = false) async -> JokeSnapshot? {
        let key = "joke_\(category.lowercased())"
        if !forceRefresh, let cached = await cache.load(JokeSnapshot.self, key: key) {
            return cached
        }

        do {
            let value = try await jokeProvider.fetch(category: category)
            await cache.store(value, key: key, ttl: 5 * 60)
            return value
        } catch {
            print("[DataServiceManager] Joke fetch failed: \(error)")
            return await cache.load(JokeSnapshot.self, key: key)
        }
    }

    func exchangeRate(base: String, targets: [String], forceRefresh: Bool = false) async -> ExchangeRateSnapshot? {
        let normalizedBase = base.uppercased()
        let normalizedTargets = targets.map { $0.uppercased() }.sorted()
        let key = "exchange_\(normalizedBase)_\(normalizedTargets.joined(separator: ","))"
        if !forceRefresh, let cached = await cache.load(ExchangeRateSnapshot.self, key: key) {
            return cached
        }

        do {
            let value = try await exchangeRateProvider.fetch(base: normalizedBase, targets: normalizedTargets)
            await cache.store(value, key: key, ttl: 30 * 60)
            return value
        } catch {
            print("[DataServiceManager] Exchange rate fetch failed: \(error)")
            return await cache.load(ExchangeRateSnapshot.self, key: key)
        }
    }

    func trendingMovies(forceRefresh: Bool = false) async -> [MovieSnapshot] {
        let key = "trending_movies"
        if !forceRefresh, let cached = await cache.load([MovieSnapshot].self, key: key) {
            return cached
        }

        do {
            let value = try await movieProvider.fetchTrending()
            await cache.store(value, key: key, ttl: 60 * 60)
            return value
        } catch {
            print("[DataServiceManager] Trending movies fetch failed: \(error)")
            return await cache.load([MovieSnapshot].self, key: key) ?? []
        }
    }

    func sportsScores(sport: String, forceRefresh: Bool = false) async -> [SportsScoreSnapshot] {
        let key = "sports_\(sport.lowercased())"
        if !forceRefresh, let cached = await cache.load([SportsScoreSnapshot].self, key: key) {
            return cached
        }

        do {
            let value = try await sportsProvider.fetchLiveScores(sport: sport)
            await cache.store(value, key: key, ttl: 5 * 60)
            return value
        } catch {
            print("[DataServiceManager] Sports scores fetch failed: \(error)")
            return await cache.load([SportsScoreSnapshot].self, key: key) ?? []
        }
    }

    func nasaApod(forceRefresh: Bool = false) async -> NASAAPODSnapshot? {
        let key = "nasa_apod"
        if !forceRefresh, let cached = await cache.load(NASAAPODSnapshot.self, key: key) {
            return cached
        }

        do {
            let value = try await nasaProvider.fetchAPOD()
            await cache.store(value, key: key, ttl: 6 * 60 * 60)
            return value
        } catch {
            print("[DataServiceManager] NASA APOD fetch failed: \(error)")
            return await cache.load(NASAAPODSnapshot.self, key: key)
        }
    }

    func wordOfDay(forceRefresh: Bool = false) async -> WordSnapshot? {
        let key = "word_of_day"
        if !forceRefresh, let cached = await cache.load(WordSnapshot.self, key: key) {
            return cached
        }

        do {
            let value = try await dictionaryProvider.randomWord()
            await cache.store(value, key: key, ttl: 24 * 60 * 60)
            return value
        } catch {
            print("[DataServiceManager] Word of day fetch failed: \(error)")
            return await cache.load(WordSnapshot.self, key: key)
        }
    }

    func dictionaryLookup(word: String, forceRefresh: Bool = false) async -> WordSnapshot? {
        let key = "dict_\(word.lowercased())"
        if !forceRefresh, let cached = await cache.load(WordSnapshot.self, key: key) {
            return cached
        }

        do {
            let value = try await dictionaryProvider.lookup(word: word)
            await cache.store(value, key: key, ttl: 24 * 60 * 60)
            return value
        } catch {
            print("[DataServiceManager] Dictionary lookup failed for '\(word)': \(error)")
            return await cache.load(WordSnapshot.self, key: key)
        }
    }
}
