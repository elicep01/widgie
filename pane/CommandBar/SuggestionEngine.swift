import Foundation

struct SuggestionEngine {
    func suggestion(for input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowercased = trimmed.lowercased()

        if lowercased.contains("clock") {
            return "...with timezone and date"
        }

        if lowercased.contains("weather") {
            return "...for your current location"
        }

        if lowercased.contains("checklist") {
            return "...with a daily reset"
        }

        if lowercased.contains("stock") {
            return "...with daily sparkline"
        }

        if lowercased.hasPrefix("/") {
            return "Try /templates, /template minimal-clock, /export, or /import"
        }

        return nil
    }
}
