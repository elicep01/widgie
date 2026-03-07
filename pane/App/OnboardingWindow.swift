import AppKit
import SwiftUI

@MainActor
final class OnboardingWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private let onDismiss: () -> Void
    private var hasDismissed = false

    init(
        settingsStore: SettingsStore,
        onOpenAISettings: @escaping () -> Void,
        onStartBuilding: @escaping () -> Void,
        onApplyTheme: @escaping (WidgetTheme) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onDismiss = onDismiss
        super.init()

        let rootView = OnboardingRootView(
            settingsStore: settingsStore,
            onOpenAISettings: onOpenAISettings,
            onStartBuilding: onStartBuilding,
            onApplyTheme: onApplyTheme,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to widgie"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setFrame(NSRect(x: 0, y: 0, width: 760, height: 680), display: false)
        window.minSize = NSSize(width: 700, height: 620)
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
        self.window.delegate = self
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        guard !hasDismissed else { return }
        hasDismissed = true
        window.orderOut(nil)
        onDismiss()
    }

    func windowWillClose(_ notification: Notification) {
        dismiss()
    }
}

private struct OnboardingRootView: View {
    @ObservedObject var settingsStore: SettingsStore
    let onOpenAISettings: () -> Void
    let onStartBuilding: () -> Void
    let onApplyTheme: (WidgetTheme) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                features
                themePicker
                setupPanel
                footer
            }
            .padding(22)
        }
        .frame(minWidth: 700, minHeight: 620)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.11, blue: 0.17),
                    Color(red: 0.06, green: 0.08, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to widgie")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Build desktop widgets from prompts in seconds. Resize freely, keep everything visible, and launch the prompter anytime with Cmd+Shift+W.")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var features: some View {
        HStack(spacing: 12) {
            FeatureCard(
                icon: "sparkles",
                title: "Prompt to Widget",
                detail: "Generate complete widgets with layout, data bindings, and styling."
            )
            FeatureCard(
                icon: "arrow.up.left.and.arrow.down.right",
                title: "Responsive Resize",
                detail: "Drag to any size and keep content readable with compact auto-fitting."
            )
        }
    }

    private let themeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Your Style")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                // Theme grid
                LazyVGrid(columns: themeColumns, spacing: 8) {
                    ForEach(WidgetTheme.allCases.filter { $0 != .custom }, id: \.rawValue) { theme in
                        OnboardingThemeCard(
                            theme: theme,
                            isSelected: settingsStore.defaultTheme == theme
                        ) {
                            settingsStore.defaultTheme = theme
                            onApplyTheme(theme)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Live preview widget
                VStack(spacing: 6) {
                    OnboardingWidgetPreview(theme: settingsStore.defaultTheme)
                    Text("Preview")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(width: 160)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Setup")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    Toggle("Launch widgie at login", isOn: $settingsStore.launchAtLogin)
                        .toggleStyle(.switch)
                        .foregroundStyle(.white.opacity(0.92))
                    HStack {
                        Text("Temperature unit")
                            .foregroundStyle(Color.white.opacity(0.86))
                        Spacer()
                        Picker("", selection: $settingsStore.useFahrenheit) {
                            Text("C").tag(false)
                            Text("F").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 110)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Default location")
                        .foregroundStyle(Color.white.opacity(0.86))
                    TextField("Madison, WI", text: $settingsStore.defaultLocation)
                        .textFieldStyle(.roundedBorder)
                        .withoutWritingTools()
                    Text("Hotkey: \(settingsStore.hotkeyPreset.displayName)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !settingsStore.hasAnyRemoteAPIKey {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                    Text("Add an OpenAI or Claude API key to generate widgets with AI.")
                    Spacer()
                    Button("Open AI Settings") {
                        onOpenAISettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.86))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Open AI Settings") {
                onOpenAISettings()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Start Building") {
                onStartBuilding()
                onDismiss()
            }
            .buttonStyle(.borderedProminent)

            Button("Finish") {
                onDismiss()
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.regular)
    }
}

private struct FeatureCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.white)

            Text(detail)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct OnboardingThemeCard: View {
    let theme: WidgetTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.previewBackground)
                    .frame(height: 32)
                    .overlay(
                        HStack(spacing: 3) {
                            Circle().fill(palette.accent).frame(width: 5, height: 5)
                            RoundedRectangle(cornerRadius: 1).fill(palette.primary).frame(width: 16, height: 3)
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                isSelected ? palette.accent : Color.white.opacity(0.15),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                    )

                Text(theme.displayName)
                    .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : Color.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var palette: ThemePalette { ThemeResolver.palette(for: theme) }
}

private struct OnboardingWidgetPreview: View {
    let theme: WidgetTheme

    var body: some View {
        let palette = ThemeResolver.palette(for: theme)

        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.accent)
                Text("My Widget")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.primary)
                Spacer()
            }

            // Fake stat row
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("72\u{00B0}F")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primary)
                    Text("Sunny")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(palette.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+2.4%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.positive)
                    Text("Today")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(palette.secondary)
                }
            }

            // Fake progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(palette.muted.opacity(0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(palette.accent)
                        .frame(width: geo.size.width * 0.65)
                }
            }
            .frame(height: 4)

            // Bottom tags
            HStack(spacing: 6) {
                Text("Tasks: 5")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(palette.accent.opacity(0.15))
                    .clipShape(Capsule())
                Text("3 left")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(palette.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(palette.warning.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.previewBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ThemeResolver.palette(for: theme).accent.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}
