import Foundation

enum ComponentType: String, Codable {
    case text
    case icon
    case divider
    case spacer
    case progressRing = "progress_ring"
    case progressBar = "progress_bar"
    case chart
    case clock
    case analogClock = "analog_clock"
    case date
    case countdown
    case timer
    case stopwatch
    case worldClocks = "world_clocks"
    case pomodoro
    case dayProgress = "day_progress"
    case yearProgress = "year_progress"
    case weather
    case stock
    case crypto
    case calendarNext = "calendar_next"
    case reminders
    case battery
    case systemStats = "system_stats"
    case musicNowPlaying = "music_now_playing"
    case newsHeadlines = "news_headlines"
    case screenTime = "screen_time"
    case checklist
    case habitTracker = "habit_tracker"
    case quote
    case note
    case shortcutLauncher = "shortcut_launcher"
    case linkBookmarks = "link_bookmarks"
    case fileClipboard = "file_clipboard"
    case githubRepoStats = "github_repo_stats"
    case periodTracker = "period_tracker"
    case moodTracker = "mood_tracker"
    case breathingExercise = "breathing_exercise"
    case virtualPet = "virtual_pet"
    case vstack
    case hstack
    case container
}

enum FontWeightName: String, Codable {
    case ultralight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
}

final class ComponentConfig: Codable {
    var type: ComponentType
    var id: String?

    var content: String?
    var title: String?
    var name: String?
    var font: String?
    var size: Double?
    var weight: FontWeightName?
    var color: String?
    var alignment: String?
    var maxLines: Int?
    var opacity: Double?

    var timezone: String?
    var format: String?
    var showSeconds: Bool?
    var showSecondHand: Bool?
    var showControls: Bool?
    var showLaps: Bool?
    var showSessionCount: Bool?
    var showAlbumArt: Bool?
    var showArtist: Bool?
    var showTitle: Bool?
    var showProgress: Bool?
    var showTime: Bool?
    var showSource: Bool?
    var showIcon: Bool?
    var showTemperature: Bool?
    var showCondition: Bool?
    var showHighLow: Bool?
    var showHumidity: Bool?
    var showWind: Bool?
    var showFeelsLike: Bool?
    var showStreak: Bool?
    var showFavicon: Bool?
    var showQuotationMarks: Bool?
    var showChange: Bool?
    var showPrice: Bool?
    var showChangePercent: Bool?
    var showChart: Bool?
    var showDueDate: Bool?
    var showCheckbox: Bool?
    var showCalendarColor: Bool?
    var showPercentage: Bool?
    var showTimeRemaining: Bool?
    var showDate: Bool?
    var label: String?
    var source: String?
    var targetDate: String?
    var showComponents: [String]?
    var style: String?
    var category: String?
    var refreshInterval: String?
    var editable: Bool?
    var resetsDaily: Bool?
    var strikethrough: Bool?
    var completedText: String?
    var clocks: [WorldClockConfig]?
    var items: [ChecklistItemConfig]?
    var habits: [HabitConfig]?
    var shortcuts: [ShortcutConfig]?
    var links: [LinkBookmarkConfig]?
    var customQuotes: [String]?
    var checkedColor: String?
    var uncheckedColor: String?
    var authorColor: String?
    var iconSize: Double?
    var chartType: String?
    var chartPeriod: String?
    var duration: Int?
    var autoStart: Bool?
    var workDuration: Int?
    var breakDuration: Int?
    var longBreakDuration: Int?
    var sessionsBeforeLongBreak: Int?
    var workColor: String?
    var breakColor: String?
    var trackColor: String?
    var fillColor: String?
    var positiveColor: String?
    var negativeColor: String?
    var lowColor: String?
    var labelColor: String?
    var controlColor: String?
    var startHour: Int?
    var endHour: Int?
    var location: String?
    var symbol: String?
    var currency: String?
    var temperatureUnit: String?
    var sourceSystem: String?
    var feedUrl: String?
    var feedUrls: [String]?
    var list: String?
    var emptyText: String?
    var timeRange: String?
    var device: String?
    var interactive: Bool?
    var maxEvents: Int?
    var maxItems: Int?
    var maxApps: Int?
    var goalHours: Int?
    var showDailyGoal: Bool?
    var showCategories: Bool?
    var overColor: String?
    var barColor: String?
    var forecastDays: Int?
    var rotateInterval: Int?
    var albumArtSize: Double?
    var lineWidth: Double?
    var height: Double?
    var lowThreshold: Double?
    var showMetrics: [String]?
    var maxFiles: Int?
    var cycleLength: Int?
    var breatheInDuration: Double?
    var breatheOutDuration: Double?
    var holdDuration: Double?
    var sessionDuration: Int?
    var moods: [String]?

    var direction: String?
    var thickness: Double?
    var spacing: Double?

    var padding: EdgeInsetsConfig?
    var background: String?
    var cornerRadius: Double?
    var border: BorderConfig?
    var shadow: ShadowConfig?

    var child: ComponentConfig?
    var children: [ComponentConfig]?

    /// Returns true if this component (or any descendant) requires direct click interaction.
    var hasInteractiveContent: Bool {
        let interactiveTypes: Set<ComponentType> = [
            .shortcutLauncher, .linkBookmarks, .checklist,
            .pomodoro, .note, .stopwatch, .timer,
            .musicNowPlaying, .habitTracker, .reminders,
            .fileClipboard, .periodTracker, .moodTracker,
            .breathingExercise, .virtualPet
        ]
        if interactiveTypes.contains(type) { return true }
        if child?.hasInteractiveContent == true { return true }
        if children?.contains(where: { $0.hasInteractiveContent }) == true { return true }
        return false
    }

    init(
        type: ComponentType,
        content: String? = nil,
        name: String? = nil,
        font: String? = nil,
        size: Double? = nil,
        weight: FontWeightName? = nil,
        color: String? = nil,
        alignment: String? = nil,
        maxLines: Int? = nil,
        opacity: Double? = nil,
        timezone: String? = nil,
        format: String? = nil,
        showSeconds: Bool? = nil,
        showSecondHand: Bool? = nil,
        showControls: Bool? = nil,
        showLaps: Bool? = nil,
        showSessionCount: Bool? = nil,
        showAlbumArt: Bool? = nil,
        showArtist: Bool? = nil,
        showTitle: Bool? = nil,
        showProgress: Bool? = nil,
        showTime: Bool? = nil,
        showSource: Bool? = nil,
        showIcon: Bool? = nil,
        showTemperature: Bool? = nil,
        showCondition: Bool? = nil,
        showHighLow: Bool? = nil,
        showHumidity: Bool? = nil,
        showWind: Bool? = nil,
        showFeelsLike: Bool? = nil,
        showChange: Bool? = nil,
        showPrice: Bool? = nil,
        showChangePercent: Bool? = nil,
        showChart: Bool? = nil,
        showDueDate: Bool? = nil,
        showCheckbox: Bool? = nil,
        showCalendarColor: Bool? = nil,
        showPercentage: Bool? = nil,
        showTimeRemaining: Bool? = nil,
        label: String? = nil,
        source: String? = nil,
        targetDate: String? = nil,
        showComponents: [String]? = nil,
        style: String? = nil,
        refreshInterval: String? = nil,
        completedText: String? = nil,
        clocks: [WorldClockConfig]? = nil,
        chartType: String? = nil,
        chartPeriod: String? = nil,
        duration: Int? = nil,
        autoStart: Bool? = nil,
        workDuration: Int? = nil,
        breakDuration: Int? = nil,
        longBreakDuration: Int? = nil,
        sessionsBeforeLongBreak: Int? = nil,
        workColor: String? = nil,
        breakColor: String? = nil,
        trackColor: String? = nil,
        fillColor: String? = nil,
        positiveColor: String? = nil,
        negativeColor: String? = nil,
        lowColor: String? = nil,
        startHour: Int? = nil,
        endHour: Int? = nil,
        location: String? = nil,
        symbol: String? = nil,
        currency: String? = nil,
        temperatureUnit: String? = nil,
        sourceSystem: String? = nil,
        feedUrl: String? = nil,
        feedUrls: [String]? = nil,
        list: String? = nil,
        emptyText: String? = nil,
        timeRange: String? = nil,
        device: String? = nil,
        interactive: Bool? = nil,
        maxEvents: Int? = nil,
        maxItems: Int? = nil,
        maxApps: Int? = nil,
        forecastDays: Int? = nil,
        rotateInterval: Int? = nil,
        albumArtSize: Double? = nil,
        lineWidth: Double? = nil,
        height: Double? = nil,
        lowThreshold: Double? = nil,
        showMetrics: [String]? = nil,
        direction: String? = nil,
        thickness: Double? = nil,
        spacing: Double? = nil,
        padding: EdgeInsetsConfig? = nil,
        background: String? = nil,
        cornerRadius: Double? = nil,
        border: BorderConfig? = nil,
        shadow: ShadowConfig? = nil,
        child: ComponentConfig? = nil,
        children: [ComponentConfig]? = nil
    ) {
        self.type = type
        self.content = content
        self.name = name
        self.font = font
        self.size = size
        self.weight = weight
        self.color = color
        self.alignment = alignment
        self.maxLines = maxLines
        self.opacity = opacity
        self.timezone = timezone
        self.format = format
        self.showSeconds = showSeconds
        self.showSecondHand = showSecondHand
        self.showControls = showControls
        self.showLaps = showLaps
        self.showSessionCount = showSessionCount
        self.showAlbumArt = showAlbumArt
        self.showArtist = showArtist
        self.showTitle = showTitle
        self.showProgress = showProgress
        self.showTime = showTime
        self.showSource = showSource
        self.showIcon = showIcon
        self.showTemperature = showTemperature
        self.showCondition = showCondition
        self.showHighLow = showHighLow
        self.showHumidity = showHumidity
        self.showWind = showWind
        self.showFeelsLike = showFeelsLike
        self.showChange = showChange
        self.showPrice = showPrice
        self.showChangePercent = showChangePercent
        self.showChart = showChart
        self.showDueDate = showDueDate
        self.showCheckbox = showCheckbox
        self.showCalendarColor = showCalendarColor
        self.showPercentage = showPercentage
        self.showTimeRemaining = showTimeRemaining
        self.label = label
        self.source = source
        self.targetDate = targetDate
        self.showComponents = showComponents
        self.style = style
        self.refreshInterval = refreshInterval
        self.completedText = completedText
        self.clocks = clocks
        self.chartType = chartType
        self.chartPeriod = chartPeriod
        self.duration = duration
        self.autoStart = autoStart
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.longBreakDuration = longBreakDuration
        self.sessionsBeforeLongBreak = sessionsBeforeLongBreak
        self.workColor = workColor
        self.breakColor = breakColor
        self.trackColor = trackColor
        self.fillColor = fillColor
        self.positiveColor = positiveColor
        self.negativeColor = negativeColor
        self.lowColor = lowColor
        self.startHour = startHour
        self.endHour = endHour
        self.location = location
        self.symbol = symbol
        self.currency = currency
        self.temperatureUnit = temperatureUnit
        self.sourceSystem = sourceSystem
        self.feedUrl = feedUrl
        self.feedUrls = feedUrls
        self.list = list
        self.emptyText = emptyText
        self.timeRange = timeRange
        self.device = device
        self.interactive = interactive
        self.maxEvents = maxEvents
        self.maxItems = maxItems
        self.maxApps = maxApps
        self.forecastDays = forecastDays
        self.rotateInterval = rotateInterval
        self.albumArtSize = albumArtSize
        self.lineWidth = lineWidth
        self.height = height
        self.lowThreshold = lowThreshold
        self.showMetrics = showMetrics
        self.direction = direction
        self.thickness = thickness
        self.spacing = spacing
        self.padding = padding
        self.background = background
        self.cornerRadius = cornerRadius
        self.border = border
        self.shadow = shadow
        self.child = child
        self.children = children
    }
}

struct BorderConfig: Codable {
    var color: String
    var width: Double
}

struct ShadowConfig: Codable {
    var color: String
    var opacity: Double
    var radius: Double
    var x: Double
    var y: Double
}

struct WorldClockConfig: Codable {
    var timezone: String
    var label: String?
}

struct ChecklistItemConfig: Codable {
    var id: String
    var text: String
    var checked: Bool
}

struct HabitConfig: Codable {
    var id: String
    var name: String
    var icon: String?
    var target: Int
    var unit: String?
}

struct ShortcutConfig: Codable {
    var name: String
    var icon: String?
    var action: String
}

struct LinkBookmarkConfig: Codable {
    var name: String
    var url: String
    var icon: String?
}
