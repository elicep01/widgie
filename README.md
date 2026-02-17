# pane

pane is a macOS desktop widget app powered by AI.

Press `Cmd+Shift+W`, describe what you want, and pane generates a widget for your desktop.

## What it does

- Creates desktop widgets from natural language prompts
- Uses OpenAI or Claude for widget generation
- Verifies and corrects generated configs before rendering
- Supports live and interactive widgets (time, weather, productivity, and more)
- Saves widgets and restores them on app launch

## Quick start

1. Open `pane.xcodeproj` in Xcode.
2. Build and run the `pane` target.
3. Open Settings and add an OpenAI or Claude API key.
4. Press `Cmd+Shift+W` and type a widget prompt.

## Notes

- API keys are stored in Keychain.
- pane requires a provider API key to generate widgets.
- The app name is `pane`.
