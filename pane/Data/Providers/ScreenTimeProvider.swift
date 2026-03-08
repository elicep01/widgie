import AppKit
import Foundation

/// Tracks actual screen time by polling the frontmost application at regular intervals
/// and accumulating per-app usage durations throughout the day. Resets at midnight.
final class ScreenTimeProvider {
    static let shared = ScreenTimeProvider()

    /// How often we sample the frontmost app (seconds)
    private let pollInterval: TimeInterval = 15

    private var timer: Timer?
    private var lastPollDate: Date?
    private var trackingDay: Int = -1 // day-of-year for reset detection

    /// Accumulated seconds per app bundle name
    private var appDurations: [String: TimeInterval] = [:]
    /// Total accumulated seconds
    private var totalSeconds: TimeInterval = 0

    /// App category mapping
    private static let categoryMap: [String: String] = [
        // Browsers
        "Safari": "Browsing",
        "Google Chrome": "Browsing",
        "Firefox": "Browsing",
        "Arc": "Browsing",
        "Brave Browser": "Browsing",
        "Microsoft Edge": "Browsing",
        "Opera": "Browsing",
        // Communication
        "Mail": "Communication",
        "Messages": "Communication",
        "Slack": "Communication",
        "Discord": "Communication",
        "Microsoft Teams": "Communication",
        "Zoom": "Communication",
        "FaceTime": "Communication",
        "Telegram": "Communication",
        "WhatsApp": "Communication",
        // Development
        "Xcode": "Development",
        "Visual Studio Code": "Development",
        "Code": "Development",
        "Terminal": "Development",
        "iTerm2": "Development",
        "Warp": "Development",
        "Cursor": "Development",
        "Sublime Text": "Development",
        "IntelliJ IDEA": "Development",
        "PyCharm": "Development",
        "WebStorm": "Development",
        // Productivity
        "Finder": "Productivity",
        "Notes": "Productivity",
        "Reminders": "Productivity",
        "Calendar": "Productivity",
        "Preview": "Productivity",
        "Pages": "Productivity",
        "Numbers": "Productivity",
        "Keynote": "Productivity",
        "Microsoft Word": "Productivity",
        "Microsoft Excel": "Productivity",
        "Microsoft PowerPoint": "Productivity",
        "Notion": "Productivity",
        "Obsidian": "Productivity",
        // Entertainment
        "Spotify": "Entertainment",
        "Music": "Entertainment",
        "TV": "Entertainment",
        "Podcasts": "Entertainment",
        "YouTube": "Entertainment",
        "Netflix": "Entertainment",
        // Social
        "Twitter": "Social",
        "X": "Social",
        "Instagram": "Social",
        "TikTok": "Social",
        "Reddit": "Social",
        // Design
        "Figma": "Design",
        "Sketch": "Design",
        "Adobe Photoshop": "Design",
        "Adobe Illustrator": "Design",
        "Canva": "Design",
        // System
        "System Preferences": "System",
        "System Settings": "System",
        "Activity Monitor": "System",
        "App Store": "System",
    ]

    init() {}

    /// Start background tracking. Call once at app launch.
    @MainActor
    func startTracking() {
        guard timer == nil else { return }
        lastPollDate = Date()
        trackingDay = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.recordFrontmostApp()
        }
        // Fire immediately to capture current state
        recordFrontmostApp()
    }

    private func recordFrontmostApp() {
        let now = Date()

        // Reset at midnight
        let currentDay = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
        if currentDay != trackingDay {
            appDurations.removeAll()
            totalSeconds = 0
            trackingDay = currentDay
            lastPollDate = now
            return
        }

        guard let lastPoll = lastPollDate else {
            lastPollDate = now
            return
        }

        let elapsed = now.timeIntervalSince(lastPoll)
        // Sanity: cap at 2× poll interval to avoid huge jumps (e.g. after sleep)
        let credited = min(elapsed, pollInterval * 2)

        if let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName, !frontApp.isEmpty {
            appDurations[frontApp, default: 0] += credited
            totalSeconds += credited
        }

        lastPollDate = now
    }

    func fetch(maxApps: Int) -> ScreenTimeSnapshot {
        // Sort apps by duration descending
        let sorted = appDurations
            .sorted { $0.value > $1.value }
            .prefix(max(1, maxApps))

        let topApps = sorted.map { name, seconds in
            ScreenTimeAppSnapshot(
                id: name,
                name: name,
                category: Self.categoryMap[name] ?? "Other",
                durationSeconds: seconds,
                durationText: Self.formatDuration(seconds)
            )
        }

        return ScreenTimeSnapshot(
            total: Self.formatDuration(totalSeconds),
            totalSeconds: totalSeconds,
            topApps: topApps,
            isAvailable: true,
            updatedAt: Date()
        )
    }

    /// Format seconds into a human-readable string like "2h 15m" or "45m"
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
}
