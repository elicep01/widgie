import Foundation

/// Maps common user-facing concept tokens to synonyms that appear in example keySignals and prompts.
/// Used by `PromptExampleRetriever` to expand query tokens before scoring so that semantically
/// related prompts (e.g. "mood tracker" → habit_tracker examples) rank higher.
enum ConceptSynonymMap {

    /// Expands a set of normalized tokens with their synonyms.
    static func expand(_ tokens: Set<String>) -> Set<String> {
        var expanded = tokens
        for token in tokens {
            if let synonyms = expansions[token] {
                expanded.formUnion(synonyms)
            }
        }
        return expanded
    }

    // MARK: - Synonym table

    private static let expansions: [String: Set<String>] = [

        // Mood / wellness → maps to habit_tracker territory
        "mood":         ["habit", "tracker", "wellness", "feeling", "emotion", "daily"],
        "moods":        ["habit", "tracker", "wellness", "feeling"],
        "feeling":      ["mood", "habit", "tracker", "wellness", "emotion"],
        "feelings":     ["mood", "habit", "tracker", "wellness"],
        "emotion":      ["mood", "habit", "tracker", "feeling"],
        "emotions":     ["mood", "habit", "tracker"],
        "wellness":     ["habit", "tracker", "mood", "health", "daily"],
        "mental":       ["mood", "habit", "tracker", "wellness"],
        "mindfulness":  ["mood", "habit", "tracker", "wellness"],
        "mindful":      ["mood", "habit", "tracker"],

        // Habit / routine / goals
        "habit":        ["tracker", "routine", "daily", "checklist", "goals"],
        "habits":       ["tracker", "routine", "daily", "checklist"],
        "routine":      ["habit", "tracker", "daily", "checklist"],
        "rituals":      ["habit", "tracker", "routine", "daily"],
        "goal":         ["habit", "tracker", "checklist", "progress"],
        "goals":        ["habit", "tracker", "checklist", "progress"],

        // Productivity / tasks / todo
        "productivity": ["checklist", "dashboard", "todo", "habit", "focus"],
        "productive":   ["checklist", "dashboard", "todo", "habit"],
        "focus":        ["dashboard", "checklist", "timer", "pomodoro"],
        "work":         ["dashboard", "checklist", "timer", "pomodoro"],
        "task":         ["checklist", "todo", "list"],
        "tasks":        ["checklist", "todo", "list"],
        "todo":         ["checklist", "task", "list"],
        "todos":        ["checklist", "task", "list"],

        // Finance / market
        "finance":      ["stock", "crypto", "market", "bitcoin", "dashboard"],
        "financial":    ["stock", "crypto", "market"],
        "portfolio":    ["stock", "crypto", "market", "bitcoin", "ethereum"],
        "investment":   ["stock", "crypto", "market"],
        "trading":      ["stock", "crypto", "bitcoin", "market"],
        "market":       ["stock", "crypto", "bitcoin", "ethereum"],
        "markets":      ["stock", "crypto", "bitcoin", "ethereum"],
        "assets":       ["stock", "crypto", "market"],
        "price":        ["stock", "crypto", "bitcoin"],
        "prices":       ["stock", "crypto", "bitcoin"],
        "ticker":       ["stock", "market"],

        // Crypto
        "bitcoin":      ["btc", "crypto"],
        "ethereum":     ["eth", "crypto"],
        "btc":          ["bitcoin", "crypto"],
        "eth":          ["ethereum", "crypto"],
        "crypto":       ["bitcoin", "ethereum", "btc", "eth"],
        "coins":        ["crypto", "bitcoin", "ethereum"],
        "coin":         ["crypto", "bitcoin", "ethereum"],

        // Metals / commodities
        "gold":         ["stock", "market", "metals", "commodities", "gld"],
        "silver":       ["stock", "market", "metals", "commodities", "slv"],
        "metals":       ["gold", "silver", "stock", "market"],
        "commodities":  ["gold", "silver", "stock", "market"],

        // Time
        "time":         ["clock", "timer", "countdown", "watch"],
        "clocks":       ["clock", "timer", "world", "timezone"],
        "watch":        ["clock", "timer", "countdown"],
        "schedule":     ["clock", "calendar", "countdown"],
        "alarm":        ["clock", "timer", "countdown"],

        // Journal / notes
        "journal":      ["note", "diary", "memo", "text"],
        "diary":        ["note", "journal", "memo"],
        "memo":         ["note", "journal", "text"],
        "writing":      ["note", "journal", "text"],
        "write":        ["note", "journal", "text"],
        "sticky":       ["note", "memo", "text"],

        // Weather
        "forecast":     ["weather", "temperature", "rain"],
        "temperature":  ["weather", "celsius", "fahrenheit"],
        "rain":         ["weather"],
        "sunny":        ["weather"],
        "cloudy":       ["weather"],

        // System / stats
        "system":       ["stats", "cpu", "memory", "battery"],
        "stats":        ["system", "battery", "memory", "cpu"],
        "performance":  ["system", "stats", "cpu"],
        "computer":     ["system", "stats", "battery"],
        "mac":          ["system", "stats", "battery"],
        "laptop":       ["system", "stats", "battery"],

        // Music
        "music":        ["now", "playing", "song", "album"],
        "song":         ["music", "playing", "now"],
        "playlist":     ["music", "now", "playing"],
        "spotify":      ["music", "now", "playing"],

        // Health / fitness
        "health":       ["battery", "habit", "tracker", "wellness"],
        "fitness":      ["habit", "tracker", "wellness", "steps"],
        "exercise":     ["habit", "tracker", "fitness"],
        "sleep":        ["habit", "tracker", "wellness"],
        "steps":        ["habit", "tracker", "fitness"],

        // Dashboard / overview
        "dashboard":    ["productivity", "checklist", "quote", "stock", "weather"],
        "overview":     ["dashboard", "productivity"],
        "summary":      ["dashboard", "productivity"],
        "desktop":      ["dashboard", "widget", "creative"],
    ]
}
