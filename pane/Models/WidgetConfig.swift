import Foundation

struct WidgetConfig: Codable, Identifiable {
    var version: String
    var id: UUID
    var name: String
    var description: String
    var size: WidgetSize
    var minSize: WidgetSize?
    var maxSize: WidgetSize?
    var position: WidgetPosition?
    var theme: WidgetTheme
    var background: BackgroundConfig
    var cornerRadius: Double
    var padding: EdgeInsetsConfig
    var refreshInterval: Int
    var content: ComponentConfig
    var dataSources: [String: DataSourceConfig]?

    /// True when the widget tree contains buttons or other clickable elements.
    var hasInteractiveContent: Bool { content.hasInteractiveContent }

    init(
        version: String = "1.0",
        id: UUID = UUID(),
        name: String,
        description: String,
        size: WidgetSize = .medium,
        minSize: WidgetSize? = nil,
        maxSize: WidgetSize? = WidgetSize(width: 500, height: 350),
        position: WidgetPosition? = nil,
        theme: WidgetTheme = .obsidian,
        background: BackgroundConfig? = nil,
        cornerRadius: Double = 20,
        padding: EdgeInsetsConfig = .medium,
        refreshInterval: Int = 60,
        content: ComponentConfig,
        dataSources: [String: DataSourceConfig]? = nil
    ) {
        self.version = version
        self.id = id
        self.name = name
        self.description = description
        self.size = size
        self.minSize = minSize
        self.maxSize = maxSize
        self.position = position
        self.theme = theme
        self.background = background ?? BackgroundConfig.default(for: theme)
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.refreshInterval = refreshInterval
        self.content = content
        self.dataSources = dataSources
    }

    enum CodingKeys: String, CodingKey {
        case version
        case id
        case name
        case description
        case size
        case minSize
        case maxSize
        case position
        case theme
        case background
        case cornerRadius
        case padding
        case refreshInterval
        case content
        case dataSources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Custom Widget"

        let decodedTheme = try container.decodeIfPresent(WidgetTheme.self, forKey: .theme) ?? .obsidian
        theme = decodedTheme

        description = try container.decodeIfPresent(String.self, forKey: .description) ?? name
        size = try container.decodeIfPresent(WidgetSize.self, forKey: .size) ?? .medium
        minSize = try container.decodeIfPresent(WidgetSize.self, forKey: .minSize)
        maxSize = try container.decodeIfPresent(WidgetSize.self, forKey: .maxSize) ?? WidgetSize(width: 500, height: 350)
        position = try container.decodeIfPresent(WidgetPosition.self, forKey: .position)
        background = try container.decodeIfPresent(BackgroundConfig.self, forKey: .background) ?? BackgroundConfig.default(for: decodedTheme)
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 20
        padding = try container.decodeIfPresent(EdgeInsetsConfig.self, forKey: .padding) ?? .medium
        refreshInterval = try container.decodeIfPresent(Int.self, forKey: .refreshInterval) ?? 60
        content = try container.decode(ComponentConfig.self, forKey: .content)
        dataSources = try container.decodeIfPresent([String: DataSourceConfig].self, forKey: .dataSources)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(size, forKey: .size)
        try container.encodeIfPresent(minSize, forKey: .minSize)
        try container.encodeIfPresent(maxSize, forKey: .maxSize)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encode(theme, forKey: .theme)
        try container.encode(background, forKey: .background)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(padding, forKey: .padding)
        try container.encode(refreshInterval, forKey: .refreshInterval)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(dataSources, forKey: .dataSources)
    }
}

struct WidgetSize: Codable {
    var width: Double
    var height: Double

    static let tiny = WidgetSize(width: 170, height: 170)
    static let small = WidgetSize(width: 170, height: 170)
    static let medium = WidgetSize(width: 320, height: 180)
    static let wide = WidgetSize(width: 480, height: 180)
    static let large = WidgetSize(width: 320, height: 360)
    static let dashboard = WidgetSize(width: 480, height: 360)

    static let appleWallpaperPresets: [WidgetSize] = [
        .tiny, .medium, .wide, .large, .dashboard
    ]

    func snappedToAppleWallpaperPreset() -> WidgetSize {
        guard let nearest = Self.appleWallpaperPresets.min(by: { lhs, rhs in
            distanceSquared(to: lhs) < distanceSquared(to: rhs)
        }) else {
            return self
        }
        return nearest
    }

    private func distanceSquared(to other: WidgetSize) -> Double {
        let dw = width - other.width
        let dh = height - other.height
        return (dw * dw) + (dh * dh)
    }
}

struct WidgetPosition: Codable {
    var x: Double
    var y: Double
}

enum WidgetTheme: String, Codable, CaseIterable {
    // Active themes (Mac-native)
    case obsidian       // Dark mode — deep charcoal, blue accent
    case frosted        // Light mode — white glass, system blue
    case transparent    // Glass — vibrancy, translucent
    case mono           // Minimal — pure black & white
    case paper          // Warm — cream, ink, editorial

    // Legacy themes (kept for backward compat, mapped to active themes)
    case neon
    case pastel
    case sakura
    case ocean
    case sunset
    case lavender
    case retro
    case cyberpunk
    case midnight
    case roseGold = "rose_gold"
    case custom

    /// The 5 active Mac-native themes shown in UI.
    static var activeThemes: [WidgetTheme] {
        [.obsidian, .frosted, .transparent, .mono, .paper]
    }

    /// Maps legacy themes to their closest active equivalent.
    var canonical: WidgetTheme {
        switch self {
        case .obsidian, .frosted, .transparent, .mono, .paper:
            return self
        case .neon, .cyberpunk, .midnight, .ocean:
            return .obsidian      // dark themes → obsidian
        case .pastel, .sakura, .lavender, .roseGold:
            return .frosted       // light colorful → frosted
        case .sunset:
            return .obsidian      // dark warm → obsidian
        case .retro:
            return .paper         // warm vintage → paper
        case .custom:
            return .obsidian
        }
    }
}

struct BackgroundConfig: Codable {
    var type: String
    var material: String?
    var tintColor: String?
    var tintOpacity: Double?
    var color: String?
    var colors: [String]?
    var direction: String?

    static func `default`(for theme: WidgetTheme) -> BackgroundConfig {
        switch theme.canonical {
        case .obsidian:
            return BackgroundConfig(
                type: "blur",
                material: "hudWindow",
                tintColor: "#1C1C1E",
                tintOpacity: 0.72
            )
        case .frosted:
            return BackgroundConfig(
                type: "blur",
                material: "popover",
                tintColor: "#FFFFFF",
                tintOpacity: 0.55
            )
        case .transparent:
            return BackgroundConfig(
                type: "blur",
                material: "hudWindow",
                tintColor: "#000000",
                tintOpacity: 0.25
            )
        case .mono:
            return BackgroundConfig(
                type: "solid",
                color: "#FFFFFF"
            )
        case .paper:
            return BackgroundConfig(
                type: "solid",
                color: "#F5F0E8"
            )
        default:
            return BackgroundConfig(
                type: "blur",
                material: "hudWindow",
                tintColor: "#1C1C1E",
                tintOpacity: 0.72
            )
        }
    }
}

struct EdgeInsetsConfig: Codable {
    var top: Double
    var bottom: Double
    var leading: Double
    var trailing: Double

    static let medium = EdgeInsetsConfig(top: 16, bottom: 16, leading: 16, trailing: 16)
}

struct DataSourceConfig: Codable {
    var provider: String?
    var refreshInterval: Int?
    var location: String?
    var symbols: [String]?
}

struct WidgetMetadata: Codable {
    var createdAt: Date
    var updatedAt: Date
    var originalPrompt: String
    var position: WidgetPosition?
    var isLocked: Bool
    var isVisible: Bool
    var space: String
}

struct WidgetFileEnvelope: Codable {
    var config: WidgetConfig
    var metadata: WidgetMetadata
}
