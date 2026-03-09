import Foundation
import SwiftUI

struct ThemePalette {
    let primary: Color
    let secondary: Color
    let accent: Color
    let positive: Color
    let negative: Color
    let warning: Color
    let muted: Color
}

struct ThemeSurfaceStyle {
    let innerBorderColor: Color
    let innerBorderOpacity: Double
    let innerBorderWidth: Double
    let shadowColor: Color
    let shadowOpacity: Double
    let shadowRadius: Double
    let shadowX: Double
    let shadowY: Double
}

struct ThemeResolver {
    private static let cacheLock = NSLock()
    private static var themeCache: [WidgetTheme: ThemeDefinition] = [:]

    static func palette(for theme: WidgetTheme) -> ThemePalette {
        let resolved = normalized(theme)

        if let definition = themeDefinition(for: resolved) {
            return ThemePalette(
                primary: Color(hex: definition.colors.primary),
                secondary: Color(hex: definition.colors.secondary),
                accent: Color(hex: definition.colors.accent),
                positive: Color(hex: definition.colors.positive),
                negative: Color(hex: definition.colors.negative),
                warning: Color(hex: definition.colors.warning),
                muted: Color(hex: definition.colors.muted)
            )
        }

        return fallbackPalette(for: resolved)
    }

    static func surface(for theme: WidgetTheme) -> ThemeSurfaceStyle {
        let resolved = normalized(theme)

        if let definition = themeDefinition(for: resolved),
           let surface = definition.surface {
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: surface.innerBorderColor),
                innerBorderOpacity: surface.innerBorderOpacity,
                innerBorderWidth: surface.innerBorderWidth,
                shadowColor: Color(hex: surface.shadowColor),
                shadowOpacity: surface.shadowOpacity,
                shadowRadius: surface.shadowRadius,
                shadowX: surface.shadowX,
                shadowY: surface.shadowY
            )
        }

        return fallbackSurface(for: resolved)
    }

    static func color(for token: String?, theme: WidgetTheme) -> Color {
        guard let token else {
            return palette(for: theme).primary
        }

        let lower = token.lowercased()
        if lower.hasPrefix("#") {
            return Color(hex: lower)
        }

        let palette = palette(for: theme)
        switch lower {
        case "primary":
            return palette.primary
        case "secondary":
            return palette.secondary
        case "accent":
            return palette.accent
        case "positive":
            return palette.positive
        case "negative":
            return palette.negative
        case "warning":
            return palette.warning
        case "muted":
            return palette.muted
        default:
            return palette.primary
        }
    }

    private static func normalized(_ theme: WidgetTheme) -> WidgetTheme {
        theme.canonical
    }

    private static func themeDefinition(for theme: WidgetTheme) -> ThemeDefinition? {
        cacheLock.lock()
        if let cached = themeCache[theme] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let bundledURL = Bundle.main.url(forResource: theme.rawValue, withExtension: "json", subdirectory: "Themes")
            ?? Bundle.main.url(forResource: theme.rawValue, withExtension: "json")

        guard let url = bundledURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ThemeDefinition.self, from: data) else {
            return nil
        }

        cacheLock.lock()
        themeCache[theme] = decoded
        cacheLock.unlock()
        return decoded
    }

    private static func fallbackPalette(for theme: WidgetTheme) -> ThemePalette {
        // Legacy themes are already mapped via normalized() → canonical
        switch theme {
        case .obsidian:
            // Apple Dark — inspired by macOS dark mode system colors
            return ThemePalette(
                primary: Color(hex: "#F5F5F7"),
                secondary: Color(hex: "#86868B"),
                accent: Color(hex: "#0A84FF"),
                positive: Color(hex: "#30D158"),
                negative: Color(hex: "#FF453A"),
                warning: Color(hex: "#FFD60A"),
                muted: Color(hex: "#636366")
            )
        case .frosted:
            // Apple Light — inspired by macOS light mode system colors
            return ThemePalette(
                primary: Color(hex: "#1D1D1F"),
                secondary: Color(hex: "#6E6E73"),
                accent: Color(hex: "#007AFF"),
                positive: Color(hex: "#28CD41"),
                negative: Color(hex: "#FF3B30"),
                warning: Color(hex: "#FF9F0A"),
                muted: Color(hex: "#AEAEB2")
            )
        case .transparent:
            // Glass — high-contrast whites for vibrancy backgrounds
            return ThemePalette(
                primary: Color(hex: "#FFFFFF"),
                secondary: Color(hex: "#CCCCCC"),
                accent: Color(hex: "#64D2FF"),
                positive: Color(hex: "#30D158"),
                negative: Color(hex: "#FF6961"),
                warning: Color(hex: "#FFD60A"),
                muted: Color(hex: "#98989D")
            )
        case .mono:
            // Minimal B&W — no color, pure typography
            return ThemePalette(
                primary: Color(hex: "#000000"),
                secondary: Color(hex: "#6E6E73"),
                accent: Color(hex: "#1D1D1F"),
                positive: Color(hex: "#1D7A3E"),
                negative: Color(hex: "#BF3030"),
                warning: Color(hex: "#8A6E00"),
                muted: Color(hex: "#AEAEB2")
            )
        case .paper:
            // Warm editorial — cream, sepia ink, muted earth tones
            return ThemePalette(
                primary: Color(hex: "#2C2418"),
                secondary: Color(hex: "#7A6E5C"),
                accent: Color(hex: "#8B5E3C"),
                positive: Color(hex: "#4A7C50"),
                negative: Color(hex: "#A03C2E"),
                warning: Color(hex: "#8A6E1E"),
                muted: Color(hex: "#9C9080")
            )
        default:
            return fallbackPalette(for: theme.canonical)
        }
    }

    private static func fallbackSurface(for theme: WidgetTheme) -> ThemeSurfaceStyle {
        switch theme {
        case .obsidian:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FFFFFF"),
                innerBorderOpacity: 0.08,
                innerBorderWidth: 0.5,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.4,
                shadowRadius: 20,
                shadowX: 0,
                shadowY: 8
            )
        case .frosted:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FFFFFF"),
                innerBorderOpacity: 0.6,
                innerBorderWidth: 0.5,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.12,
                shadowRadius: 16,
                shadowX: 0,
                shadowY: 6
            )
        case .transparent:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FFFFFF"),
                innerBorderOpacity: 0.15,
                innerBorderWidth: 0.5,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.25,
                shadowRadius: 18,
                shadowX: 0,
                shadowY: 7
            )
        case .mono:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#000000"),
                innerBorderOpacity: 0.1,
                innerBorderWidth: 1.0,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.06,
                shadowRadius: 8,
                shadowX: 0,
                shadowY: 2
            )
        case .paper:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#D4C8B0"),
                innerBorderOpacity: 0.4,
                innerBorderWidth: 0.5,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.15,
                shadowRadius: 14,
                shadowX: 0,
                shadowY: 6
            )
        default:
            return fallbackSurface(for: theme.canonical)
        }
    }
}

private struct ThemeDefinition: Decodable {
    let colors: ThemeColorTokens
    let surface: ThemeSurfaceTokens?
}

private struct ThemeColorTokens: Decodable {
    let primary: String
    let secondary: String
    let accent: String
    let positive: String
    let negative: String
    let warning: String
    let muted: String
}

private struct ThemeSurfaceTokens: Decodable {
    let innerBorderColor: String
    let innerBorderOpacity: Double
    let innerBorderWidth: Double
    let shadowColor: String
    let shadowOpacity: Double
    let shadowRadius: Double
    let shadowX: Double
    let shadowY: Double
}

extension Color {
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .uppercased()

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red, green, blue, alpha: UInt64
        switch cleaned.count {
        case 3:
            (red, green, blue, alpha) = (
                ((value >> 8) & 0xF) * 17,
                ((value >> 4) & 0xF) * 17,
                (value & 0xF) * 17,
                255
            )
        case 6:
            (red, green, blue, alpha) = (
                (value >> 16) & 0xFF,
                (value >> 8) & 0xFF,
                value & 0xFF,
                255
            )
        case 8:
            (red, green, blue, alpha) = (
                (value >> 24) & 0xFF,
                (value >> 16) & 0xFF,
                (value >> 8) & 0xFF,
                value & 0xFF
            )
        default:
            (red, green, blue, alpha) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
