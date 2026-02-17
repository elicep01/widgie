import AppKit
import SwiftUI

struct WidgetRenderer: View {
    let config: WidgetConfig
    private var surfaceStyle: ThemeSurfaceStyle { ThemeResolver.surface(for: config.theme) }

    var body: some View {
        ZStack {
            renderWidgetBackground(config.background)

            renderComponent(config.content)
                .padding(config.padding.edgeInsets)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius.cgFloat, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: config.cornerRadius.cgFloat, style: .continuous)
                .stroke(
                    surfaceStyle.innerBorderColor.opacity(surfaceStyle.innerBorderOpacity),
                    lineWidth: surfaceStyle.innerBorderWidth.cgFloat
                )
        )
        .shadow(
            color: surfaceStyle.shadowColor.opacity(surfaceStyle.shadowOpacity),
            radius: surfaceStyle.shadowRadius.cgFloat,
            x: surfaceStyle.shadowX.cgFloat,
            y: surfaceStyle.shadowY.cgFloat
        )
    }

    private func renderComponent(_ component: ComponentConfig) -> AnyView {
        switch component.type {
        case .text:
            return AnyView(
                Text(component.content ?? "")
                    .font(font(for: component))
                    .foregroundStyle(ThemeResolver.color(for: component.color, theme: config.theme))
                    .multilineTextAlignment(textAlignment(for: component.alignment))
                    .lineLimit(component.maxLines)
                    .opacity(component.opacity ?? 1)
                    .frame(maxWidth: .infinity, alignment: frameAlignment(for: component.alignment))
            )

        case .icon:
            return AnyView(
                Image(systemName: component.name ?? "questionmark.circle")
                    .font(.system(size: (component.size ?? 20).cgFloat))
                    .foregroundStyle(ThemeResolver.color(for: component.color, theme: config.theme))
                    .frame(maxWidth: .infinity, alignment: frameAlignment(for: component.alignment))
            )

        case .divider:
            if (component.direction ?? "horizontal").lowercased() == "vertical" {
                return AnyView(
                    Rectangle()
                        .fill(ThemeResolver.color(for: component.color ?? "muted", theme: config.theme))
                        .frame(width: (component.thickness ?? 0.5).cgFloat)
                        .frame(maxHeight: .infinity)
                )
            }

            return AnyView(
                Rectangle()
                    .fill(ThemeResolver.color(for: component.color ?? "muted", theme: config.theme))
                    .frame(height: (component.thickness ?? 0.5).cgFloat)
                    .frame(maxWidth: .infinity)
            )

        case .spacer:
            if let size = component.size {
                return AnyView(Color.clear.frame(height: size.cgFloat))
            }
            return AnyView(Spacer(minLength: 0))

        case .progressRing:
            return AnyView(ProgressRingComponentView(widgetID: config.id, component: component, theme: config.theme))

        case .progressBar:
            return AnyView(ProgressBarComponentView(widgetID: config.id, component: component, theme: config.theme))

        case .clock:
            return AnyView(ClockComponentView(component: component, theme: config.theme))

        case .analogClock:
            return AnyView(AnalogClockComponentView(component: component, theme: config.theme))

        case .date:
            return AnyView(DateComponentView(component: component, theme: config.theme))

        case .countdown:
            return AnyView(CountdownComponentView(component: component, theme: config.theme))

        case .timer:
            return AnyView(TimerComponentView(component: component, theme: config.theme))

        case .stopwatch:
            return AnyView(StopwatchComponentView(component: component, theme: config.theme))

        case .worldClocks:
            return AnyView(WorldClocksComponentView(component: component, theme: config.theme))

        case .pomodoro:
            return AnyView(PomodoroComponentView(component: component, theme: config.theme))

        case .dayProgress:
            return AnyView(DayProgressComponentView(component: component, theme: config.theme))

        case .yearProgress:
            return AnyView(YearProgressComponentView(component: component, theme: config.theme))

        case .chart:
            return AnyView(ChartComponentView(component: component, theme: config.theme))

        case .weather:
            return AnyView(WeatherComponentView(component: component, theme: config.theme))

        case .stock:
            return AnyView(StockComponentView(component: component, theme: config.theme))

        case .crypto:
            return AnyView(CryptoComponentView(component: component, theme: config.theme))

        case .calendarNext:
            return AnyView(CalendarNextComponentView(component: component, theme: config.theme))

        case .reminders:
            return AnyView(RemindersComponentView(component: component, theme: config.theme))

        case .battery:
            return AnyView(BatteryComponentView(component: component, theme: config.theme))

        case .systemStats:
            return AnyView(SystemStatsComponentView(component: component, theme: config.theme))

        case .musicNowPlaying:
            return AnyView(MusicNowPlayingComponentView(component: component, theme: config.theme))

        case .newsHeadlines:
            return AnyView(NewsHeadlinesComponentView(component: component, theme: config.theme))

        case .screenTime:
            return AnyView(ScreenTimeComponentView(component: component, theme: config.theme))

        case .checklist:
            return AnyView(ChecklistComponentView(widgetID: config.id, component: component, theme: config.theme))

        case .habitTracker:
            return AnyView(HabitTrackerComponentView(widgetID: config.id, component: component, theme: config.theme))

        case .quote:
            return AnyView(QuoteComponentView(component: component, theme: config.theme))

        case .note:
            return AnyView(NoteComponentView(widgetID: config.id, component: component, theme: config.theme))

        case .shortcutLauncher:
            return AnyView(ShortcutLauncherComponentView(component: component, theme: config.theme))

        case .linkBookmarks:
            return AnyView(LinkBookmarksComponentView(component: component, theme: config.theme))

        case .vstack:
            let children = component.children ?? []
            return AnyView(
                VStack(alignment: horizontalAlignment(for: component.alignment), spacing: (component.spacing ?? 8).cgFloat) {
                    ForEach(children.indices, id: \.self) { index in
                        renderComponent(children[index])
                    }
                }
            )

        case .hstack:
            let children = component.children ?? []
            return AnyView(
                HStack(alignment: verticalAlignment(for: component.alignment), spacing: (component.spacing ?? 12).cgFloat) {
                    ForEach(children.indices, id: \.self) { index in
                        renderComponent(children[index])
                    }
                }
            )

        case .container:
            guard let child = component.child ?? component.children?.first else {
                return AnyView(EmptyView())
            }

            return AnyView(
                renderComponent(child)
                    .padding((component.padding ?? .medium).edgeInsets)
                    .background(containerBackground(from: component.background))
                    .clipShape(RoundedRectangle(cornerRadius: (component.cornerRadius ?? 12).cgFloat, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: (component.cornerRadius ?? 12).cgFloat, style: .continuous)
                            .stroke(
                                ThemeResolver.color(for: component.border?.color ?? "muted", theme: config.theme)
                                    .opacity(component.border == nil ? 0 : 0.6),
                                lineWidth: (component.border?.width ?? 0).cgFloat
                            )
                    )
                    .shadow(
                        color: ThemeResolver.color(for: component.shadow?.color, theme: config.theme)
                            .opacity(component.shadow?.opacity ?? 0),
                        radius: (component.shadow?.radius ?? 0).cgFloat,
                        x: (component.shadow?.x ?? 0).cgFloat,
                        y: (component.shadow?.y ?? 0).cgFloat
                    )
            )
        }
    }

    private func renderWidgetBackground(_ background: BackgroundConfig) -> AnyView {
        switch background.type.lowercased() {
        case "blur":
            return AnyView(
                ZStack {
                    VisualEffectMaterialView(
                        material: material(for: background.material),
                        blendingMode: .behindWindow
                    )

                    if let tintColor = background.tintColor {
                        Color(hex: tintColor)
                            .opacity(background.tintOpacity ?? 0.7)
                    }
                }
            )
        case "gradient":
            if let colors = background.colors, colors.count >= 2 {
                return AnyView(
                    LinearGradient(
                        colors: colors.map { Color(hex: $0) },
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            return AnyView(Color.clear)
        case "solid":
            if let color = background.color {
                if color.hasPrefix("#") {
                    return AnyView(Color(hex: color))
                }
                return AnyView(ThemeResolver.color(for: color, theme: config.theme))
            }
            return AnyView(Color.clear)
        default:
            return AnyView(Color.clear)
        }
    }

    private func containerBackground(from background: String?) -> AnyView {
        guard let background else {
            return AnyView(Color.clear)
        }

        if background.hasPrefix("blur:") {
            let materialName = background.replacingOccurrences(of: "blur:", with: "")
            return AnyView(
                VisualEffectMaterialView(material: material(for: materialName), blendingMode: .behindWindow)
            )
        }

        if background.hasPrefix("#") {
            return AnyView(Color(hex: background))
        }

        return AnyView(ThemeResolver.color(for: background, theme: config.theme))
    }

    private func material(for materialName: String?) -> NSVisualEffectView.Material {
        guard let materialName = materialName?.lowercased() else {
            return .hudWindow
        }

        switch materialName {
        case "popover":
            return .popover
        case "sidebar":
            return .sidebar
        case "header":
            return .headerView
        default:
            return .hudWindow
        }
    }

    private func font(for component: ComponentConfig) -> Font {
        let weight = fontWeight(for: component.weight)
        let size = (component.size ?? 14).cgFloat

        switch (component.font ?? "sf-pro").lowercased() {
        case "sf-mono":
            return .system(size: size, weight: weight, design: .monospaced)
        case "new-york":
            return .system(size: size, weight: weight, design: .serif)
        case "sf-rounded":
            return .system(size: size, weight: weight, design: .rounded)
        default:
            return .system(size: size, weight: weight, design: .default)
        }
    }

    private func fontWeight(for weight: FontWeightName?) -> Font.Weight {
        switch weight ?? .regular {
        case .ultralight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        }
    }

    private func textAlignment(for alignment: String?) -> TextAlignment {
        switch alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func frameAlignment(for alignment: String?) -> Alignment {
        switch alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func horizontalAlignment(for alignment: String?) -> HorizontalAlignment {
        switch alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func verticalAlignment(for alignment: String?) -> VerticalAlignment {
        switch alignment?.lowercased() {
        case "top":
            return .top
        case "bottom":
            return .bottom
        default:
            return .center
        }
    }
}

private struct ClockComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(clockFormatter.string(from: time.now))
                .font(.system(size: (component.size ?? 42).cgFloat, weight: .light, design: .monospaced))
                .foregroundStyle(ThemeResolver.color(for: component.color, theme: theme))

            if let label = component.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private var clockFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = component.format ?? "HH:mm"
        formatter.timeZone = resolvedTimezone(component.timezone)
        return formatter
    }
}

private struct AnalogClockComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared

    var body: some View {
        let size = (component.size ?? 120).cgFloat
        let current = time.now
        var calendar = Calendar.current
        calendar.timeZone = resolvedTimezone(component.timezone)
        let hour = calendar.component(.hour, from: current)
        let minute = calendar.component(.minute, from: current)
        let second = calendar.component(.second, from: current)

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(ThemeResolver.color(for: "muted", theme: theme).opacity(0.6), lineWidth: 1.2)

                ForEach(0..<60, id: \.self) { index in
                    Capsule()
                        .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(index.isMultiple(of: 5) ? 0.75 : 0.35))
                        .frame(width: index.isMultiple(of: 5) ? 1.8 : 1, height: index.isMultiple(of: 5) ? 8 : 4)
                        .offset(y: -size * 0.46)
                        .rotationEffect(.degrees(Double(index) * 6))
                }

                hand(length: size * 0.23, width: 3, color: ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                    .rotationEffect(.degrees((Double(hour % 12) + (Double(minute) / 60)) * 30))

                hand(length: size * 0.34, width: 2.4, color: ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                    .rotationEffect(.degrees((Double(minute) + (Double(second) / 60)) * 6))

                if component.showSecondHand ?? true {
                    hand(length: size * 0.38, width: 1.2, color: ThemeResolver.color(for: "accent", theme: theme))
                        .rotationEffect(.degrees(Double(second) * 6))
                }

                Circle()
                    .fill(ThemeResolver.color(for: "accent", theme: theme))
                    .frame(width: 5, height: 5)
            }
            .frame(width: size, height: size)

            if let label = component.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func hand(length: CGFloat, width: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
    }
}

private struct DateComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared

    var body: some View {
        Text(formatter.string(from: time.now))
            .font(.system(size: (component.size ?? 13).cgFloat, weight: .medium))
            .foregroundStyle(ThemeResolver.color(for: component.color ?? "secondary", theme: theme))
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = component.format ?? "EEEE, MMM d"
        formatter.timeZone = resolvedTimezone(component.timezone)
        return formatter
    }
}

private struct CountdownComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 4) {
            if let label = component.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            }

            Text(remainingText(now: time.now))
                .font(.system(size: (component.size ?? 18).cgFloat, weight: .semibold, design: .monospaced))
                .foregroundStyle(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        case "leading":
            return .leading
        default:
            // Compact countdown widgets read better centered by default.
            return .center
        }
    }

    private var stackAlignment: HorizontalAlignment {
        switch alignment {
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }

    private func remainingText(now: Date) -> String {
        guard let targetString = component.targetDate,
              let target = ISO8601DateFormatter().date(from: targetString) else {
            return "--"
        }

        if target <= now {
            return component.completedText ?? "Time's up!"
        }

        let values = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: target)
        let units = component.showComponents ?? ["days", "hours", "minutes"]

        var parts: [String] = []
        if units.contains("days"), let day = values.day { parts.append("\(day)d") }
        if units.contains("hours"), let hour = values.hour { parts.append("\(hour)h") }
        if units.contains("minutes"), let minute = values.minute { parts.append("\(minute)m") }
        if units.contains("seconds"), let second = values.second { parts.append("\(second)s") }

        return parts.joined(separator: " ")
    }
}

private struct TimerComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared
    @State private var remaining: Int
    @State private var isRunning: Bool
    @State private var lastTick: Date?

    init(component: ComponentConfig, theme: WidgetTheme) {
        self.component = component
        self.theme = theme
        let duration = max(1, component.duration ?? 1500)
        _remaining = State(initialValue: duration)
        _isRunning = State(initialValue: component.autoStart ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = component.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            }

            timerDisplay

            if component.showControls ?? true {
                HStack(spacing: 8) {
                    Button(isRunning ? "Pause" : "Start") {
                        isRunning.toggle()
                        lastTick = time.now
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Reset") {
                        isRunning = false
                        remaining = totalDuration
                        lastTick = time.now
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .onAppear {
            lastTick = time.now
            if component.autoStart ?? false {
                isRunning = true
            }
        }
        .onChange(of: time.now) { _, newValue in
            tick(now: newValue)
        }
    }

    private var timerDisplay: some View {
        Group {
            switch resolvedStyle {
            case "ring":
                let ringDiameter = max(86, min(144, (component.size ?? 24).cgFloat * 3.25))
                let clockFont = max(16, min(40, ringDiameter * 0.26))
                ZStack {
                    Circle()
                        .stroke(ThemeResolver.color(for: "muted", theme: theme).opacity(0.35), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress.cgFloat)
                        .stroke(
                            ThemeResolver.color(for: component.color ?? "accent", theme: theme),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text(formatClock(remaining))
                        .font(.system(size: clockFont, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                }
                .frame(width: ringDiameter, height: ringDiameter)
            case "bar":
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatClock(remaining))
                        .font(.system(size: (component.size ?? 20).cgFloat, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.3))
                            Capsule()
                                .fill(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
                                .frame(width: geometry.size.width * progress.cgFloat)
                        }
                    }
                    .frame(height: 8)
                }
            default:
                Text(formatClock(remaining))
                    .font(.system(size: (component.size ?? 28).cgFloat, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
            }
        }
    }

    private var totalDuration: Int {
        max(1, component.duration ?? 1500)
    }

    private var progress: Double {
        let elapsed = max(0, totalDuration - remaining)
        return Double(elapsed) / Double(totalDuration)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        case "leading":
            return .leading
        default:
            // Timer widgets read better centered by default.
            return .center
        }
    }

    private var resolvedStyle: String {
        (component.style ?? "digital").lowercased()
    }

    private func tick(now: Date) {
        guard isRunning else {
            lastTick = now
            return
        }

        guard let lastTick else {
            self.lastTick = now
            return
        }

        let elapsed = Int(now.timeIntervalSince(lastTick))
        guard elapsed > 0 else { return }

        self.lastTick = now
        remaining = max(0, remaining - elapsed)

        if remaining == 0 {
            isRunning = false
        }
    }
}

private struct StopwatchComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared
    @State private var elapsed: Int = 0
    @State private var isRunning: Bool = false
    @State private var lastTick: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = component.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            }

            Text(formatClock(elapsed))
                .font(.system(size: (component.size ?? 32).cgFloat, weight: .semibold, design: .monospaced))
                .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))

            if component.showControls ?? true {
                HStack(spacing: 8) {
                    Button(isRunning ? "Pause" : "Start") {
                        isRunning.toggle()
                        lastTick = time.now
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Reset") {
                        isRunning = false
                        elapsed = 0
                        lastTick = time.now
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .onAppear {
            lastTick = time.now
        }
        .onChange(of: time.now) { _, newValue in
            tick(now: newValue)
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func tick(now: Date) {
        guard isRunning else {
            lastTick = now
            return
        }

        guard let lastTick else {
            self.lastTick = now
            return
        }

        let delta = Int(now.timeIntervalSince(lastTick))
        guard delta > 0 else { return }

        self.lastTick = now
        elapsed += delta
    }
}

private struct WorldClocksComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entries.indices, id: \.self) { index in
                let entry = entries[index]
                HStack(spacing: 10) {
                    Text(entry.label ?? shortTimezoneName(entry.timezone))
                        .font(.system(size: (component.size ?? 14).cgFloat, weight: .medium))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                    Spacer(minLength: 8)
                    Text(timeString(for: entry.timezone))
                        .font(.system(size: (component.size ?? 14).cgFloat, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var entries: [WorldClockConfig] {
        if let clocks = component.clocks, !clocks.isEmpty {
            return clocks
        }

        return [
            WorldClockConfig(timezone: "local", label: "Local")
        ]
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func timeString(for timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = component.format ?? "HH:mm"
        formatter.timeZone = resolvedTimezone(timezone)
        return formatter.string(from: time.now)
    }

    private func shortTimezoneName(_ timezone: String) -> String {
        if timezone.lowercased() == "local" {
            return "Local"
        }
        return timezone.split(separator: "/").last.map(String.init) ?? timezone
    }
}

private struct PomodoroComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared
    @State private var phase: PomodoroPhase = .work
    @State private var remaining: Int
    @State private var isRunning: Bool
    @State private var completedSessions: Int = 0
    @State private var lastTick: Date?

    init(component: ComponentConfig, theme: WidgetTheme) {
        self.component = component
        self.theme = theme
        _remaining = State(initialValue: max(1, component.workDuration ?? 1500))
        _isRunning = State(initialValue: component.autoStart ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phase.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(phaseColor)
                Spacer(minLength: 8)
                if component.showSessionCount ?? true {
                    Text("S\(completedSessions)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                }
            }

            pomodoroDisplay

            if component.showControls ?? true {
                HStack(spacing: 8) {
                    Button(isRunning ? "Pause" : "Start") {
                        isRunning.toggle()
                        lastTick = time.now
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Reset") {
                        resetToWork()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .onAppear {
            lastTick = time.now
        }
        .onChange(of: time.now) { _, newValue in
            tick(now: newValue)
        }
    }

    private var pomodoroDisplay: some View {
        Group {
            switch (component.style ?? "ring").lowercased() {
            case "bar":
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatClock(remaining))
                        .font(.system(size: (component.size ?? 22).cgFloat, weight: .semibold, design: .monospaced))
                        .foregroundStyle(phaseColor)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.3))
                            Capsule()
                                .fill(phaseColor)
                                .frame(width: geometry.size.width * phaseProgress.cgFloat)
                        }
                    }
                    .frame(height: 8)
                }
            case "digital":
                Text(formatClock(remaining))
                    .font(.system(size: (component.size ?? 24).cgFloat, weight: .semibold, design: .monospaced))
                    .foregroundStyle(phaseColor)
            default:
                ZStack {
                    Circle()
                        .stroke(ThemeResolver.color(for: "muted", theme: theme).opacity(0.35), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: phaseProgress.cgFloat)
                        .stroke(phaseColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(formatClock(remaining))
                        .font(.system(size: (component.size ?? 16).cgFloat, weight: .semibold, design: .monospaced))
                        .foregroundStyle(phaseColor)
                }
                .frame(width: 92, height: 92)
            }
        }
    }

    private var workDuration: Int {
        max(1, component.workDuration ?? 1500)
    }

    private var shortBreakDuration: Int {
        max(1, component.breakDuration ?? 300)
    }

    private var longBreakDuration: Int {
        max(1, component.longBreakDuration ?? 900)
    }

    private var sessionsBeforeLongBreak: Int {
        max(1, component.sessionsBeforeLongBreak ?? 4)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .work:
            return ThemeResolver.color(for: component.workColor ?? component.color ?? "negative", theme: theme)
        case .shortBreak, .longBreak:
            return ThemeResolver.color(for: component.breakColor ?? "positive", theme: theme)
        }
    }

    private var phaseDuration: Int {
        switch phase {
        case .work:
            return workDuration
        case .shortBreak:
            return shortBreakDuration
        case .longBreak:
            return longBreakDuration
        }
    }

    private var phaseProgress: Double {
        let elapsed = max(0, phaseDuration - remaining)
        return Double(elapsed) / Double(max(1, phaseDuration))
    }

    private func resetToWork() {
        phase = .work
        remaining = workDuration
        isRunning = false
        lastTick = time.now
    }

    private func tick(now: Date) {
        guard isRunning else {
            lastTick = now
            return
        }

        guard let lastTick else {
            self.lastTick = now
            return
        }

        let delta = Int(now.timeIntervalSince(lastTick))
        guard delta > 0 else { return }
        self.lastTick = now

        remaining = max(0, remaining - delta)
        if remaining == 0 {
            advancePhase()
        }
    }

    private func advancePhase() {
        switch phase {
        case .work:
            completedSessions += 1
            if completedSessions.isMultiple(of: sessionsBeforeLongBreak) {
                phase = .longBreak
                remaining = longBreakDuration
            } else {
                phase = .shortBreak
                remaining = shortBreakDuration
            }
        case .shortBreak, .longBreak:
            phase = .work
            remaining = workDuration
        }
    }
}

private enum PomodoroPhase {
    case work
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .work:
            return "Work"
        case .shortBreak:
            return "Break"
        case .longBreak:
            return "Long Break"
        }
    }
}

private struct DayProgressComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = component.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            }

            Group {
                switch (component.style ?? "bar").lowercased() {
                case "ring":
                    ZStack {
                        Circle()
                            .stroke(ThemeResolver.color(for: "muted", theme: theme).opacity(0.35), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: progress.cgFloat)
                            .stroke(
                                ThemeResolver.color(for: component.color ?? "accent", theme: theme),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 72, height: 72)
                case "text":
                    EmptyView()
                default:
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.3))
                            Capsule()
                                .fill(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
                                .frame(width: geometry.size.width * progress.cgFloat)
                        }
                    }
                    .frame(height: 8)
                }
            }

            if component.showPercentage ?? true {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
            }

            if component.showTimeRemaining ?? true {
                Text(timeRemainingText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var startHour: Int {
        min(max(component.startHour ?? 8, 0), 23)
    }

    private var endHour: Int {
        min(max(component.endHour ?? 23, 1), 24)
    }

    private var dayRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = time.now
        let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now) ?? now
        let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: now) ?? now
        if end <= start {
            return (start, start.addingTimeInterval(1))
        }
        return (start, end)
    }

    private var progress: Double {
        let now = time.now
        let range = dayRange
        if now <= range.start {
            return 0
        }
        if now >= range.end {
            return 1
        }

        let total = range.end.timeIntervalSince(range.start)
        let elapsed = now.timeIntervalSince(range.start)
        return (elapsed / total).clamped(0, 1)
    }

    private var timeRemainingText: String {
        let now = time.now
        let range = dayRange
        if now < range.start {
            let wait = Int(range.start.timeIntervalSince(now))
            return "Starts in \(formatHoursMinutes(wait))"
        }
        if now >= range.end {
            return "Done for today"
        }
        let remaining = Int(range.end.timeIntervalSince(now))
        return "\(formatHoursMinutes(remaining)) left"
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct YearProgressComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @ObservedObject private var time = TimePublisher.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(component.label ?? String(Calendar.current.component(.year, from: time.now)))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))

            Group {
                switch (component.style ?? "bar").lowercased() {
                case "ring":
                    ZStack {
                        Circle()
                            .stroke(ThemeResolver.color(for: "muted", theme: theme).opacity(0.35), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: progress.cgFloat)
                            .stroke(
                                ThemeResolver.color(for: component.color ?? "accent", theme: theme),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 72, height: 72)
                case "text":
                    EmptyView()
                default:
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.3))
                            Capsule()
                                .fill(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
                                .frame(width: geometry.size.width * progress.cgFloat)
                        }
                    }
                    .frame(height: 8)
                }
            }

            if component.showPercentage ?? true {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private var progress: Double {
        let now = time.now
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now

        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }

        let elapsed = now.timeIntervalSince(start)
        return (elapsed / total).clamped(0, 1)
    }
}

private enum DataLoadState {
    case loading
    case ready
    case failed
}

private struct LoadingShimmerView: View {
    let theme: WidgetTheme
    let lines: Int
    let lineHeight: CGFloat

    @State private var shimmerOffset: CGFloat = -0.7

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<max(1, lines), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.28))
                    .frame(maxWidth: .infinity)
                    .frame(height: lineHeight)
            }
        }
        .overlay {
            GeometryReader { geo in
                let width = max(48, geo.size.width * 0.48)
                LinearGradient(
                    colors: [
                        Color.clear,
                        ThemeResolver.color(for: "primary", theme: theme).opacity(0.30),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: width)
                .offset(x: geo.size.width * shimmerOffset)
            }
            .mask(
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<max(1, lines), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .frame(maxWidth: .infinity)
                            .frame(height: lineHeight)
                    }
                }
            )
        }
        .onAppear {
            shimmerOffset = -0.7
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.3
            }
        }
    }
}

private struct DataErrorFallbackView: View {
    let message: String
    let theme: WidgetTheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
                .lineLimit(2)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
    }
}

private struct WeatherComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var snapshot: WeatherSnapshot?
    @State private var loadState: DataLoadState = .loading

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if loadState == .loading && snapshot == nil {
                LoadingShimmerView(theme: theme, lines: 4, lineHeight: 11)
            } else if loadState == .failed && snapshot == nil {
                DataErrorFallbackView(message: "Couldn't load weather", theme: theme)
            } else if let snapshot {
                HStack(spacing: 8) {
                    if component.showIcon ?? true {
                        Image(systemName: snapshot.conditionSymbol)
                            .font(.system(size: 18))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
                    }

                    if component.showTemperature ?? true {
                        Text(snapshot.temperature.map { "\($0.roundedInt)\(snapshot.unitSymbol)" } ?? "--")
                            .font(.system(size: (component.size ?? 30).cgFloat, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                    }

                    Spacer(minLength: 0)
                }

                if component.showCondition ?? true {
                    Text(snapshot.condition)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                }

                if component.showHighLow ?? true {
                    Text("H \(snapshot.high?.roundedInt ?? 0) • L \(snapshot.low?.roundedInt ?? 0)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: "muted", theme: theme))
                }

                if component.showHumidity == true, let humidity = snapshot.humidity {
                    Text("Humidity \(humidity.roundedInt)%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                }

                if component.showWind == true, let wind = snapshot.windSpeed {
                    Text("Wind \(wind.roundedInt) mph")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                }

                if component.showFeelsLike == true, let feelsLike = snapshot.feelsLike {
                    Text("Feels like \(feelsLike.roundedInt)\(snapshot.unitSymbol)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                }
            } else {
                Text("--")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: loadState == .failed ? 20 : 30 * 60) {
            await MainActor.run {
                if snapshot == nil {
                    loadState = .loading
                }
            }
            let location = component.location ?? "Madison, WI"
            let fahrenheit = prefersFahrenheit(unitToken: component.temperatureUnit)
            let value = await DataServiceManager.shared.weather(location: location, fahrenheit: fahrenheit)
            await MainActor.run {
                snapshot = value
                loadState = value == nil ? .failed : .ready
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func prefersFahrenheit(unitToken: String?) -> Bool {
        let normalized = (unitToken ?? "fahrenheit")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if ["celsius", "celcius", "centigrade", "c", "metric", "°c"].contains(normalized) {
            return false
        }

        if ["fahrenheit", "f", "imperial", "°f"].contains(normalized) {
            return true
        }

        // Unknown tokens default to fahrenheit for backward compatibility.
        return true
    }
}

private struct StockComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var snapshot: MarketSnapshot?
    @State private var loadState: DataLoadState = .loading

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if loadState == .loading && snapshot == nil {
                LoadingShimmerView(theme: theme, lines: 3, lineHeight: 10)
            } else if loadState == .failed && snapshot == nil {
                DataErrorFallbackView(message: "Couldn't load stock data", theme: theme)
            } else {
                HStack {
                    Text((component.symbol ?? snapshot?.symbol ?? "STOCK").uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                    Spacer(minLength: 8)
                    if component.showPrice ?? true {
                        Text(snapshot?.price.map(formatPrice) ?? "--")
                            .font(.system(size: (component.size ?? 18).cgFloat, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                    }
                }

                if component.showChange ?? true {
                    Text(changeText(snapshot))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(changeColor(snapshot))
                }

                if component.showChart ?? true {
                    SparklineChartView(
                        values: snapshot?.history ?? [],
                        color: changeColor(snapshot),
                        height: (component.height ?? 38).cgFloat
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 60) {
            await MainActor.run {
                if snapshot == nil {
                    loadState = .loading
                }
            }
            let symbol = component.symbol ?? "AAPL"
            let period = component.chartPeriod ?? "7d"
            let value = await DataServiceManager.shared.stock(symbol: symbol, period: period)
            await MainActor.run {
                snapshot = value
                loadState = value == nil ? .failed : .ready
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func changeText(_ value: MarketSnapshot?) -> String {
        guard let value, let change = value.change, let percent = value.changePercent else {
            return "--"
        }
        return String(format: "%+.2f (%+.2f%%)", change, percent)
    }

    private func changeColor(_ value: MarketSnapshot?) -> Color {
        guard let percent = value?.changePercent else {
            return ThemeResolver.color(for: "secondary", theme: theme)
        }
        return percent >= 0
            ? ThemeResolver.color(for: component.positiveColor ?? "positive", theme: theme)
            : ThemeResolver.color(for: component.negativeColor ?? "negative", theme: theme)
    }
}

private struct CryptoComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var snapshot: MarketSnapshot?
    @State private var loadState: DataLoadState = .loading

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if loadState == .loading && snapshot == nil {
                LoadingShimmerView(theme: theme, lines: 3, lineHeight: 10)
            } else if loadState == .failed && snapshot == nil {
                DataErrorFallbackView(message: "Couldn't load crypto data", theme: theme)
            } else {
                HStack {
                    Text((component.symbol ?? snapshot?.symbol ?? "BTC").uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                    Spacer(minLength: 8)
                    Text(snapshot?.price.map(formatPrice) ?? "--")
                        .font(.system(size: (component.size ?? 18).cgFloat, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                }

                if let percent = snapshot?.changePercent {
                    Text(String(format: "%+.2f%%", percent))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(percent >= 0 ? ThemeResolver.color(for: "positive", theme: theme) : ThemeResolver.color(for: "negative", theme: theme))
                } else {
                    Text("--")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                }

                if component.showChart ?? false {
                    SparklineChartView(
                        values: snapshot?.history ?? [],
                        color: ThemeResolver.color(for: component.color ?? "accent", theme: theme),
                        height: (component.height ?? 38).cgFloat
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 2 * 60) {
            await MainActor.run {
                if snapshot == nil {
                    loadState = .loading
                }
            }
            let symbol = component.symbol ?? "BTC"
            let currency = component.currency ?? "USD"
            let value = await DataServiceManager.shared.crypto(symbol: symbol, currency: currency)
            await MainActor.run {
                snapshot = value
                loadState = value == nil ? .failed : .ready
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct CalendarNextComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var events: [CalendarEventSnapshot] = []
    @State private var hasLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !hasLoaded {
                LoadingShimmerView(theme: theme, lines: 3, lineHeight: 10)
            } else if events.isEmpty {
                Text(component.emptyText ?? "No upcoming events")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            } else {
                ForEach(events.prefix(max(1, component.maxEvents ?? 3))) { event in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(ThemeResolver.color(for: "accent", theme: theme))
                            .frame(width: 6, height: 6)
                        Text(event.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if component.showTime ?? true {
                            Text(calendarTimeText(event.startDate, allDay: event.isAllDay))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 5 * 60) {
            let maxEvents = component.maxEvents ?? 3
            let range = component.timeRange ?? "today"
            let value = await DataServiceManager.shared.calendarNext(maxEvents: maxEvents, timeRange: range)
            await MainActor.run {
                events = value
                hasLoaded = true
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct RemindersComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var reminders: [ReminderSnapshot] = []
    @State private var hasLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !hasLoaded {
                LoadingShimmerView(theme: theme, lines: 3, lineHeight: 10)
            } else if reminders.isEmpty {
                Text("No reminders")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            } else {
                ForEach(reminders.prefix(max(1, component.maxItems ?? 5))) { reminder in
                    HStack(spacing: 8) {
                        if component.showCheckbox ?? true {
                            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(reminder.isCompleted ? ThemeResolver.color(for: "positive", theme: theme) : ThemeResolver.color(for: "muted", theme: theme))
                        }
                        Text(reminder.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                            .strikethrough(reminder.isCompleted)
                            .lineLimit(1)

                        Spacer(minLength: 8)
                        if component.showDueDate ?? true, let due = reminder.dueDate {
                            Text(reminderDueText(due))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 5 * 60) {
            let maxItems = component.maxItems ?? 5
            let value = await DataServiceManager.shared.reminders(maxItems: maxItems)
            await MainActor.run {
                reminders = value
                hasLoaded = true
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct BatteryComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var snapshot: BatterySnapshot?

    var body: some View {
        Group {
            switch (component.style ?? "ring").lowercased() {
            case "bar":
                VStack(alignment: .leading, spacing: 6) {
                    batteryText
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.3))
                            Capsule()
                                .fill(fillColor)
                                .frame(width: geo.size.width * percentage.cgFloat)
                        }
                    }
                    .frame(height: 8)
                }
            case "text":
                batteryText
            default:
                ZStack {
                    Circle()
                        .stroke(ThemeResolver.color(for: "muted", theme: theme).opacity(0.35), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: percentage.cgFloat)
                        .stroke(fillColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    batteryText
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .frame(width: 74, height: 74)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 60) {
            let value = await DataServiceManager.shared.battery()
            await MainActor.run {
                snapshot = value
            }
        }
    }

    private var percentage: Double {
        let p = (snapshot?.percentage ?? 0) / 100
        return max(0, min(1, p))
    }

    private var fillColor: Color {
        let threshold = component.lowThreshold ?? 20
        if (snapshot?.percentage ?? 100) <= threshold {
            return ThemeResolver.color(for: component.lowColor ?? "negative", theme: theme)
        }
        return ThemeResolver.color(for: component.color ?? "positive", theme: theme)
    }

    private var batteryText: some View {
        Text(snapshot?.percentage.map { "\($0.roundedInt)%" } ?? "--")
            .font(.system(size: (component.size ?? 14).cgFloat, weight: .semibold, design: .monospaced))
            .foregroundStyle(fillColor)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct SystemStatsComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var snapshot: SystemStatsSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statRow(title: "CPU", value: snapshot?.cpuPercent)
            statRow(title: "MEM", value: snapshot?.memoryPercent)
            statRow(title: "DISK", value: snapshot?.storagePercent)
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 30) {
            let value = await DataServiceManager.shared.systemStats()
            await MainActor.run {
                snapshot = value
            }
        }
    }

    @ViewBuilder
    private func statRow(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                Spacer(minLength: 6)
                Text(value.map { "\($0.roundedInt)%" } ?? "--")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.3))
                    Capsule()
                        .fill(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
                        .frame(width: geo.size.width * max(0, min(1, (value ?? 0) / 100)).cgFloat)
                }
            }
            .frame(height: 7)
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct MusicNowPlayingComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var snapshot: MusicSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot?.title ?? "Nothing Playing")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                .lineLimit(1)

            if component.showArtist ?? true {
                Text(snapshot?.artist ?? "Music")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                    .lineLimit(1)
            }

            if component.showProgress ?? true {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.3))
                        Capsule()
                            .fill(ThemeResolver.color(for: "accent", theme: theme))
                            .frame(width: geo.size.width * (snapshot?.progress ?? 0).cgFloat)
                    }
                }
                .frame(height: 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 1) {
            let value = await DataServiceManager.shared.musicNowPlaying()
            await MainActor.run {
                snapshot = value
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct NewsHeadlinesComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var headlines: [NewsHeadlineSnapshot] = []
    @State private var hasLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !hasLoaded {
                LoadingShimmerView(theme: theme, lines: 3, lineHeight: 10)
            } else if headlines.isEmpty {
                Text("No headlines")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            } else {
                ForEach(headlines.prefix(max(1, component.maxItems ?? 3))) { headline in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                            .lineLimit(2)
                        if component.showSource ?? true, let source = headline.source {
                            Text(source)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ThemeResolver.color(for: "muted", theme: theme))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 30 * 60) {
            let feed = component.feedUrl ?? "https://feeds.bbci.co.uk/news/rss.xml"
            let maxItems = component.maxItems ?? 3
            let value = await DataServiceManager.shared.news(feedURL: feed, maxItems: maxItems)
            await MainActor.run {
                headlines = value
                hasLoaded = true
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct ScreenTimeComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var snapshot: ScreenTimeSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot?.total ?? "Screen Time Unavailable")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(ThemeResolver.color(for: component.color ?? "accent", theme: theme))

            ForEach(snapshot?.topApps.prefix(max(1, component.maxApps ?? 3)) ?? []) { app in
                HStack {
                    Text(app.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                    Spacer(minLength: 6)
                    Text(app.durationText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 5 * 60) {
            let value = await DataServiceManager.shared.screenTime(maxApps: component.maxApps ?? 3)
            await MainActor.run {
                snapshot = value
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct ChecklistRuntimeItem: Identifiable {
    var id: String
    var text: String
    var checked: Bool
}

private struct ChecklistComponentView: View {
    let widgetID: UUID
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var items: [ChecklistRuntimeItem] = []
    @State private var hasLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = component.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
            }

            ForEach(items) { item in
                Button {
                    guard component.interactive ?? true else { return }
                    toggle(itemID: item.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                ThemeResolver.color(
                                    for: item.checked
                                        ? (component.checkedColor ?? "positive")
                                        : (component.uncheckedColor ?? "muted"),
                                    theme: theme
                                )
                            )

                        Text(item.text)
                            .font(.system(size: (component.size ?? 13).cgFloat, weight: .medium))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                            .lineLimit(1)
                            .strikethrough((component.strikethrough ?? true) && item.checked)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!(component.interactive ?? true))
            }

            if component.showProgress ?? true {
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.28))
                            Capsule()
                                .fill(ThemeResolver.color(for: component.checkedColor ?? "positive", theme: theme))
                                .frame(width: geo.size.width * progress.cgFloat)
                        }
                    }
                    .frame(height: 7)

                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .task(id: component.id ?? component.title ?? "checklist") {
            await load()
        }
    }

    private var progress: Double {
        guard !items.isEmpty else { return 0 }
        let checked = items.filter(\.checked).count
        return Double(checked) / Double(items.count)
    }

    private var componentKey: String {
        componentStorageKey(widgetID: widgetID, component: component, fallback: "checklist")
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        let defaults = (component.items ?? []).map {
            ChecklistRuntimeItem(id: $0.id, text: $0.text, checked: $0.checked)
        }
        let fallback = defaults.isEmpty
            ? [
                ChecklistRuntimeItem(id: "item-1", text: "Task one", checked: false),
                ChecklistRuntimeItem(id: "item-2", text: "Task two", checked: false)
            ]
            : defaults

        let persisted = await UserDataStore.shared.checklistState(
            for: componentKey,
            resetsDaily: component.resetsDaily ?? false
        )
        let merged = fallback.map {
            ChecklistRuntimeItem(id: $0.id, text: $0.text, checked: persisted[$0.id] ?? $0.checked)
        }

        await MainActor.run {
            items = merged
        }
    }

    private func toggle(itemID: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].checked.toggle()
        let checked = items[index].checked
        Task {
            await UserDataStore.shared.setChecklistItem(
                for: componentKey,
                itemID: itemID,
                checked: checked,
                resetsDaily: component.resetsDaily ?? false
            )
        }
    }
}

private struct HabitRuntimeItem: Identifiable {
    var id: String
    var name: String
    var icon: String
    var target: Int
    var unit: String
    var count: Int
    var streak: Int
}

private struct HabitTrackerComponentView: View {
    let widgetID: UUID
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var habits: [HabitRuntimeItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(habits) { habit in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: habit.icon)
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
                        Text(habit.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                        Spacer(minLength: 6)
                        Text("\(habit.count)/\(habit.target)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))

                        if component.interactive ?? true {
                            Button {
                                increment(habitID: habit.id)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ThemeResolver.color(for: "muted", theme: theme).opacity(0.28))
                            Capsule()
                                .fill(ThemeResolver.color(for: component.color ?? "accent", theme: theme))
                                .frame(width: geo.size.width * min(1, max(0, Double(habit.count) / Double(max(1, habit.target)))).cgFloat)
                        }
                    }
                    .frame(height: 7)

                    if component.showStreak ?? false {
                        Text("Streak: \(habit.streak) day\(habit.streak == 1 ? "" : "s")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .task(id: component.id ?? component.title ?? "habits") {
            await load()
        }
    }

    private var componentKey: String {
        componentStorageKey(widgetID: widgetID, component: component, fallback: "habit-tracker")
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func load() async {
        let configs = component.habits ?? []
        let fallback = configs.isEmpty
            ? [HabitConfig(id: "water", name: "Water", icon: "drop.fill", target: 8, unit: "glasses")]
            : configs

        await UserDataStore.shared.registerHabitTargets(fallback, componentKey: componentKey)

        var snapshot: [HabitRuntimeItem] = []
        for habit in fallback {
            let count = await UserDataStore.shared.habitCount(componentKey: componentKey, habitID: habit.id)
            let streak = await UserDataStore.shared.habitStreak(componentKey: componentKey, habitID: habit.id)
            snapshot.append(
                HabitRuntimeItem(
                    id: habit.id,
                    name: habit.name,
                    icon: habit.icon ?? "flame.fill",
                    target: max(1, habit.target),
                    unit: habit.unit ?? "",
                    count: count,
                    streak: streak
                )
            )
        }

        await MainActor.run {
            habits = snapshot
        }
    }

    private func increment(habitID: String) {
        Task {
            await UserDataStore.shared.incrementHabit(componentKey: componentKey, habitID: habitID)
            await load()
        }
    }
}

private struct NoteComponentView: View {
    let widgetID: UUID
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var text: String = ""
    @State private var hasLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = component.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ThemeResolver.color(for: "secondary", theme: theme))
            }

            if component.editable ?? true {
                TextEditor(text: $text)
                    .font(.system(size: (component.size ?? 13).cgFloat, weight: .regular))
                    .foregroundColor(.primary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 68)
                    .onChange(of: text) { _, newValue in
                        Task {
                            await UserDataStore.shared.setNote(newValue, for: componentKey)
                        }
                    }
            } else {
                Text(text)
                    .font(.system(size: (component.size ?? 13).cgFloat, weight: .regular))
                    .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .task(id: component.id ?? component.title ?? "note") {
            await load()
        }
    }

    private var componentKey: String {
        componentStorageKey(widgetID: widgetID, component: component, fallback: "note")
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        let persisted = await UserDataStore.shared.note(for: componentKey)
        await MainActor.run {
            text = persisted ?? component.content ?? ""
        }
    }
}

private struct QuoteComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var quoteText: String = ""
    @State private var authorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayedQuote)
                .font(.system(size: (component.size ?? 14).cgFloat, weight: .regular, design: .serif))
                .foregroundStyle(ThemeResolver.color(for: component.color ?? "secondary", theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            if let authorText, !authorText.isEmpty {
                Text(authorText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeResolver.color(for: component.authorColor ?? "muted", theme: theme))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .task {
            refreshQuote()
        }
        .polling(every: 60 * 60) {
            await MainActor.run {
                refreshQuote()
            }
        }
    }

    private var displayedQuote: String {
        if component.showQuotationMarks ?? true {
            return "\"\(quoteText)\""
        }
        return quoteText
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func refreshQuote() {
        let quotePool = resolvedQuotePool()
        guard !quotePool.isEmpty else {
            quoteText = "Stay focused."
            authorText = nil
            return
        }

        let index: Int
        if (component.style ?? "").lowercased() == "daily" {
            index = Calendar.current.ordinality(of: .day, in: .year, for: Date()).map { $0 % quotePool.count } ?? 0
        } else {
            index = Int.random(in: 0..<quotePool.count)
        }

        let selected = quotePool[index]
        if let split = selected.range(of: " — ") {
            quoteText = String(selected[..<split.lowerBound])
            authorText = String(selected[split.upperBound...])
        } else {
            quoteText = selected
            authorText = nil
        }
    }

    private func resolvedQuotePool() -> [String] {
        if (component.source ?? "").lowercased() == "custom",
           let custom = component.customQuotes,
           !custom.isEmpty {
            return custom
        }

        let category = (component.category ?? "motivation").lowercased()
        if category.contains("focus") {
            return [
                "Focus is saying no to a hundred good ideas. — Steve Jobs",
                "What gets measured gets managed. — Peter Drucker",
                "Small disciplines repeated daily lead to great achievements. — John Maxwell"
            ]
        }

        return [
            "Success is the sum of small efforts repeated day in and day out. — Robert Collier",
            "Discipline is choosing between what you want now and what you want most. — Abraham Lincoln",
            "You do not rise to the level of your goals. You fall to the level of your systems. — James Clear",
            "Do the hard things first. Easy gets easier after. — Unknown"
        ]
    }
}

private struct ShortcutLauncherComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    var body: some View {
        let shortcuts = component.shortcuts ?? []
        Group {
            if (component.style ?? "grid").lowercased() == "list" {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, shortcut in
                        Button {
                            launch(shortcut.action)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: shortcut.icon ?? "bolt.circle.fill")
                                Text(shortcut.name)
                                Spacer(minLength: 0)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], spacing: 10) {
                    ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, shortcut in
                        Button {
                            launch(shortcut.action)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: shortcut.icon ?? "bolt.circle.fill")
                                    .font(.system(size: (component.iconSize ?? 24).cgFloat, weight: .regular))
                                Text(shortcut.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                            .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func launch(_ action: String) {
        let trimmed = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.hasPrefix("open:") {
            let bundleID = String(trimmed.dropFirst("open:".count))
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: .init(), completionHandler: nil)
            }
            return
        }

        if trimmed.hasPrefix("shortcut:") {
            let name = String(trimmed.dropFirst("shortcut:".count))
            var components = URLComponents(string: "shortcuts://run-shortcut")
            components?.queryItems = [URLQueryItem(name: "name", value: name)]
            if let url = components?.url {
                NSWorkspace.shared.open(url)
            }
            return
        }

        if trimmed.hasPrefix("url:"),
           let url = URL(string: String(trimmed.dropFirst("url:".count))) {
            NSWorkspace.shared.open(url)
            return
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct LinkBookmarksComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    var body: some View {
        let links = component.links ?? []
        Group {
            if (component.style ?? "grid").lowercased() == "list" {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                        Button {
                            open(link.url)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: link.icon ?? "link")
                                Text(link.name)
                                Spacer(minLength: 0)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], spacing: 10) {
                    ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                        Button {
                            open(link.url)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: link.icon ?? "link")
                                    .font(.system(size: (component.iconSize ?? 22).cgFloat))
                                Text(link.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func open(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct ProgressRingComponentView: View {
    let widgetID: UUID
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(ThemeResolver.color(for: component.trackColor ?? "muted", theme: theme).opacity(0.35), lineWidth: (component.lineWidth ?? 6).cgFloat)

            Circle()
                .trim(from: 0, to: progress.cgFloat)
                .stroke(
                    ThemeResolver.color(for: component.fillColor ?? "accent", theme: theme),
                    style: StrokeStyle(lineWidth: (component.lineWidth ?? 6).cgFloat, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ThemeResolver.color(for: component.color ?? "primary", theme: theme))
        }
        .frame(width: (component.size ?? 66).cgFloat, height: (component.size ?? 66).cgFloat)
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 30) {
            let resolved = await resolveProgressValue(source: component.source, widgetID: widgetID, component: component)
            await MainActor.run {
                progress = resolved ?? 0
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct ProgressBarComponentView: View {
    let widgetID: UUID
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var progress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ThemeResolver.color(for: component.trackColor ?? "muted", theme: theme).opacity(0.3))
                    Capsule()
                        .fill(ThemeResolver.color(for: component.fillColor ?? "accent", theme: theme))
                        .frame(width: geo.size.width * progress.cgFloat)
                }
            }
            .frame(height: (component.height ?? 8).cgFloat)

            if component.showPercentage ?? true {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ThemeResolver.color(for: component.color ?? "secondary", theme: theme))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 30) {
            let resolved = await resolveProgressValue(source: component.source, widgetID: widgetID, component: component)
            await MainActor.run {
                progress = resolved ?? 0
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }
}

private struct ChartComponentView: View {
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var values: [Double] = []

    var body: some View {
        SparklineChartView(
            values: values,
            color: ThemeResolver.color(for: component.color ?? "accent", theme: theme),
            height: (component.height ?? 40).cgFloat
        )
        .frame(maxWidth: .infinity, alignment: alignment)
        .polling(every: 60) {
            let source = component.source ?? ""
            let loaded = await loadValues(for: source)
            await MainActor.run {
                values = loaded
            }
        }
    }

    private var alignment: Alignment {
        switch component.alignment?.lowercased() {
        case "center":
            return .center
        case "trailing":
            return .trailing
        default:
            return .leading
        }
    }

    private func loadValues(for source: String) async -> [Double] {
        let lowered = source.lowercased()
        if lowered.contains("stocks.") {
            let symbol = lowered
                .replacingOccurrences(of: "stocks.", with: "")
                .components(separatedBy: ".")
                .first?
                .uppercased() ?? "AAPL"
            return (await DataServiceManager.shared.stock(symbol: symbol, period: "7d"))?.history ?? []
        }

        if lowered.contains("crypto.") {
            let symbol = lowered
                .replacingOccurrences(of: "crypto.", with: "")
                .components(separatedBy: ".")
                .first?
                .uppercased() ?? "BTC"
            return (await DataServiceManager.shared.crypto(symbol: symbol, currency: "USD"))?.history ?? []
        }

        return [4, 5, 5.5, 6, 5.2, 5.8, 6.4, 6.1, 7]
    }
}

private struct SparklineChartView: View {
    let values: [Double]
    let color: Color
    let height: CGFloat

    var body: some View {
        let safeValues = values.isEmpty ? [0, 0, 0] : values
        ZStack {
            SparklineShape(values: safeValues)
                .stroke(color.opacity(0.95), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            SparklineFillShape(values: safeValues)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.28), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(height: height)
    }
}

private struct SparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 0.0001)

        for (index, value) in values.enumerated() {
            let x = rect.minX + CGFloat(index) / CGFloat(values.count - 1) * rect.width
            let normalized = (value - minValue) / range
            let y = rect.maxY - CGFloat(normalized) * rect.height

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

private struct SparklineFillShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = SparklineShape(values: values).path(in: rect)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PollingModifier: ViewModifier {
    let interval: TimeInterval
    let action: @Sendable () async -> Void

    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                start()
            }
            .onChange(of: interval) { _ in
                start()
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
    }

    private func start() {
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                await action()
                let ns = UInt64(max(1, interval) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }
}

private extension View {
    func polling(every interval: TimeInterval, _ action: @escaping @Sendable () async -> Void) -> some View {
        modifier(PollingModifier(interval: interval, action: action))
    }
}

private func componentStorageKey(widgetID: UUID, component: ComponentConfig, fallback: String) -> String {
    if let explicit = component.id, !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return scopedStorageKey(widgetID: widgetID, raw: explicit)
    }

    if let title = component.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return scopedStorageKey(widgetID: widgetID, raw: title)
    }

    if let label = component.label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return scopedStorageKey(widgetID: widgetID, raw: label)
    }

    return scopedStorageKey(widgetID: widgetID, raw: fallback)
}

private func scopedStorageKey(widgetID: UUID, raw: String) -> String {
    let sanitized = raw
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9_-]", with: "-", options: .regularExpression)
    return "\(widgetID.uuidString.lowercased())::\(sanitized)"
}

private func resolveProgressValue(source: String?, widgetID: UUID, component: ComponentConfig) async -> Double? {
    guard let source = source?.trimmingCharacters(in: .whitespacesAndNewlines),
          !source.isEmpty else {
        return nil
    }

    let lowered = source.lowercased()
    if let direct = Double(lowered) {
        return direct.clamped(0, 1)
    }

    if lowered == "battery.percentage" || lowered == "battery.level" {
        let battery = await DataServiceManager.shared.battery()
        return battery.percentage.map { ($0 / 100).clamped(0, 1) }
    }

    if lowered == "day.progress" {
        return currentDayProgress(startHour: component.startHour ?? 8, endHour: component.endHour ?? 23)
    }

    if lowered == "year.progress" {
        return currentYearProgress()
    }

    if lowered == "checklist.progress" {
        let key = componentStorageKey(widgetID: widgetID, component: component, fallback: "checklist")
        return await UserDataStore.shared.checklistProgress(for: key)
    }

    if lowered.hasPrefix("checklist."), lowered.hasSuffix(".progress") {
        let parts = lowered.split(separator: ".")
        if parts.count >= 3 {
            let componentID = String(parts[1])
            let key = scopedStorageKey(widgetID: widgetID, raw: componentID)
            return await UserDataStore.shared.checklistProgress(for: key)
        }
    }

    if lowered.hasPrefix("habits."), lowered.hasSuffix(".progress") {
        let parts = lowered.split(separator: ".")
        if parts.count >= 3 {
            let habitID = String(parts[1])
            if let scoped = await UserDataStore.shared.habitProgress(
                for: habitID,
                componentKey: componentStorageKey(widgetID: widgetID, component: component, fallback: "habit-tracker")
            ) {
                return scoped
            }
            return await UserDataStore.shared.habitProgress(for: habitID, componentKey: nil)
        }
    }

    return nil
}

private func currentDayProgress(startHour: Int, endHour: Int) -> Double {
    let now = Date()
    let calendar = Calendar.current
    let dayStart = calendar.date(bySettingHour: max(0, min(23, startHour)), minute: 0, second: 0, of: now) ?? now
    let dayEnd = calendar.date(bySettingHour: max(1, min(24, endHour)), minute: 0, second: 0, of: now) ?? now
    let total = dayEnd.timeIntervalSince(dayStart)
    guard total > 0 else { return 0 }
    let elapsed = now.timeIntervalSince(dayStart)
    return (elapsed / total).clamped(0, 1)
}

private func currentYearProgress() -> Double {
    let now = Date()
    let calendar = Calendar.current
    let year = calendar.component(.year, from: now)
    let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
    let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now
    let total = end.timeIntervalSince(start)
    guard total > 0 else { return 0 }
    return (now.timeIntervalSince(start) / total).clamped(0, 1)
}

private extension EdgeInsetsConfig {
    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top.cgFloat, leading: leading.cgFloat, bottom: bottom.cgFloat, trailing: trailing.cgFloat)
    }
}

private extension Double {
    var cgFloat: CGFloat { CGFloat(self) }
    var roundedInt: Int { Int(self.rounded()) }

    func clamped(_ minValue: Double, _ maxValue: Double) -> Double {
        Swift.min(Swift.max(self, minValue), maxValue)
    }
}

private extension CGFloat {
    func clamped(_ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, minValue), maxValue)
    }
}

private func resolvedTimezone(_ timezoneIdentifier: String?) -> TimeZone {
    guard let timezoneIdentifier,
          timezoneIdentifier.lowercased() != "local",
          let timezone = TimeZone(identifier: timezoneIdentifier) else {
        return .current
    }
    return timezone
}

private func formatClock(_ seconds: Int) -> String {
    let clamped = max(0, seconds)
    let hours = clamped / 3600
    let minutes = (clamped % 3600) / 60
    let secs = clamped % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    return String(format: "%02d:%02d", minutes, secs)
}

private func formatHoursMinutes(_ seconds: Int) -> String {
    let clamped = max(0, seconds)
    let hours = clamped / 3600
    let minutes = (clamped % 3600) / 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

private func formatPrice(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.minimumFractionDigits = value >= 1 ? 2 : 4
    formatter.maximumFractionDigits = value >= 1 ? 2 : 6
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
}

private func calendarTimeText(_ date: Date, allDay: Bool) -> String {
    if allDay {
        return "All Day"
    }

    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func reminderDueText(_ dueDate: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(dueDate) {
        return "Today"
    }
    if calendar.isDateInTomorrow(dueDate) {
        return "Tomorrow"
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: dueDate)
}
