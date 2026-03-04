import Foundation

/// Learns and persists the user's aesthetic and layout preferences from accepted widget
/// generations. After a few accepted widgets the store can generate a compact "User Style
/// Profile" string that is injected into every generation prompt, nudging the AI toward
/// the user's taste even when the prompt doesn't specify visual details.
@MainActor
final class UserPreferenceStore {
    private static let fileName = "user_preferences.json"
    private static let minObservationsForProfile = 3

    private var profile: StoredProfile

    init() {
        profile = Self.loadFromDisk() ?? StoredProfile()
    }

    // MARK: - Public API

    /// Update preferences from a newly accepted prompt + config pair.
    func learn(prompt: String, config: WidgetConfig) {
        profile.totalAccepted += 1
        recordTheme(config.theme.rawValue)
        recordBackground(config.background.type)
        recordSize(config.size)
        recordCornerRadius(config.cornerRadius)
        recordFonts(in: config.content)
        recordAestheticTokens(from: prompt)
        saveToDisk()
    }

    /// Returns a concise style profile string for injection into the system prompt,
    /// or `nil` if too few observations exist yet.
    var styleProfile: String? {
        guard profile.totalAccepted >= Self.minObservationsForProfile else { return nil }

        var lines: [String] = []

        if let theme = dominantKey(in: profile.themeFrequency) {
            lines.append("- Preferred theme: \(theme)")
        }

        if let bg = dominantKey(in: profile.backgroundTypeFrequency) {
            let friendly = backgroundFriendlyName(bg)
            lines.append("- Background style: \(friendly)")
        }

        let avgSize = averageSize()
        if let sizeLabel = sizeCategoryLabel(avgSize) {
            lines.append("- Widget size tendency: \(sizeLabel) (avg ~\(Int(avgSize.width))×\(Int(avgSize.height)) pts)")
        }

        let topFonts = topN(profile.fontFrequency, n: 2)
        if !topFonts.isEmpty {
            lines.append("- Preferred fonts: \(topFonts.joined(separator: ", "))")
        }

        let topTokens = topN(profile.aestheticTokenFrequency, n: 5)
        if !topTokens.isEmpty {
            lines.append("- Aesthetic keywords from past prompts: \(topTokens.joined(separator: ", "))")
        }

        guard !lines.isEmpty else { return nil }

        return """
        USER STYLE PROFILE (inferred from \(profile.totalAccepted) accepted widget\(profile.totalAccepted == 1 ? "" : "s")):
        \(lines.joined(separator: "\n"))
        Apply this style when the user's prompt does not override it. Never mention this profile to the user.
        """
    }

    // MARK: - Recording helpers

    private func recordTheme(_ theme: String) {
        let key = theme.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        profile.themeFrequency[key, default: 0] += 1
    }

    private func recordBackground(_ type: String) {
        let key = type.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        profile.backgroundTypeFrequency[key, default: 0] += 1
    }

    private func recordSize(_ size: WidgetSize) {
        profile.widthSamples.append(size.width)
        profile.heightSamples.append(size.height)
        // Keep only the most recent 50 samples to avoid drift from old preferences.
        if profile.widthSamples.count > 50 { profile.widthSamples.removeFirst() }
        if profile.heightSamples.count > 50 { profile.heightSamples.removeFirst() }
    }

    private func recordCornerRadius(_ radius: Double) {
        profile.cornerRadiusSamples.append(radius)
        if profile.cornerRadiusSamples.count > 50 { profile.cornerRadiusSamples.removeFirst() }
    }

    private func recordFonts(in component: ComponentConfig) {
        if let font = component.font {
            let key = font.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { profile.fontFrequency[key, default: 0] += 1 }
        }
        component.child.map { recordFonts(in: $0) }
        component.children?.forEach { recordFonts(in: $0) }
    }

    private static let aestheticKeywords: Set<String> = [
        // Visual style
        "minimal", "minimalist", "clean", "simple", "elegant", "sleek", "crisp",
        "bold", "vibrant", "colorful", "monochrome", "dark", "light", "neon",
        "retro", "vintage", "cute", "professional", "modern", "classic",
        "subtle", "glassmorphic", "frosted", "blurred", "transparent",
        "aesthetic", "beautiful", "gorgeous", "pretty", "fancy", "cool",
        // Layout / density
        "compact", "spacious", "airy", "dense", "condensed", "detailed",
        "full", "tiny", "small", "large", "wide", "narrow", "tall",
        // Mood / vibe
        "cozy", "moody", "calm", "energetic", "focused", "productive",
        "dark", "bright", "pastel", "muted", "vivid",
    ]

    private func recordAestheticTokens(from prompt: String) {
        let lower = prompt.lowercased()
        let words = lower.split { !$0.isLetter }.map(String.init)
        for word in words {
            if Self.aestheticKeywords.contains(word) {
                profile.aestheticTokenFrequency[word, default: 0] += 1
            }
        }
    }

    // MARK: - Analysis helpers

    private func dominantKey(in freq: [String: Int]) -> String? {
        guard !freq.isEmpty else { return nil }
        let sorted = freq.sorted { $0.value > $1.value }
        // Only return a dominant key if it has at least 40% of votes.
        let total = freq.values.reduce(0, +)
        guard let top = sorted.first, Double(top.value) / Double(total) >= 0.4 else { return nil }
        return top.key
    }

    private func topN(_ freq: [String: Int], n: Int) -> [String] {
        freq.sorted { $0.value > $1.value }.prefix(n).map(\.key)
    }

    private func averageSize() -> WidgetSize {
        let avgW = profile.widthSamples.isEmpty ? 320 : profile.widthSamples.reduce(0, +) / Double(profile.widthSamples.count)
        let avgH = profile.heightSamples.isEmpty ? 160 : profile.heightSamples.reduce(0, +) / Double(profile.heightSamples.count)
        return WidgetSize(width: avgW, height: avgH)
    }

    private func sizeCategoryLabel(_ size: WidgetSize) -> String? {
        let w = size.width
        let ratio = w > 0 ? size.width / size.height : 1.5

        let sizeWord: String
        switch w {
        case ..<200:  sizeWord = "tiny"
        case 200..<300: sizeWord = "small"
        case 300..<420: sizeWord = "medium"
        case 420..<600: sizeWord = "large"
        default:       sizeWord = "extra-large"
        }

        let ratioWord: String
        switch ratio {
        case ..<1.1:    ratioWord = "square"
        case 1.1..<1.8: ratioWord = "slightly wide"
        case 1.8..<2.8: ratioWord = "wide/horizontal"
        default:        ratioWord = "very wide"
        }

        return "\(sizeWord), \(ratioWord)"
    }

    private func backgroundFriendlyName(_ type: String) -> String {
        switch type {
        case "blur":      return "blur / frosted glass"
        case "gradient":  return "gradient"
        case "solid":     return "solid"
        case "image":     return "image"
        default:          return type
        }
    }

    // MARK: - Persistence

    private static func storeURL() -> URL? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("widgie", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private static func loadFromDisk() -> StoredProfile? {
        guard let url = storeURL(), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StoredProfile.self, from: data)
    }

    private func saveToDisk() {
        guard let url = Self.storeURL() else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Stored data model

private struct StoredProfile: Codable {
    var themeFrequency: [String: Int] = [:]
    var backgroundTypeFrequency: [String: Int] = [:]
    var widthSamples: [Double] = []
    var heightSamples: [Double] = []
    var cornerRadiusSamples: [Double] = []
    var fontFrequency: [String: Int] = [:]
    var aestheticTokenFrequency: [String: Int] = [:]
    var totalAccepted: Int = 0
}
