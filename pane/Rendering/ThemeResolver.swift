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
        theme == .custom ? .obsidian : theme
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
        switch theme {
        case .obsidian:
            return ThemePalette(
                primary: Color(hex: "#E6EDF3"),
                secondary: Color(hex: "#8B949E"),
                accent: Color(hex: "#58A6FF"),
                positive: Color(hex: "#3FB950"),
                negative: Color(hex: "#F85149"),
                warning: Color(hex: "#D29922"),
                muted: Color(hex: "#7A8696")   // was #484F58 — 2.3:1 (dark on dark) → 5.0:1
            )
        case .frosted:
            return ThemePalette(
                primary: Color(hex: "#1A1A1A"),
                secondary: Color(hex: "#5D6470"),
                accent: Color(hex: "#0066CC"),  // was #0A84FF — 3.65:1 → 5.56:1
                positive: Color(hex: "#1A7A4E"), // was #2FA56A — 3.1:1  → 5.4:1
                negative: Color(hex: "#C23333"), // was #D14B4B — 4.36:1 → 5.5:1
                warning: Color(hex: "#8A6000"),  // was #B27B1D — 3.67:1 → 5.6:1
                muted: Color(hex: "#6B7280")     // was #A4ACB8 — 2.3:1  → 4.8:1
            )
        case .neon:
            return ThemePalette(
                primary: Color(hex: "#F3F7FF"),
                secondary: Color(hex: "#8FA6C4"),
                accent: Color(hex: "#18F0FF"),
                positive: Color(hex: "#1CFF8A"),
                negative: Color(hex: "#FF4E9A"),
                warning: Color(hex: "#FFD447"),
                muted: Color(hex: "#6F8FAE")    // was #3C4D6F — 2.34:1 (dark on dark) → 5.9:1
            )
        case .paper:
            return ThemePalette(
                primary: Color(hex: "#2C261F"),
                secondary: Color(hex: "#6A5E50"),
                accent: Color(hex: "#7A5020"),   // was #9D6E3A — 3.88:1 → 6.1:1
                positive: Color(hex: "#3D6235"), // was #567E4A — 4.09:1 → 6.1:1
                negative: Color(hex: "#963830"), // was #AD5042 — 4.58:1 → 6.3:1
                warning: Color(hex: "#7A5C00"),  // was #B48633 — 2.86:1 → 5.45:1
                muted: Color(hex: "#726659")     // was #CDBEAB — 1.59:1 → 4.9:1
            )
        case .transparent:
            return ThemePalette(
                primary: Color(hex: "#FFFFFF"),
                secondary: Color(hex: "#D9E0EA"),
                accent: Color(hex: "#8BC4FF"),
                positive: Color(hex: "#5EE08F"),
                negative: Color(hex: "#FF7B86"),
                warning: Color(hex: "#E9BF66"),
                muted: Color(hex: "#9BA9BB")
            )
        case .pastel:
            // Soft candy colors on cream — mint, peach, baby blue
            return ThemePalette(
                primary: Color(hex: "#4A3F5C"),
                secondary: Color(hex: "#8878A0"),
                accent: Color(hex: "#A8D8B9"),
                positive: Color(hex: "#7CC9A0"),
                negative: Color(hex: "#E8889A"),
                warning: Color(hex: "#F0C77E"),
                muted: Color(hex: "#B0A8C0")
            )
        case .sakura:
            // Japanese cherry blossom — vivid pinks, blush, deep rose
            return ThemePalette(
                primary: Color(hex: "#4D1A33"),
                secondary: Color(hex: "#A0506E"),
                accent: Color(hex: "#FF6B9D"),
                positive: Color(hex: "#7BC68F"),
                negative: Color(hex: "#E0405A"),
                warning: Color(hex: "#FFAA6E"),
                muted: Color(hex: "#C0708A")
            )
        case .ocean:
            // Deep sea — dark navy, teal, aquamarine, coral accents
            return ThemePalette(
                primary: Color(hex: "#D0F0FF"),
                secondary: Color(hex: "#5BA8C8"),
                accent: Color(hex: "#00D4AA"),
                positive: Color(hex: "#00E5A0"),
                negative: Color(hex: "#FF6B6B"),
                warning: Color(hex: "#FFD166"),
                muted: Color(hex: "#4A90A8")
            )
        case .sunset:
            // Warm dusk sky — deep orange, magenta, warm purple on dark
            return ThemePalette(
                primary: Color(hex: "#FFE8D6"),
                secondary: Color(hex: "#D4906A"),
                accent: Color(hex: "#FF6D3F"),
                positive: Color(hex: "#7AE08A"),
                negative: Color(hex: "#FF4477"),
                warning: Color(hex: "#FFBB44"),
                muted: Color(hex: "#B07858")
            )
        case .lavender:
            // Dreamy purple — lilac background, violet accents, soft plum
            return ThemePalette(
                primary: Color(hex: "#3B2066"),
                secondary: Color(hex: "#8A6EBB"),
                accent: Color(hex: "#B47EFF"),
                positive: Color(hex: "#6EDD8A"),
                negative: Color(hex: "#FF6090"),
                warning: Color(hex: "#FFD06E"),
                muted: Color(hex: "#9080C0")
            )
        case .retro:
            // 70s/80s vintage — mustard, burnt orange, olive, brown tones
            return ThemePalette(
                primary: Color(hex: "#3D2B1A"),
                secondary: Color(hex: "#8A6E44"),
                accent: Color(hex: "#E8A030"),
                positive: Color(hex: "#7AAA40"),
                negative: Color(hex: "#D05530"),
                warning: Color(hex: "#F0C030"),
                muted: Color(hex: "#9A8460")
            )
        case .cyberpunk:
            // Neon pink/cyan on pure black — electric, high contrast
            return ThemePalette(
                primary: Color(hex: "#EEFFFF"),
                secondary: Color(hex: "#00FFEE"),
                accent: Color(hex: "#FF00AA"),
                positive: Color(hex: "#00FF88"),
                negative: Color(hex: "#FF0055"),
                warning: Color(hex: "#FFE600"),
                muted: Color(hex: "#6680AA")
            )
        case .midnight:
            // Deep blue-black — indigo, royal blue, starlight silver
            return ThemePalette(
                primary: Color(hex: "#E0EAFF"),
                secondary: Color(hex: "#7090CC"),
                accent: Color(hex: "#4466FF"),
                positive: Color(hex: "#44DDAA"),
                negative: Color(hex: "#FF5577"),
                warning: Color(hex: "#FFCC44"),
                muted: Color(hex: "#5570A0")
            )
        case .roseGold:
            // Luxury metallic — copper, champagne, blush on warm cream
            return ThemePalette(
                primary: Color(hex: "#4A2A2A"),
                secondary: Color(hex: "#B08070"),
                accent: Color(hex: "#D4956E"),
                positive: Color(hex: "#6EAA7E"),
                negative: Color(hex: "#CC4455"),
                warning: Color(hex: "#D4A855"),
                muted: Color(hex: "#B09088")
            )
        case .mono:
            // Pure black and white — no color, just grayscale contrast
            return ThemePalette(
                primary: Color(hex: "#111111"),
                secondary: Color(hex: "#666666"),
                accent: Color(hex: "#333333"),
                positive: Color(hex: "#2D6E40"),
                negative: Color(hex: "#993333"),
                warning: Color(hex: "#7A6622"),
                muted: Color(hex: "#999999")
            )
        case .custom:
            return fallbackPalette(for: .obsidian)
        }
    }

    private static func fallbackSurface(for theme: WidgetTheme) -> ThemeSurfaceStyle {
        switch theme {
        case .obsidian:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FFFFFF"),
                innerBorderOpacity: 0.06,
                innerBorderWidth: 0.5,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.35,
                shadowRadius: 20,
                shadowX: 0,
                shadowY: 8
            )
        case .frosted:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FFFFFF"),
                innerBorderOpacity: 0.5,
                innerBorderWidth: 0.8,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.16,
                shadowRadius: 16,
                shadowX: 0,
                shadowY: 6
            )
        case .neon:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#18F0FF"),
                innerBorderOpacity: 0.16,
                innerBorderWidth: 0.9,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.42,
                shadowRadius: 24,
                shadowX: 0,
                shadowY: 10
            )
        case .paper:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FFFFFF"),
                innerBorderOpacity: 0.42,
                innerBorderWidth: 0.7,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.18,
                shadowRadius: 18,
                shadowX: 0,
                shadowY: 7
            )
        case .transparent:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FFFFFF"),
                innerBorderOpacity: 0.12,
                innerBorderWidth: 0.6,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.22,
                shadowRadius: 18,
                shadowX: 0,
                shadowY: 7
            )
        case .pastel:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FFFFFF"),
                innerBorderOpacity: 0.7,
                innerBorderWidth: 1.0,
                shadowColor: Color(hex: "#C0B0D0"),
                shadowOpacity: 0.18,
                shadowRadius: 16,
                shadowX: 0,
                shadowY: 6
            )
        case .sakura:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FF90B0"),
                innerBorderOpacity: 0.35,
                innerBorderWidth: 1.0,
                shadowColor: Color(hex: "#FF6090"),
                shadowOpacity: 0.16,
                shadowRadius: 18,
                shadowX: 0,
                shadowY: 6
            )
        case .ocean:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#00D4AA"),
                innerBorderOpacity: 0.15,
                innerBorderWidth: 0.8,
                shadowColor: Color(hex: "#002040"),
                shadowOpacity: 0.5,
                shadowRadius: 24,
                shadowX: 0,
                shadowY: 10
            )
        case .sunset:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FF6D3F"),
                innerBorderOpacity: 0.15,
                innerBorderWidth: 0.8,
                shadowColor: Color(hex: "#200008"),
                shadowOpacity: 0.45,
                shadowRadius: 22,
                shadowX: 0,
                shadowY: 8
            )
        case .lavender:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#B47EFF"),
                innerBorderOpacity: 0.3,
                innerBorderWidth: 1.0,
                shadowColor: Color(hex: "#8050C0"),
                shadowOpacity: 0.14,
                shadowRadius: 18,
                shadowX: 0,
                shadowY: 6
            )
        case .retro:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#E8A030"),
                innerBorderOpacity: 0.3,
                innerBorderWidth: 1.2,
                shadowColor: Color(hex: "#8A6030"),
                shadowOpacity: 0.2,
                shadowRadius: 10,
                shadowX: 0,
                shadowY: 4
            )
        case .cyberpunk:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#FF00AA"),
                innerBorderOpacity: 0.3,
                innerBorderWidth: 1.2,
                shadowColor: Color(hex: "#FF00AA"),
                shadowOpacity: 0.25,
                shadowRadius: 30,
                shadowX: 0,
                shadowY: 0
            )
        case .midnight:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#4466FF"),
                innerBorderOpacity: 0.15,
                innerBorderWidth: 0.8,
                shadowColor: Color(hex: "#000030"),
                shadowOpacity: 0.5,
                shadowRadius: 24,
                shadowX: 0,
                shadowY: 10
            )
        case .roseGold:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#D4956E"),
                innerBorderOpacity: 0.35,
                innerBorderWidth: 1.0,
                shadowColor: Color(hex: "#C09070"),
                shadowOpacity: 0.16,
                shadowRadius: 16,
                shadowX: 0,
                shadowY: 6
            )
        case .mono:
            return ThemeSurfaceStyle(
                innerBorderColor: Color(hex: "#000000"),
                innerBorderOpacity: 0.08,
                innerBorderWidth: 1.0,
                shadowColor: Color(hex: "#000000"),
                shadowOpacity: 0.08,
                shadowRadius: 8,
                shadowX: 0,
                shadowY: 2
            )
        case .custom:
            return fallbackSurface(for: .obsidian)
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
