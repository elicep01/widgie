# widgie

widgie is a macOS menu bar app that lets you create desktop widgets by describing them in plain English.

Press `Cmd+Shift+W`, type what you want, and widgie turns your prompt into a live widget on your desktop.

## What It Does

- Creates widgets from natural language prompts
- Supports clocks, weather, stocks, crypto, reminders, calendars, notes, checklists, habits, launchers, news, system stats, GitHub widgets, and more
- Edit existing widgets by prompting again
- Runs as a menu bar app with a global hotkey
- Persists widgets and interactive state across launches
- 15 built-in themes from minimal to expressive

## Themes

widgie ships with 15 themes you can set from onboarding or settings. Picking a theme applies it to all your widgets at once.

- **Obsidian** — dark, GitHub-inspired
- **Frosted** — light glass blur
- **Neon** — dark with electric accents
- **Paper** — warm parchment tones
- **Glass** — transparent overlay
- **Pastel** — soft mint and cream
- **Sakura** — cherry blossom pink
- **Ocean** — deep navy blue
- **Sunset** — warm orange on dark
- **Lavender** — soft purple
- **Retro** — vintage warm tones
- **Cyberpunk** — neon pink/purple gamer aesthetic
- **Midnight** — deep indigo
- **Rose Gold** — elegant metallic pink
- **Mono** — minimalist grayscale

## How It Works

widgie combines two systems:

1. A native macOS widget runtime that handles layout, sizing, drag, resize, snapping, locking, persistence, and desktop placement.
2. An AI generation pipeline that interprets prompts, asks follow-up questions when needed, validates output, and repairs low-quality results before rendering.

## Features

### Prompt-to-widget

- Open the command bar with `Cmd+Shift+W`
- Type what you want in plain English
- Get clarification questions when your request is ambiguous
- The AI handles everything — data sources, layout, styling

### Widget types

- Time, date, clocks, countdowns, timers, pomodoro
- Weather (any location)
- Stocks and crypto (live prices)
- Calendar and reminders (read-only, needs macOS permissions)
- Notes, checklists, habit trackers
- Quick launch and bookmark widgets
- Music now playing, news headlines (RSS)
- System stats (CPU, RAM, battery)
- GitHub repo stats

### Desktop behavior

- Apple-style size presets (tiny, small, medium, wide, large, dashboard)
- Drag-and-snap positioning with alignment guides
- Smart placement that avoids overlapping existing widgets
- Corner resize handles
- Auto layout, locking, duplication, deletion
- Compact auto-fitting to minimize dead space

## Example Prompts

- `make a weather widget for Seattle`
- `build a compact system monitor for cpu, ram, and battery`
- `create a checklist for my morning routine`
- `add a quick launcher with Safari, Notion, and Terminal`
- `track stars for owner/repo`
- `show me bitcoin and ethereum prices`

## Getting Started

### Requirements

- macOS 13+
- Xcode 15+
- An OpenAI or Claude API key

### Run Locally

1. Open `pane.xcodeproj`
2. Select the `widgie` scheme
3. Build and run
4. Open Settings from the menu bar icon
5. Add at least one AI provider API key
6. Press `Cmd+Shift+W` and create your first widget

## Command Bar Commands

- `/list` — show all widgets
- `/remove <name>` — delete a widget
- `/theme <name>` — apply a theme to all widgets
- `/layout auto` — auto-arrange widgets on screen
- `/templates` — list saved templates
- `/template <name>` — create widget from template
- `/export` — export all widgets
- `/import` — import widgets
- `/settings` — open settings

## Data Sources

Built-in data providers:

- Weather (Open-Meteo, any location)
- Stocks (Yahoo Finance)
- Crypto (CoinGecko, any coin)
- Battery and system stats
- Music now playing (Apple Music)
- News headlines (RSS feeds)
- Screen time (app names)
- GitHub repo stats
- Calendar and Reminders (EventKit, read-only)

## Architecture

```
Prompt (Cmd+Shift+W)
  -> Command Bar
  -> AppCoordinator
  -> AgentOrchestrator (plan, clarify, verify)
  -> AI Provider (OpenAI or Claude)
  -> Schema Validation + Repair
  -> WidgetConfig
  -> WidgetManager
  -> Desktop Widget Window
```

## Tests

Tests are in `paneTests/` and `paneUITests/`.

Build from terminal:

```bash
xcodebuild -project pane.xcodeproj -scheme widgie -configuration Debug build
```

Run AI end-to-end tests:

```bash
PANE_RUN_E2E_AI_TESTS=1 \
OPENAI_API_KEY="$OPENAI_API_KEY" \
xcodebuild -project pane.xcodeproj -scheme widgie -configuration Debug -only-testing:paneTests/PipelineE2ETests test
```
