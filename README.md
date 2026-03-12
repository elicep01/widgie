# widgie

**AI-powered desktop widgets for macOS.** Describe what you want in plain English — widgie builds it, places it on your desktop, and keeps it live.

Press `⌘⇧W`, type "weather for Tokyo", and a live weather widget appears on your desktop in seconds.

---

## Features

### Prompt-to-Widget
Type what you want and widgie's AI agent handles everything — layout, data sources, styling, and placement. No drag-and-drop builders, no configuration panels. Just describe it.

```
"minimal clock with date below"
"bitcoin and ethereum prices side by side"
"checklist for my morning routine"
"5-day weather forecast for London in celsius"
"track stars for torvalds/linux"
```

### Conversational Editing
Chat with widgie to refine your widgets iteratively. The AI remembers your full conversation history, so you can say things like:

- "make the font bigger"
- "add a 3-day forecast below the current weather"
- "change the location to Paris"
- "remove the clock and add a countdown to Jan 1"

After each change, widgie tells you exactly what it modified.

### 30+ Gallery Widgets
Browse pre-built widgets across 9 categories and add them to your desktop with one click:

| Category | Examples |
|----------|----------|
| **Time** | Minimal clock, analog clock, world clocks, countdown, stopwatch |
| **Weather** | Current conditions, 5-day forecast, multi-city |
| **Finance** | Stock ticker, crypto tracker, portfolio dashboard |
| **Productivity** | Checklist, notes, pomodoro timer, calendar, reminders |
| **Health** | Habit tracker, mood tracker, meditation, breathing exercise |
| **System** | CPU/RAM/disk monitor, battery ring, screen time |
| **Media** | Now playing (Spotify/Apple Music), news headlines (RSS) |
| **Inspiration** | Quote of the day, year progress, virtual pet |
| **Dashboard** | Morning dashboard, finance overview, productivity HQ |

### 15 Themes
One-click theme switching that applies across all widgets:

**Obsidian** · **Frosted** · **Neon** · **Paper** · **Glass** · **Pastel** · **Sakura** · **Ocean** · **Sunset** · **Lavender** · **Retro** · **Cyberpunk** · **Midnight** · **Rose Gold** · **Mono**

### Native Desktop Experience
- **Drag & snap** — alignment guides and smart edge snapping
- **Resize** — corner handles with Apple-style size presets (tiny → dashboard)
- **Auto layout** — arrange all widgets neatly with `⌘L`
- **Lock/unlock** — prevent accidental moves
- **Persistent** — widgets, positions, sizes, and interactive state survive restarts
- **Menu bar app** — runs quietly, no Dock icon

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧W` | Toggle widgie window |
| `⌘G` | Open gallery |
| `⌘N` | New widget conversation |
| `⌘L` | Auto layout all widgets |

### Live Data Sources
All data updates automatically — no manual refresh needed:

- **Weather** — Open-Meteo (any city worldwide)
- **Stocks** — Yahoo Finance (any ticker)
- **Crypto** — CoinGecko (any coin)
- **Calendar & Reminders** — macOS EventKit (read-only)
- **Music** — Apple Music / Spotify now playing
- **News** — RSS feeds (BBC, CNN, Reuters, NPR, and more)
- **System** — CPU, RAM, disk, battery
- **GitHub** — Stars, forks, issues for any repo
- **Screen Time** — Active app tracking

### AI Providers
Choose your preferred AI backend:

- **OpenAI** — gpt-4o, o3-mini, o1
- **Claude** — Opus 4.5, Sonnet 4.5, Haiku 4.5

---

## Getting Started

### Requirements
- macOS 15.5+ (Sequoia)
- An OpenAI or Claude API key

### Install from DMG
1. Download `widgie-1.0.dmg` from [Releases](https://github.com/elicep01/widgie/releases)
2. Drag **widgie** to Applications
3. Open widgie — it appears in your menu bar
4. Complete onboarding: add your API key, pick a theme, set your preferences
5. Press `⌘⇧W` and create your first widget

### Build from Source
```bash
git clone https://github.com/elicep01/widgie.git
cd widgie
open pane.xcodeproj
# Select the "widgie" scheme → Build & Run
```

### Build for Distribution
```bash
./scripts/build-release.sh
# Output: build/widgie-1.0.dmg and build/widgie-1.0.zip
```

---

## How It Works

```
User prompt
  → Agent Orchestrator (plan, research, clarify if needed)
  → AI Provider (OpenAI or Claude)
  → Generation Pipeline (generate → validate → verify → repair)
  → Widget Config (JSON schema)
  → Widget Renderer (SwiftUI)
  → Desktop Window (AppKit)
```

The agent runs autonomously — it plans what data sources to use, asks clarification questions only when it literally cannot build without an answer (e.g., "which stock ticker?"), generates the widget, runs a critique/repair loop to catch issues, and places the result on your desktop. Build first, refine after.

---

## Widget Types

widgie supports 35+ component types that can be composed into any layout:

**Time & Date** — clock, analog clock, date, countdown, timer, stopwatch, world clocks, pomodoro, day progress, year progress

**Data** — weather, stock, crypto, calendar, reminders, news headlines, GitHub stats, system stats, battery, screen time

**Interactive** — checklist, habit tracker, mood tracker, note, quote, shortcut launcher, link bookmarks

**Health** — period tracker, breathing exercise, meditation, virtual pet

**Layout** — VStack, HStack, container with full nesting support

**Visual** — progress ring, progress bar, chart, icon, text, divider, spacer

---

## Command Bar

The command bar (`⌘⇧W`) also supports slash commands:

| Command | Action |
|---------|--------|
| `/list` | Show all widgets |
| `/remove <name>` | Delete a widget |
| `/theme <name>` | Apply theme to all widgets |
| `/layout auto` | Auto-arrange widgets |
| `/templates` | List saved templates |
| `/template <name>` | Create from template |
| `/export` | Export all widgets |
| `/import` | Import widgets |
| `/settings` | Open settings |

---

## Architecture

- **Swift + AppKit + SwiftUI** — native macOS, no Electron
- **App Sandbox** — full sandboxing with network, automation, and file access entitlements
- **Hardened Runtime** — code-signed and ready for notarization
- **Launch at Login** — via SMAppService (macOS native)
- **Keychain** — API keys stored securely in macOS Keychain
- **Persistence** — widgets stored as JSON in Application Support

Key files:
- `pane/AI/AgentOrchestrator.swift` — planning engine (data plan, critique, repair)
- `pane/AI/GenerationPipeline.swift` — generation → validation → verification → correction
- `pane/AI/PromptBuilder.swift` — system prompt and edit prompt construction
- `pane/App/AppCoordinator.swift` — main app flow coordinator
- `pane/Rendering/WidgetRenderer.swift` — SwiftUI component renderers
- `pane/Models/ComponentConfig.swift` — widget schema and component types

---

## Tests

```bash
# Build
xcodebuild -project pane.xcodeproj -scheme widgie -configuration Debug build

# Run AI end-to-end tests (requires API key)
PANE_RUN_E2E_AI_TESTS=1 \
OPENAI_API_KEY="$OPENAI_API_KEY" \
xcodebuild -project pane.xcodeproj -scheme widgie -configuration Debug \
  -only-testing:paneTests/PipelineE2ETests test
```

---

## License

Copyright © 2026 Elice Priyadarshini. All rights reserved.
