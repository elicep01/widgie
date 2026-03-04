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
