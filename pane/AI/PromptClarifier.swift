import Foundation

// MARK: - Models

struct ClarificationQuestion: Codable, Identifiable {
    let id: String
    let question: String
    let options: [String]
    let allowsMultiple: Bool
}

enum ClarificationResult {
    case clear
    case needsQuestions([ClarificationQuestion])
}

// MARK: - Clarifier

struct PromptClarifier {
    private let componentTypes: [String]

    init() {
        self.componentTypes = Self.loadComponentTypes()
    }

    func analyze(prompt: String, client: AIProviderClient) async -> ClarificationResult {
        let system = systemPrompt()
        let user = "User prompt: \(prompt)"

        do {
            let raw = try await client.generateJSON(systemPrompt: system, userPrompt: user)
            return parse(raw)
        } catch {
            // On any failure (timeout, network, parse error) just proceed without clarification.
            return .clear
        }
    }

    // Maps human-readable option labels to schema field tokens the AI and heuristics understand.
    private static let optionFieldMap: [String: String] = [
        "Stars": "stars",
        "Forks": "forks",
        "Open Issues": "issues",
        "Watchers": "watchers",
        "Language": "language",
        "Description": "description",
        "Celsius": "celsius",
        "Fahrenheit": "fahrenheit"
    ]

    func synthesizePrompt(
        original: String,
        questions: [ClarificationQuestion],
        answers: [String: [String]]
    ) -> String {
        var parts = [original]
        for q in questions {
            guard let selected = answers[q.id], !selected.isEmpty else { continue }
            let stem = q.question.hasSuffix("?") ? String(q.question.dropLast()) : q.question
            // Map labels to field tokens so the AI and heuristic get machine-readable values
            let tokens = selected.map { Self.optionFieldMap[$0] ?? $0.lowercased().replacingOccurrences(of: " ", with: "_") }
            parts.append("\(stem): \(tokens.joined(separator: ", "))")
        }
        return parts.joined(separator: ". ")
    }

    // MARK: - Private

    private func parse(_ raw: String) -> ClarificationResult {
        // Strip markdown fences if present
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            let lines = text.components(separatedBy: "\n")
            text = lines.dropFirst().dropLast().joined(separator: "\n")
        }

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .clear
        }

        guard let needs = json["needsClarification"] as? Bool, needs else {
            return .clear
        }

        guard let rawQuestions = json["questions"] as? [[String: Any]] else {
            return .clear
        }

        let questions: [ClarificationQuestion] = rawQuestions.compactMap { q in
            guard
                let id = q["id"] as? String,
                let question = q["question"] as? String,
                let options = q["options"] as? [String],
                !options.isEmpty
            else { return nil }
            let allowsMultiple = (q["allowsMultiple"] as? Bool) ?? true
            return ClarificationQuestion(id: id, question: question, options: options, allowsMultiple: allowsMultiple)
        }

        guard !questions.isEmpty else { return .clear }
        return .needsQuestions(questions)
    }

    private func systemPrompt() -> String {
        let schemaList = componentTypes.joined(separator: ", ")

        return """
        You are the clarification layer for "pane", a macOS desktop widget app.

        Your job: when a user's widget prompt is incomplete, ask ALL the questions needed to fully specify it in ONE round. After this, no more questions will be asked. Think like a careful product designer + engineer: ask only high-value questions that affect behavior.

        AVAILABLE COMPONENT TYPES:
        \(schemaList)

        COMPONENT ROUTING RULES — use these to decide what to ask:

        github_repo_stats:
        - Triggered by: GitHub URL (github.com/...) OR "github stats", "repo tracker", "github stars/forks"
        - Required field: source = "owner/repo" (extract from URL if present)
        - Optional field: showComponents (which stats to display)
        - If a github.com URL with owner/repo is already in the prompt, set needsClarification: true and ask ONLY: "Which stats to show?" with options ["Stars", "Forks", "Open Issues", "Watchers", "Description"] and allowsMultiple: true, id: "show-stats"
        - If no URL or repo is given, also ask for the repo URL

        weather:
        - Needs: location (city name). If no location → ask "Which city?" with 3–4 example options + allowsMultiple: false
        - Needs: temperature unit if not clear. Options: ["Celsius", "Fahrenheit"]

        stock / crypto:
        - Needs: specific symbols. If vague ("the market", "crypto") → ask "Which assets?" with top options, allowsMultiple: true

        timer / countdown / pomodoro:
        - timer + no duration → ask "How long?" with common options like ["2 min", "5 min", "25 min (Pomodoro)", "1 hr"]
        - countdown + no date → ask "What date?" — free text isn't possible so use id "target-date" with representative options

        dashboard / productivity:
        - Ask "Which sections to include?" listing available component types as options, allowsMultiple: true

        Interaction-first behavior:
        - If user asks for note/scratch/journal and does not say static vs editable, ask whether it should be editable.
        - If user asks for checklist/todos and does not say interaction mode, ask whether they want check-off interaction.
        - If user asks for launcher/shortcuts and app targets are unclear, ask which app set to include.
        - If data freshness matters ("live", "real-time", "updates"), ask how often to refresh (for example: 1 min, 5 min, 15 min).
        - If prompt suggests unsupported live integrations, ask for a URL and steer to link_bookmarks.

        Apple-size consistency:
        - If prompt asks for very specific dimensions, ask them to choose the nearest wallpaper size class.
        - Size options should be from: Small Square, Medium, Wide, Large, Dashboard.

        External APIs pane CANNOT fetch (polymarket, Twitter, Reddit, Notion, etc.):
        - pane has NO generic HTTP fetch. The best widget is a link_bookmarks with the profile/page URL.
        - If the user asks for live data from an unsupported service, ask: "Can you share the profile URL?" so a bookmark widget can be created.
        - Do NOT ask about data that can't be displayed.

        WHEN TO RETURN needsClarification: false (prompt is already complete):
        - A GitHub.com URL is present AND owner/repo is clear in the path → still ask show-stats question
        - Specific city already named for weather
        - Specific symbols named for stocks/crypto
        - Duration explicit for timer
        - Self-contained: "analog clock", "battery meter", "stopwatch", "pomodoro"
        - Any prompt that leaves nothing important ambiguous (interaction, data source, or refresh intent)

        Return ONLY valid JSON. No explanation, no markdown, no preamble.

        If CLEAR:
        {"needsClarification": false}

        If needs input, ask ALL relevant questions at once (max 3):
        {
          "needsClarification": true,
          "questions": [
            {
              "id": "short-kebab-id",
              "question": "Short question text?",
              "options": ["Option A", "Option B", "Option C"],
              "allowsMultiple": true
            }
          ]
        }

        Rules:
        - Maximum 3 questions, maximum 5 options each
        - allowsMultiple: true for "what to include"; false for mutually exclusive choices
        - Question text: under 50 characters, ends with "?"
        - Option text: 1–3 words
        - Option values for github_repo_stats stats MUST be exactly: "Stars", "Forks", "Open Issues", "Watchers", "Description"
        """
    }

    private static func loadComponentTypes() -> [String] {
        guard let url = Bundle.main.url(forResource: "ComponentSchema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let types = json["componentTypes"] as? [String] else {
            return [
                "text", "icon", "divider", "spacer", "progress_ring", "progress_bar", "chart",
                "clock", "analog_clock", "date", "countdown", "timer", "stopwatch", "world_clocks",
                "pomodoro", "day_progress", "year_progress", "weather", "stock", "crypto",
                "calendar_next", "reminders", "battery", "system_stats", "music_now_playing",
                "news_headlines", "screen_time", "checklist", "habit_tracker", "quote", "note",
                "shortcut_launcher", "link_bookmarks", "github_repo_stats", "vstack", "hstack", "container"
            ]
        }
        return types
    }
}
