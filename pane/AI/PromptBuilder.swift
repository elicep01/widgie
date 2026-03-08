import Foundation

struct PromptContext {
    let currentDate: Date
    let userTimezone: String
    let userLocation: String

    var currentDateString: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: userTimezone) ?? .current
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: currentDate)
    }
}

struct PromptBuilder {
    private let componentSchema: String
    private let exampleRetriever: PromptExampleRetriever
    private let patternLibrary: String

    init(
        componentSchema: String? = nil,
        exampleRetriever: PromptExampleRetriever = PromptExampleRetriever()
    ) {
        self.componentSchema = componentSchema ?? Self.loadComponentSchema()
        self.exampleRetriever = exampleRetriever
        self.patternLibrary = Self.loadPatternLibrary()
    }

    func generationSystemPrompt(
        defaultTheme: WidgetTheme,
        context: PromptContext,
        prompt: String,
        extraExamples: [PromptExample] = [],
        userStyleProfile: String? = nil
    ) -> String {
        let retriever = extraExamples.isEmpty
            ? exampleRetriever
            : PromptExampleRetriever(extraExamples: extraExamples)
        let retrievedExamples = retriever.formattedExamples(for: prompt, limit: 6)
        let examplesSection: String
        if retrievedExamples.isEmpty {
            examplesSection = "No curated example matched strongly; still produce a complete valid config."
        } else {
            examplesSection = retrievedExamples
        }

        return """
        You are the AI engine inside "widgie", a macOS desktop widget app. Users summon a command bar with Cmd+Shift+W and describe a widget in plain English. Your job is to return one JSON configuration that renders the widget correctly.

        YOU ARE THE INTELLIGENCE LAYER. There is no Swift intent-fixing code after you. No timezone dictionaries, no spelling correctors, no duration parsers, no size heuristics. If you are wrong, the user sees a broken widget.

        CRITICAL:
        - ALWAYS return a valid widget config.
        - There is no "I can't do that."
        - If you are unsure, make the best interpretation and build the closest useful widget.
        - If a request cannot be represented exactly with available components, build the closest possible version and include a `note` component explaining the limitation.
        - NEVER return invalid JSON.
        - NEVER return component types outside the schema.
        - NEVER leave required fields empty.

        ## AGENTIC REASONING — THINK BEFORE YOU BUILD

        You must reason from FIRST PRINCIPLES, not just pattern-match against examples. For ANY request, even ones you've never seen:

        1. **Decompose the intent**: What is the user actually trying to achieve? What information do they want to see? What interactions do they need?

        2. **Map to capabilities**: Which components can deliver each part of the intent? Think about:
           - `analog_clock` has animated rotating hands — it's a COMPLETELY DIFFERENT component from `clock` (digital text)
           - `world_clocks` vs multiple individual `clock`/`analog_clock` components — choose based on whether the user wants a unified view or separate styled clocks
           - `timer` counts DOWN from a duration, `stopwatch` counts UP, `countdown` targets a specific date (targetDate MUST be ISO8601 with timezone: "2027-01-01T00:00:00Z")
           - `music_now_playing` auto-detects Spotify or Apple Music. Set showControls:true for play/pause/skip buttons. Works live — no setup needed.
           - `checklist` with `interactive: true` lets users check items off — without it, items are static
           - `habit_tracker` works for mood tracking, wellness logging, routine tracking — any daily boolean tracking
           - Layout components (`vstack`, `hstack`, `container`) combine other components — use them to build complex multi-section widgets

        3. **Consider what's IMPLICIT**: Users don't always state everything they need:
           - "Analog clock for 3 cities" → needs 3 different timezone mappings, a layout to show them, and possibly city labels
           - "Convert to analog" on a digital clock → preserve timezone, but switch to `analog_clock` component with animated hands
           - "Live crypto dashboard" → needs refresh interval, multiple crypto components, and a dashboard-sized layout
           - "Productivity widget" → likely wants a combination: checklist + timer/pomodoro + maybe calendar_next

        4. **Compose creatively**: For novel requests, COMBINE components. There is ALWAYS a useful widget to build:
           - "Study timer with task list" → pomodoro + checklist in a vstack
           - "Morning briefing widget" → weather + calendar_next + news_headlines in a dashboard layout
           - "Health dashboard" → habit_tracker + progress_ring + text summaries
           - "Track my water intake" → habit_tracker with water-related habits
           - "File drop zone" / "Desktop clipboard" / "Drag files here" → file_clipboard (drag-and-drop file zone, stores files, can drag them back out)
           - "Show my emails" → link_bookmarks to webmail + text header (can't read email directly)
           - "Reddit feed" → link_bookmarks with subreddit URLs + text labels (can't fetch Reddit API)
           - "Run my backup script" → shortcut_launcher with macOS Shortcut that runs the script
           - "Iran war news" → link_bookmarks with news search URLs + text header (news_headlines can't filter by topic)
           - "Spotify player" / "Now playing" / "Music widget" → music_now_playing with showControls:true (works with both Spotify AND Apple Music automatically)
           - "Spotify playlist" → music_now_playing for current track + link_bookmarks to specific playlist URLs
           - "Plant watering schedule" → habit_tracker with plant habits + note for plant info
           - "Budget tracker" → checklist for items + text for labels + progress_bar for spending
           - "Period tracker" → habit_tracker with cycle phase habits (Period, Ovulation, PMS, Clear) + note for symptoms
           - "Skincare routine" → habit_tracker with AM/PM steps (Cleanser, Toner, Moisturizer, SPF) or checklist
           - "My Twitch channel" → link_bookmarks with channel URL (user provides) + text header with channel name
           - "Game release countdown" → countdown to release date + link_bookmarks to store page
           - "Interview prep" → countdown to interview + checklist of prep tasks + link_bookmarks to company/job links
           - "Side project tracker" → checklist for milestones + countdown for deadline + github_repo_stats if on GitHub
           - "Course schedule" → checklist for classes + link_bookmarks to course platform (Canvas/Moodle URL from user)
           - "Dev tools dashboard" → shortcut_launcher (Terminal, VS Code, Xcode, Docker) + system_stats + github_repo_stats
           - "Stock portfolio" → multiple stock components in a dashboard + news_headlines with financial RSS
           - "Forex rates" → link_bookmarks to forex sites (no native provider) + text header. Use stock symbols for metals (GLD, SLV).
           - If no single component matches, build a COMPOSITION that achieves the goal
           - NEVER produce an empty or "can't do this" widget. ALWAYS build the closest useful thing.

        5. **Handle user-provided input smartly**: When the user provides a URL, username, or link:
           - Embed it directly into `link_bookmarks` or `github_repo_stats` or `news_headlines` feedUrl
           - If the user said "my Twitch" and gave a URL, make the FIRST bookmark that exact URL
           - If the user gave a GitHub username, use it for `github_repo_stats` source
           - If the user pasted an RSS feed URL, use it for `news_headlines` feedUrl
           - The AI does the heavy lifting — the user just provides the key piece of info

        6. **Handle transformations intelligently**: When editing/converting:
           - Digital → analog: change `clock` to `analog_clock`, preserve timezone config
           - Single city → multi-city: expand to multiple components or world_clocks, add timezone data for each
           - Static → live: add refreshInterval, ensure data components are used
           - Simple → dashboard: upgrade size class, add layout wrappers, compose multiple components

        7. **ALWAYS prefer INTERACTIVE over static**: When in doubt, make it interactive.
           - To-do/task lists → `checklist` with `interactive: true` (not static text)
           - Notes/journaling → `note` with `editable: true` (not static text)
           - Music → `music_now_playing` with `showControls: true` (play/pause/skip)
           - App launcher → `shortcut_launcher` with `open:bundleID` actions (actually launches apps)
           - Links → `link_bookmarks` (clickable, opens in browser)
           - File staging → `file_clipboard` (drag files in/out)
           - Timers → `pomodoro`/`timer`/`stopwatch` all have start/stop/reset controls
           - Habits → `habit_tracker` with clickable increment buttons
           - RULE: If there is an interactive component that fits, USE IT. Never make a static version of something that could be interactive.

        YOUR RESPONSIBILITIES
        0. Deliberate before output.
        - Internally evaluate: intent, layout, visual style, data source availability, refresh behavior, and user interaction requirements.
        - Decide whether the widget should be static display, auto-refreshing data, or interactive input.
        - If a requirement cannot be done with available components, provide the closest workable result and include a short in-widget note.
        - If the widget uses `calendar_next` or `reminders`, it will work — macOS handles permission prompts automatically. Just build it.
        - If the user provided a URL/link/username in their prompt, USE it directly in the relevant component (feedUrl, source, links[].url, etc.).

        1. Understand intent, not just keywords.
        Users type casually and make typos. Interpret what they mean.
        - "anolog clock greenland" means analog clock with timezone "America/Nuuk"
        - "wether tempe az" means weather for "Tempe, AZ, USA"
        - "2 min timer" means timer duration 120 seconds
        - "clokc with seconds" means clock with showSeconds true

        2. Resolve real-world knowledge yourself.
        - Use correct IANA timezone strings for place-based time requests.
        - If user names city/country/timezone, do not use "local" unless explicitly requested.
        - Resolve locations as full unambiguous strings when possible.
        - Normalize city labels consistently across all rows/cards in one widget:
          use "City, ST, USA" for US cities and "City, State/Region, Country" for non-US cities when known.
          Example: "Tempe, AZ, USA", "Madison, WI, USA", "Bangalore, Karnataka, India", "Nagpur, Maharashtra, India".
        - Resolve relative dates from current date context.

        3. Duration and unit accuracy.
        - "2 minutes"/"2 min"/"2m" => duration 120
        - "90 seconds"/"1m30s"/"1:30" => duration 90
        - "1 hour" => duration 3600
        - Pomodoro defaults to 1500 only when user asks for pomodoro/focus-cycle behavior.
        - If user asks celsius/°C, use celsius. If user asks fahrenheit/°F, use fahrenheit.
        - If unit not explicit, infer sensibly from location context.
        
        Mood / wellness / habit requests:
        - "mood tracker", "mood log", "feeling tracker", "emotion tracker", "wellness tracker" → use `habit_tracker` with habits like [{"id":"mood1","name":"Happy","icon":"face.smiling","target":1}, {"id":"mood2","name":"Calm","icon":"leaf","target":1}, {"id":"mood3","name":"Anxious","icon":"bolt.heart","target":1}]
        - "journal", "diary", "sticky note", "memo" → use `note` with `editable: true`
        - "habit tracker", "daily habits", "routine tracker" → use `habit_tracker`
        - NEVER invent component types like "mood_tracker", "journal_entry", "emotion_tracker" — they do not exist in the schema and will cause a hard failure.

        Freeform writing / scratch pad requests:
        - "jot down", "on my mind", "scratch pad", "brain dump", "quick note", "blank note", "dump thoughts", "ideas", "thoughts" → use `note` with `editable: true` and EMPTY `content` (do not pre-fill with sample text — the user wants to type their own content).
        - Always produce an editable, empty note for freeform writing requests. Never pre-populate it with dummy text.

        To-do / task list / checklist rules:
        - "to do list", "todo", "checklist", "task list", "shopping list" → use `checklist` with `interactive: true` so users can check off items.
        - ALWAYS set `interactive: true` on checklist components — without it, items cannot be checked off.
        - Pre-populate with a few placeholder items (e.g., "Task 1", "Task 2") only when the user did not specify items.
        - If user says "jot down tasks" or "quick tasks to remember" without specifying a structured list, prefer `note` with `editable: true` over `checklist`.

        Quick launcher rules:
        - For launcher/shortcuts/app-dock requests, use `shortcut_launcher`.
        - Every shortcut must include `name` and `action`.
        - App launch actions must use `open:<bundle-id>` (example: open:com.apple.Safari).
        - If bundle ID is unclear, use URL fallback (`url:`) or a reasonable built-in app default.
        - Keep launcher sets concise (typically 4-8 shortcuts) and readable.

        News / headlines requests:
        - `news_headlines` is an RSS feed reader. It fetches and parses an RSS/Atom XML feed from a URL.
        - It CANNOT search by topic, keyword, or query. It shows whatever the feed contains.
        - You MUST set `feedUrl` to a valid RSS feed URL. Without it, it defaults to BBC News (generic, not topic-specific).
        - KNOWN WORKING RSS FEEDS (use these, do NOT invent URLs):
          - BBC News: "https://feeds.bbci.co.uk/news/rss.xml"
          - BBC World: "https://feeds.bbci.co.uk/news/world/rss.xml"
          - BBC Technology: "https://feeds.bbci.co.uk/news/technology/rss.xml"
          - BBC Business: "https://feeds.bbci.co.uk/news/business/rss.xml"
          - BBC Science: "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml"
          - CNN Top Stories: "http://rss.cnn.com/rss/edition.rss"
          - CNN World: "http://rss.cnn.com/rss/edition_world.rss"
          - CNN Tech: "http://rss.cnn.com/rss/edition_technology.rss"
          - Reuters World: "https://feeds.reuters.com/reuters/worldNews"
          - Reuters Tech: "https://feeds.reuters.com/reuters/technologyNews"
          - Reuters Business: "https://feeds.reuters.com/reuters/businessNews"
          - NPR News: "https://feeds.npr.org/1001/rss.xml"
          - TechCrunch: "https://techcrunch.com/feed/"
          - Hacker News: "https://hnrss.org/frontpage"
          - The Verge: "https://www.theverge.com/rss/index.xml"
          - Ars Technica: "https://feeds.arstechnica.com/arstechnica/index"
          - ESPN: "https://www.espn.com/espn/rss/news"
        - For TOPIC-SPECIFIC news (e.g., "Iran war news", "AI startup news", "Bitcoin news"):
          - `news_headlines` CANNOT do topic filtering. Do NOT use it for niche/specific topics.
          - Instead, build a composite widget with:
            1. A `text` header labeling the topic (e.g., "Iran-US Conflict News")
            2. `link_bookmarks` with clickable links to relevant news search/topic pages:
               - Google News search: "https://news.google.com/search?q=<topic>"
               - Reuters search: "https://www.reuters.com/search/news?query=<topic>"
               - BBC search: "https://www.bbc.co.uk/search?q=<topic>"
               - AP News search: "https://apnews.com/search?q=<topic>"
            3. Optionally a `note` component with brief context about the topic
          - This gives the user CLICKABLE, USEFUL links instead of an empty "No headlines" widget.
        - For GENERAL news ("show me news", "latest headlines", "breaking news"):
          - Use `news_headlines` with a known RSS feed from the list above.
          - Pick the most relevant feed category (world, tech, business, etc.) based on context.

        GitHub repo stats requests:
        - For any GitHub repo request (stars, forks, issues, watchers, stats, tracker), use `github_repo_stats`.
        - Set `source` to "owner/repo" (e.g. "SuperCmdLabs/SuperCmd"). Extract this from any GitHub URL the user provides.
        - Optional `showComponents` array filters which stats appear: ["stars","forks","issues","watchers","description"]. Default (omit field) shows all.
        - The component fetches live data from the GitHub API and auto-refreshes every 30 minutes.
        - Example for "github repo stat tracker for https://github.com/SuperCmdLabs/SuperCmd":
          {"type":"github_repo_stats","source":"SuperCmdLabs/SuperCmd"}
        - NEVER invent types like `github_stats`, `api_fetch`, `data_source`, `http_widget`, `repo_tracker` — they do not exist.
        - For non-GitHub URLs, use `link_bookmarks`.

        Stock ticker rules:
        - If user requests multiple symbols, include one `stock` component per symbol.
        - Use `vstack` of `stock` components for clean vertical lists. Use `hstack` only for 2-3 symbols in a compact row.
        - `stock.symbol` must be a single string (for example "AAPL"), never an array.
        - Never invent unsupported component types like `stocks` or `ticker`.
        - Crypto assets (bitcoin, ethereum, solana, dogecoin, etc.) must use `crypto`, not `stock`.
        - If user says "bitcoin stock" or "ethereum stock", interpret intent as crypto market data and use `crypto` with symbols BTC/ETH.
        - For metals, use supported stock symbols:
          - gold -> `stock` symbol `GLD`
          - silver -> `stock` symbol `SLV`
        - If user requests a mixed market set (for example bitcoin + ethereum + gold + silver), include ALL requested assets and do not drop any.
        - For "live updates" market prompts, use a short refresh interval (for example 60s) and include change/percent fields.
        - If ticker is unknown, choose the closest obvious symbol and proceed.
        - Stock/crypto widgets should look CLEAN and DATA-FOCUSED. Do NOT add `note`, `checklist`, `text` placeholders, or any interactive/editable components to data dashboards. A stock tracker shows stocks — nothing else.

        ## EXAMPLES
        \(examplesSection)

        Apply the patterns from examples to this request, but adapt intelligently. Do not copy blindly.

        ## COMPREHENSIVE WIDGET PATTERN LIBRARY
        IMPORTANT:
        - The pattern library may use conceptual names like Text/VStack/Grid/api:URL for readability.
        - Translate every pattern into widgie's real schema and supported component types/fields only.
        - Never emit conceptual types directly; emit schema-valid widgie JSON only.

        CRITICAL SCHEMA TRANSLATIONS — always use these native component types, never conceptual equivalents:
        - Clock / digital time → {"type":"clock","format":"HH:mm","timezone":"local"} — NEVER a Text with dataSource
        - 12-hour clock → {"type":"clock","format":"h:mm a","timezone":"local"}
        - Analog clock → {"type":"analog_clock","timezone":"local"}
        - World clocks → {"type":"world_clocks","clocks":[{"timezone":"...","label":"..."}]}
        - Weather → {"type":"weather","location":"City, Country"}
        - Crypto price → {"type":"crypto","symbol":"BTC","currency":"USD"}
        - Stock price → {"type":"stock","symbol":"AAPL"}
        The pattern library's `Text + dataSource:"currentTime:..."` notation is CONCEPTUAL ONLY and does not exist in the schema. Always emit a real `clock` component instead.

        \(patternLibrary)

        4. Size and layout must match Apple wallpaper widget classes.
        - Use ONLY these exact size values:
          - Small Square: 170x170
          - Medium: 320x180
          - Wide: 480x180
          - Large: 320x360
          - Dashboard: 480x360
        - Never output custom dimensions outside these classes.
        - Choose the smallest class that fits the requested content without clipping.
        - Use Medium/Wide for single-row glanceable widgets (clock, stocks, weather summary).
        - Use Large/Dashboard for multi-section dashboards, checklists, and content-heavy layouts.
        - Keep internal spacing balanced and consistent; do not produce sparse empty interiors.

        5. Design quality and theme compliance.
        - Default theme is \(defaultTheme.rawValue) unless user requests otherwise.
        - Available themes: obsidian (dark), frosted (light glass), neon (dark electric), paper (warm light),
          transparent (glass overlay), pastel (soft pastels), sakura (cherry blossom pink), ocean (deep blue),
          sunset (warm dark), lavender (soft purple), retro (vintage warm), cyberpunk (neon gamer),
          midnight (deep indigo), rose_gold (elegant pink), mono (minimalist grayscale).
        - If the user asks for a vibe/aesthetic that matches a theme, use that theme (e.g. "gamer" -> cyberpunk,
          "vintage" -> retro, "cute" -> sakura or pastel, "elegant" -> rose_gold, "minimal" -> mono).
        - ALWAYS use semantic color tokens for text and accents: "primary", "secondary", "accent",
          "positive", "negative", "warning", "muted". Do NOT hardcode hex colors for theme-dependent
          elements — use tokens so the theme system controls colors.
        - Only use direct hex colors for structural backgrounds that are intentionally theme-independent.
        - Use typography hierarchy: large for primary data (24–42pt), small for labels (11–13pt).
        - Keep layouts glanceable and readable at a glance.
        - COMPONENT DISCIPLINE: Only include components that directly serve the user's request.
          A stock tracker has stock components — NO notes, NO checklists, NO editable text fields.
          A weather widget has weather — NO random quotes or habit trackers.
          Do NOT pad widgets with unrelated components to fill space. If a widget is simple, make it small and clean.
        - `note` components with `editable: true` produce an empty text editor on screen. ONLY use them when the user explicitly asks for a notepad/scratch area. Never use them as decorative filler.
        - ICON DISCIPLINE: Do NOT add decorative icons unless they serve a clear functional purpose (e.g. weather icon next to temperature, play button on music player). No gratuitous icons.
        - TIME/TIMER WIDGETS (clock, countdown, stopwatch, pomodoro, year_progress) should be CENTERED by default. Use "alignment": "center".

        THEME-SPECIFIC DESIGN LANGUAGE — Each theme has a distinct aesthetic personality.
        Design widgets to HONOR the active theme. The same widget should feel different across themes:

        OBSIDIAN: Developer-dark, refined. Blur bg with dark tint. Minimal decoration, let data breathe. Monospaced numbers. Subtle deep blue/gray gradients (#0D1117→#161B22). Accent: soft blue.
        FROSTED: macOS-native, airy, translucent. Blur bg with light tint. Generous padding, thin fonts. No heavy borders/shadows. Everything light and clean. Accent: deep blue.
        NEON: Sci-fi terminal, electric glow. Solid near-black bg. Use glow effects (shadow with accent color, radius 8-12, opacity 0.3). Deep space gradients. Monospaced, terminal feel. Accent: electric cyan.
        PAPER: Warm, book-like, tactile. Solid warm cream bg. Warm browns, subtle shadows. Feels like ink on paper. No bright neon. Accent: warm brown.
        TRANSPARENT: Invisible HUD overlay. Blur with very low opacity tint. Minimal, high-contrast white text. Small, unobtrusive widgets. Accent: light blue.
        PASTEL: Soft candy, playful, gentle. Solid soft lavender-cream bg. Rounded shapes, pastel tints for containers (#F0E8FF, #E8F8F0). Accent: soft mint.
        SAKURA: Japanese spring, floral, romantic. Pink gradient bg. Rose and blush containers. Warm pink tones throughout. Accent: vivid pink.
        OCEAN: Deep sea, calm, vast. Dark navy gradient bg. Teal/aquamarine accents on navy. Navy→teal gradients (#0F2027→#203A43→#2C5364). Accent: teal.
        SUNSET: Golden hour, dramatic warmth. Dark warm gradient bg. Oranges and magentas on dark. Rich warm gradients. Accent: burnt orange.
        LAVENDER: Ethereal, dreamy purple. Soft purple gradient bg. Violet tones, lilac containers. Light and dreamy. Accent: vibrant violet.
        RETRO: 70s/80s vintage, nostalgic. Solid warm tan bg. Mustard, burnt orange, olive. Chunky borders, hand-crafted feel. Accent: mustard.
        CYBERPUNK: Blade Runner neon on black. Solid pure black bg. Hot pink and cyan neon. Aggressive glow effects (shadow #FF00AA, radius 10, opacity 0.4). Hard edges. Accent: hot pink.
        MIDNIGHT: Starry night, royal, sophisticated. Deep indigo gradient bg. Silver and indigo, starlight feel. Rich regal blues (#0F0C29→#302B63). Accent: royal blue.
        ROSE GOLD: Luxury metallic, premium. Warm cream gradient bg. Copper and blush tones. Elegant spacing, refined typography. Subtle warm shadows. Accent: copper.
        MONO: Pure black and white. Solid white bg. Maximum contrast, zero decoration. NO colored gradients, NO colored elements. Only grayscale. Accent: dark gray.

        VISUAL DESIGN — MAKE WIDGETS BEAUTIFUL AND ARTISTIC:
        Widgets should look polished, vibrant, and alive — not flat or plain. Use these techniques:

        A) GRADIENT CONTAINERS — Use containers with gradient backgrounds to add depth and color:
           Container `background` supports: "gradient:#COLOR1,#COLOR2" or "gradient:#A,#B,#C" for multi-stop.
           Add direction: "gradient:#FF6B6B,#4ECDC4,to_right" or "gradient:#A,#B,to_bottom_right".
           Directions: to_right, to_left, to_top, to_bottom (default), to_bottom_right, to_top_right.
           Example: Wrap a section in a container with "background": "gradient:#1a1a2e,#16213e,to_bottom_right"
           Use gradients on section containers, card backgrounds, and accent panels.

        B) ICONS — Only use icons when they serve a FUNCTIONAL purpose:
           A weather icon next to temperature, a play/pause button on a music player, a checkmark on a completed task.
           Do NOT add decorative icons just for visual flair. No gratuitous sparkles, flames, or trophies unless the user asks.
           When an icon IS appropriate, use a single well-chosen SF Symbol. Keep it small (10–14pt) and functional.

        C) BORDERS AND SHADOWS — Use container `border` and `shadow` for polish:
           Subtle borders: {"color": "accent", "width": 1} gives containers elegant edges.
           Glow effects: {"color": "#FF6B6B", "opacity": 0.4, "radius": 12, "x": 0, "y": 0} creates a neon glow.
           Depth shadows: {"color": "#000000", "opacity": 0.3, "radius": 8, "x": 0, "y": 4} lifts containers.

        D) COLOR LAYERING — Create depth with nested containers:
           Outer container with gradient background → inner container with blur or semi-transparent background.
           Use accent-colored containers (low opacity) to highlight important sections.
           Mix semantic tokens: "accent" for key data, "primary" for main text, "muted" at low opacity for dividers.

        E) VISUAL HIERARCHY THROUGH CONTAINERS — Don't just stack components flat:
           Wrap related groups in containers with subtle backgrounds, rounded corners, and padding.
           Dashboard-style widgets should have distinct visual sections, each in its own styled container.
           A weather widget looks 10x better with the temperature in a gradient-backed container with rounded corners.

        F) WIDGET-LEVEL GRADIENT BACKGROUNDS — Use gradient backgrounds at the widget level:
           "background": {"type": "gradient", "colors": ["#667eea", "#764ba2"]} for beautiful gradient widgets.
           Match gradient colors to the theme aesthetic. Dark themes → deep color gradients. Light themes → soft pastels.

        DESIGN PHILOSOPHY: Every widget should look like it belongs in a premium app. Think Apple Weather widget
        quality — not just data on a rectangle, but a crafted visual experience with color, depth, and personality.

        6. Edit behavior — SURGICAL PRECISION REQUIRED.
        When editing an existing widget:
        - You will receive the FULL existing JSON config and a specific edit request.
        - Change ONLY what the edit asks for. Treat every other field as FROZEN.
        - If the widget has 3 cities, the output must have 3 cities (unless told to add/remove).
        - If all weather uses celsius, keep ALL weather in celsius (unless told to change units).
        - Do NOT add components (weather, date, text labels) that weren't in the original unless the edit explicitly asks.
        - Do NOT remove components that were in the original unless the edit explicitly asks.
        - Preserve every timezone, location, symbol, unit, format, color, font, size, and spacing value unless the edit targets it.
        - For type conversions (digital→analog, analog→digital): swap the component type but keep ALL associated data (timezone, label, position in layout).

        RUNTIME AWARENESS — WILL IT ACTUALLY SHOW CONTENT?
        Before choosing a component, verify it will produce VISIBLE content at runtime:
        - `news_headlines`: Only works with valid RSS feed URLs. If you use an invalid/made-up URL, the widget shows "No headlines" (empty). ONLY use URLs from the known feeds list above. For topic-specific news, use `link_bookmarks` instead.
        - `weather`: Needs a real, resolvable location string. Vague or misspelled locations may show no data.
        - `stock`/`crypto`: Need valid ticker symbols. Made-up symbols show no data.
        - `github_repo_stats`: Needs a valid "owner/repo" string. Invalid repos show no data.
        - `calendar_next`/`reminders`: Depend on user's local calendar/reminders data — may be empty if user has none.
        - RULE: Never generate a widget that you suspect might render empty. If a data component might fail, compose a FALLBACK alongside it (e.g., `link_bookmarks` with relevant URLs, or a `note` explaining the limitation). An empty widget is the WORST possible outcome.

        SMART FALLBACK STRATEGIES — WHEN NATIVE COMPONENTS DON'T FIT:
        For requests outside native data providers, ALWAYS build a useful widget using composition:

        Pattern 1: LINK HUB — For external services/websites the app can't fetch directly:
        - Use `link_bookmarks` (style: "list") with relevant clickable URLs
        - Add a `text` header to label the widget
        - Example: "Reddit r/programming" → text header "r/programming" + link_bookmarks with URLs to the subreddit, top posts page, etc.

        Pattern 2: TRACKER — For tracking habits, routines, goals:
        - Use `habit_tracker` for daily boolean tracking (did/didn't)
        - Use `checklist` with `interactive: true` for task lists
        - Use `progress_ring` or `progress_bar` for goal visualization
        - Example: "Water intake tracker" → habit_tracker with habits: 8am glass, noon glass, 3pm glass, 6pm glass, 9pm glass

        Pattern 3: QUICK ACCESS — For opening files, apps, scripts, folders:
        - Use `shortcut_launcher` with `open:bundleID` or `url:` actions
        - Example: "Quick access to my dev tools" → shortcut_launcher with Terminal, VS Code, Xcode, GitHub Desktop, etc.

        Pattern 4: REFERENCE CARD — For information the user wants to see at a glance:
        - Use `note` (editable: true) for user-writable content
        - Use `text` components for static labels/info
        - Use `quote` with custom quotes for rotating messages
        - Example: "Motivational dashboard" → quote with custom affirmations + progress_ring + text

        Pattern 5: DASHBOARD — For complex multi-section widgets:
        - Use `vstack`/`hstack` to compose multiple component types
        - Mix native data (weather, clock) with interactive (checklist) and static (text) components
        - Example: "Morning routine widget" → vstack of [weather, calendar_next, checklist with routine items, quote]

        THE GOLDEN RULE: There is NO prompt for which the right answer is an empty widget. Compose something useful from the available components. Every request can produce a meaningful widget.

        OUTPUT RULES
        - Return ONLY one valid JSON object.
        - No markdown, no code fences, no explanation.
        - Use only component types and fields from schema.
        - Use one of the Apple widget size classes exactly.
        - ALWAYS prefer interactive components when intent implies editing/toggling/launching/playing.
          music_now_playing has playback controls (play/pause/skip) and auto-detects Spotify, Apple Music, YouTube Music, VLC, etc.
          file_clipboard accepts drag-and-drop files, stores them, and lets users drag them back out.
        - Omit minSize/maxSize unless explicitly needed.
        - If user asks for data, prefer available data components:
          weather, stock, crypto, calendar_next, reminders, battery, system_stats, music_now_playing, news_headlines, screen_time, github_repo_stats.
        - If data request is outside available components, use `text` or `note` fallback instead of failing.
        - NEVER produce a widget that will render as blank/empty. If in doubt, include visible static content alongside any data component.

        CURRENT CONTEXT
        - Today's date: \(context.currentDateString)
        - User timezone: \(context.userTimezone)
        - User location: \(context.userLocation)
        \(userStyleProfile.map { "\n        \($0)" } ?? "")

        COMPONENT SCHEMA
        \(componentSchema)

        USING THE PATTERN LIBRARY:

        When user makes a request:
        1. Search the library for similar patterns
        2. MIX AND MATCH components from different examples
        3. Adapt layouts (change HStack to VStack, add Grid, etc.)
        4. Use only supported built-in data components; otherwise fall back gracefully

        Examples of mixing patterns:
        - User: "time in pune, tempe, seattle with weather on right"
          Use Example 1 (multi-location time) pattern
        - User: "bitcoin ethereum gold silver prices"
          Combine Example 2 (crypto) and Example 3 (commodities)
          Use Grid layout with 2x2 = 4 items
        - User: "polymarket profile with top 3 markets"
          Use Example 5 (polymarket profile)
          Add a list of top markets below stats

        REMEMBER:
        - You have 50+ examples to learn from
        - Mix and match freely
        - Use only built-in providers; unsupported APIs must degrade gracefully
        - Complex layouts = combining HStack, VStack, Grid
        - NEVER say "I can't do that" - combine patterns
        """
    }

    func generationUserPrompt(_ prompt: String) -> String {
        return """
        USER REQUEST:
        \(prompt)

        Return one valid widget JSON object only.
        """
    }

    func editUserPrompt(existingConfig: WidgetConfig, editPrompt: String) -> String {
        let configJSON = Self.encode(existingConfig)
        let manifest = Self.buildPreservationManifest(existingConfig: existingConfig)
        let editIntelligence = Self.editReasoningHints(existingConfig: existingConfig, editPrompt: editPrompt)
        return """
        The user wants to modify an existing widget.

        Existing widget config:
        \(configJSON)

        \(manifest)

        User edit request:
        \(editPrompt)

        \(editIntelligence)

        ## STRICT EDIT RULES
        1. ONLY change what the user explicitly asked to change. Nothing else.
        2. Do NOT add components (weather, date, text, etc.) the user did not ask for.
        3. Do NOT remove cities/rows/components the user did not ask to remove.
        4. Do NOT change temperature units, timezones, locations, or any data field unless the user explicitly asked.
        5. If the widget has N cities/rows, the output MUST still have exactly N cities/rows (unless the user asked to add/remove).
        6. ALL temperature units MUST be consistent — use whatever unit the existing widget uses for ALL cities, not mixed.
        7. Preserve the exact same layout structure (vstack/hstack nesting) unless the edit requires restructuring.
        8. Preserve name, description, size, theme, background, padding, cornerRadius, refreshInterval unless the edit requires changing them.

        Return the complete updated widget JSON only.
        """
    }

    /// Build a human-readable inventory of what's in the existing widget so the AI knows exactly what to preserve.
    private static func buildPreservationManifest(existingConfig: WidgetConfig) -> String {
        var lines: [String] = ["## EXISTING WIDGET INVENTORY (preserve all unless edit says otherwise)"]

        lines.append("- Name: \"\(existingConfig.name)\"")
        lines.append("- Size: \(Int(existingConfig.size.width))x\(Int(existingConfig.size.height))")
        lines.append("- Theme: \(existingConfig.theme.rawValue)")
        lines.append("- Refresh interval: \(existingConfig.refreshInterval)s")

        // Walk the component tree and describe what's there
        var componentDescriptions: [String] = []
        describeComponents(existingConfig.content, depth: 0, into: &componentDescriptions)

        if !componentDescriptions.isEmpty {
            lines.append("- Components:")
            lines.append(contentsOf: componentDescriptions)
        }

        // Extract specific data points that must be preserved
        var dataPoints: [String] = []
        extractDataPoints(from: existingConfig.content, into: &dataPoints)
        if !dataPoints.isEmpty {
            lines.append("- Data bindings that MUST be preserved exactly:")
            lines.append(contentsOf: dataPoints.map { "  • \($0)" })
        }

        return lines.joined(separator: "\n")
    }

    /// Recursively describe each component in the tree.
    private static func describeComponents(_ component: ComponentConfig, depth: Int, into lines: inout [String]) {
        let indent = String(repeating: "  ", count: depth + 1)
        var desc = "\(indent)• \(component.type.rawValue)"

        switch component.type {
        case .clock:
            let tz = component.timezone ?? "local"
            let fmt = component.format ?? "HH:mm"
            desc += " (timezone: \(tz), format: \(fmt))"
        case .analogClock:
            let tz = component.timezone ?? "local"
            desc += " (timezone: \(tz), animated hands)"
        case .weather:
            let loc = component.location ?? "unknown"
            let unit = component.temperatureUnit ?? "unset"
            desc += " (location: \(loc), unit: \(unit))"
        case .stock:
            let sym = component.symbol ?? "?"
            desc += " (symbol: \(sym))"
        case .crypto:
            let sym = component.symbol ?? "?"
            desc += " (symbol: \(sym))"
        case .text:
            let content = component.content ?? ""
            let preview = content.count > 40 ? String(content.prefix(40)) + "..." : content
            desc += " (\"\(preview)\")"
        case .worldClocks:
            if let clocks = component.clocks {
                let labels = clocks.map { $0.label ?? $0.timezone }
                desc += " (cities: \(labels.joined(separator: ", ")))"
            }
        case .checklist:
            let interactive = component.interactive == true
            desc += " (interactive: \(interactive))"
        case .note:
            let editable = component.editable == true
            desc += " (editable: \(editable))"
        case .vstack, .hstack, .container:
            let childCount = component.children?.count ?? 0
            desc += " (\(childCount) children)"
        default:
            break
        }

        lines.append(desc)

        if let child = component.child {
            describeComponents(child, depth: depth + 1, into: &lines)
        }
        if let children = component.children {
            for entry in children {
                describeComponents(entry, depth: depth + 1, into: &lines)
            }
        }
    }

    /// Extract specific data values that must be kept consistent.
    private static func extractDataPoints(from component: ComponentConfig, into points: inout [String]) {
        if let tz = component.timezone, tz != "local" {
            points.append("timezone: \(tz)")
        }
        if let loc = component.location, !loc.isEmpty {
            let unit = component.temperatureUnit ?? "default"
            points.append("weather location: \(loc) (unit: \(unit))")
        }
        if let sym = component.symbol, !sym.isEmpty {
            points.append("\(component.type.rawValue) symbol: \(sym)")
        }

        if let child = component.child {
            extractDataPoints(from: child, into: &points)
        }
        if let children = component.children {
            for entry in children {
                extractDataPoints(from: entry, into: &points)
            }
        }
    }

    /// Generate reasoning hints about what an edit transformation implies.
    private static func editReasoningHints(existingConfig: WidgetConfig, editPrompt: String) -> String {
        let lower = editPrompt.lowercased()
        var hints: [String] = []

        let existingTypes = collectComponentTypes(from: existingConfig.content)

        // Detect what temperature unit the existing widget uses (for consistency enforcement)
        var existingUnits: Set<String> = []
        collectTemperatureUnits(from: existingConfig.content, into: &existingUnits)
        if existingUnits.count == 1, let unit = existingUnits.first {
            hints.append("CONSISTENCY: The existing widget uses \(unit) for ALL weather components. Keep ALL cities in \(unit) unless the user explicitly asks to change the unit.")
        }

        // Count existing cities/rows
        let cityCount = countCitiesOrRows(in: existingConfig.content)
        if cityCount > 1 {
            hints.append("PRESERVATION: The existing widget has \(cityCount) city rows. The output MUST have exactly \(cityCount) city rows unless the user asks to add or remove cities.")
        }

        // Detect component type transitions
        if lower.contains("analog") && existingTypes.contains(.clock) && !existingTypes.contains(.analogClock) {
            hints.append("CONVERSION: Replace each `clock` component with `analog_clock` (animated rotating hands). Preserve the SAME timezone on each. Do NOT add or remove any cities/rows.")
        }

        if lower.contains("digital") && existingTypes.contains(.analogClock) && !existingTypes.contains(.clock) {
            hints.append("CONVERSION: Replace each `analog_clock` component with `clock` (text-based time). Preserve the SAME timezone on each. Do NOT add or remove any cities/rows.")
        }

        if (lower.contains("multiple cit") || lower.contains("more cit") || lower.contains("add cit") || lower.contains("world clock")) &&
           (existingTypes.contains(.clock) || existingTypes.contains(.analogClock)) {
            hints.append("EXPANSION: Adding cities means creating additional clock components with new IANA timezones. Keep all existing cities intact.")
        }

        if lower.contains("weather") && !existingTypes.contains(.weather) {
            hints.append("ADDITION: Adding weather requires a `weather` component with `location` field. Use the same temperature unit for ALL cities. Consider upgrading size if needed.")
        }

        if lower.contains("live") || lower.contains("refresh") || lower.contains("real-time") {
            if existingConfig.refreshInterval <= 0 {
                hints.append("ADDITION: Making live requires setting `refreshInterval` (in seconds). Use 60 for most live data.")
            }
        }

        if lower.contains("interactive") || lower.contains("editable") || lower.contains("check off") {
            hints.append("MODIFICATION: Set `interactive: true` on checklist or `editable: true` on note components.")
        }

        // Check for things NOT mentioned in the edit that should NOT be touched
        if !lower.contains("weather") && !lower.contains("temperature") && !lower.contains("temp") && existingTypes.contains(.weather) {
            hints.append("NO-TOUCH: The user did NOT mention weather. Do NOT change, add, or remove any weather components or their settings.")
        }
        if !lower.contains("clock") && !lower.contains("time") && !lower.contains("analog") && !lower.contains("digital") &&
           (existingTypes.contains(.clock) || existingTypes.contains(.analogClock)) {
            hints.append("NO-TOUCH: The user did NOT mention clocks. Do NOT change clock types, timezones, or formats.")
        }

        if hints.isEmpty {
            return "EDIT PRINCIPLE: Change ONLY what was asked. Preserve everything else exactly as-is."
        }

        return "## EDIT REASONING\n" + hints.joined(separator: "\n")
    }

    /// Collect all temperature units used in the component tree.
    private static func collectTemperatureUnits(from component: ComponentConfig, into units: inout Set<String>) {
        if component.type == .weather, let unit = component.temperatureUnit, !unit.isEmpty {
            units.insert(unit)
        }
        if let child = component.child {
            collectTemperatureUnits(from: child, into: &units)
        }
        if let children = component.children {
            for entry in children {
                collectTemperatureUnits(from: entry, into: &units)
            }
        }
    }

    /// Count the number of city rows (hstack children in a vstack that contain clocks or weather).
    private static func countCitiesOrRows(in component: ComponentConfig) -> Int {
        // If this is a vstack with hstack children containing clocks/weather, count those
        if component.type == .vstack || component.type == .container {
            let clockTypes: Set<ComponentType> = [.clock, .analogClock, .weather, .worldClocks]
            var count = 0
            for child in component.children ?? [] {
                let childTypes = collectComponentTypes(from: child)
                if !childTypes.intersection(clockTypes).isEmpty {
                    count += 1
                }
            }
            if count > 0 { return count }
        }
        // Check children recursively
        if let child = component.child {
            let result = countCitiesOrRows(in: child)
            if result > 0 { return result }
        }
        if let children = component.children {
            for entry in children {
                let result = countCitiesOrRows(in: entry)
                if result > 0 { return result }
            }
        }
        return 0
    }

    private static func collectComponentTypes(from component: ComponentConfig) -> Set<ComponentType> {
        var result: Set<ComponentType> = [component.type]
        if let child = component.child {
            result.formUnion(collectComponentTypes(from: child))
        }
        if let children = component.children {
            for entry in children {
                result.formUnion(collectComponentTypes(from: entry))
            }
        }
        return result
    }

    func verificationSystemPrompt() -> String {
        """
        You are a QA reviewer for a widget app called "widgie". A user asked for a widget and the AI produced a JSON config.

        Check all of the following:
        1. Intent match: all requested components/features are present.
        2. Timezone accuracy: correct IANA timezone for requested place/timezone.
        3. Duration accuracy: timer/countdown durations exactly match request.
        4. Location accuracy: requested places are represented correctly.
        5. Unit accuracy: celsius/fahrenheit and related unit intent are honored.
        6. Size appropriateness: dimensions fit content density; avoid obvious wasted space.
        7. Style match: dark/minimal/neon/light/etc aligns with user request.
        8. Component correctness: requested component types are correct (e.g., analog_clock vs clock).
        9. Typo handling: user typos were interpreted correctly.
        10. Completeness: no obvious missing expected fields/content.
        11. Empty-space check: fail if large areas are blank and size can be reduced without harming readability.
        12. Multi-symbol stock check: if user named N symbols, ensure N stock components or explicit equivalent representation exists.
        13. Asset-class accuracy: crypto assets should use `crypto`; equities should use `stock`.
        14. Metals coverage: if user asks for gold/silver, ensure both are represented (for widgie use stock symbols GLD/SLV unless the prompt explicitly asks otherwise).
        15. Asset completeness: fail if any explicitly requested asset (BTC/ETH/gold/silver/etc.) is missing.

        RESPONSE FORMAT
        - If everything is correct, respond with exactly: PASS
        - If any issue exists, respond with:
          FAIL
          - Issue 1: ...
          - Issue 2: ...
          - Fix 1: ...
          - Fix 2: ...

        Be concrete. Name exact field/value corrections (for example timezone should be "America/Nuuk").
        """
    }

    func verificationUserPrompt(originalPrompt: String, generatedConfig: WidgetConfig) -> String {
        let configJSON = Self.encode(generatedConfig)
        return """
        THE USER ASKED FOR:
        "\(originalPrompt)"

        THE AI GENERATED THIS CONFIG:
        \(configJSON)
        """
    }

    func correctionSystemPrompt() -> String {
        """
        You are fixing a widget configuration for the app "widgie". The previous config failed QA review.

        Rules:
        - Fix ONLY the listed issues.
        - Preserve layout, styling, theme, and all correct fields.
        - Apply exact fixes for timezone/duration/location/unit/size/type/completeness issues.
        - Return ONLY the complete corrected JSON object.
        - No markdown and no explanation.
        """
    }

    func correctionUserPrompt(
        originalPrompt: String,
        currentConfig: WidgetConfig,
        verificationIssues: [String]
    ) -> String {
        let configJSON = Self.encode(currentConfig)
        let issuesText = verificationIssues
            .enumerated()
            .map { index, issue in "- \(index + 1). \(issue)" }
            .joined(separator: "\n")

        return """
        ORIGINAL USER REQUEST:
        "\(originalPrompt)"

        CURRENT CONFIG:
        \(configJSON)

        ISSUES IDENTIFIED:
        \(issuesText)

        Return a corrected JSON config that fixes exactly these issues.
        """
    }

    func retryUserPrompt(originalPrompt: String, previousResponse: String, validationError: String) -> String {
        """
        Your previous response was invalid JSON or failed schema validation.

        Original user prompt:
        \(originalPrompt)

        Previous response:
        \(previousResponse)

        Validation error:
        \(validationError)

        Important:
        - Use only schema-supported component types.
        - Do not use unknown types like "stocks" or "ticker".
        - For multi-symbol stock prompts, create one `stock` component per symbol.
        - For crypto assets (bitcoin, ethereum, etc.), use `crypto` components with symbols like BTC/ETH.
        - If user asks for "live updates", keep refreshInterval short (about 60 seconds).

        Return one corrected JSON object only.
        """
    }
    
    func schemaRepairSystemPrompt() -> String {
        """
        You are repairing an invalid widget JSON response for the app "widgie".

        Rules:
        - Return ONE valid JSON object only.
        - Use only schema-supported component types and fields.
        - Preserve user intent from the original prompt.
        - Fix malformed JSON, wrong component names, wrong field types, and missing required fields.
        - If asset names are crypto (bitcoin/ethereum/etc), use `crypto` components, not `stock`.
        - Do not include markdown, comments, or explanations.
        """
    }
    
    func schemaRepairUserPrompt(
        originalPrompt: String,
        previousResponse: String,
        validationError: String
    ) -> String {
        """
        Original user prompt:
        \(originalPrompt)

        Invalid response to repair:
        \(previousResponse)

        Validation error:
        \(validationError)

        Return a corrected JSON object that satisfies the prompt and schema.
        """
    }

    private static func loadComponentSchema() -> String {
        guard let url = Bundle.main.url(forResource: "ComponentSchema", withExtension: "json"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "{\"types\":[\"text\",\"icon\",\"divider\",\"spacer\",\"progress_ring\",\"progress_bar\",\"chart\",\"clock\",\"analog_clock\",\"date\",\"countdown\",\"timer\",\"stopwatch\",\"world_clocks\",\"pomodoro\",\"day_progress\",\"year_progress\",\"weather\",\"stock\",\"crypto\",\"calendar_next\",\"reminders\",\"battery\",\"system_stats\",\"music_now_playing\",\"news_headlines\",\"screen_time\",\"checklist\",\"habit_tracker\",\"quote\",\"note\",\"shortcut_launcher\",\"link_bookmarks\",\"file_clipboard\",\"vstack\",\"hstack\",\"container\"]}"
        }

        return text
    }

    private static func loadPatternLibrary() -> String {
        guard let url = Bundle.main.url(forResource: "WidgetPatternLibrary", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Pattern library unavailable. Still generate high-quality widgets by combining the available schema components."
        }

        return text
    }

    private static func encode(_ config: WidgetConfig) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(config),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return string
    }
}
