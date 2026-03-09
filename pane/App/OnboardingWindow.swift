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
            onStartBuilding: onStartBuilding,
            onApplyTheme: onApplyTheme,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to widgie"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setFrame(NSRect(x: 0, y: 0, width: 560, height: 640), display: false)
        window.minSize = NSSize(width: 520, height: 580)
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear

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

// MARK: - Onboarding Root

private enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case apiKey = 1
    case preferences = 2
}

private struct OnboardingRootView: View {
    @ObservedObject var settingsStore: SettingsStore
    let onStartBuilding: () -> Void
    let onApplyTheme: (WidgetTheme) -> Void
    let onDismiss: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var apiKeyText: String = ""
    @State private var selectedProvider: AIProvider = .openAI
    @State private var keyValidationState: KeyValidationState = .idle

    private enum KeyValidationState: Equatable {
        case idle
        case validating
        case valid
        case invalid(String)
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 36) // Titlebar space

                // Step indicator
                stepIndicator
                    .padding(.bottom, 28)

                // Content
                Group {
                    switch step {
                    case .welcome:
                        welcomeStep
                    case .apiKey:
                        apiKeyStep
                    case .preferences:
                        preferencesStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: step)

                Spacer()

                // Navigation
                navigationBar
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 40)
        }
        .frame(minWidth: 520, minHeight: 580)
        .onAppear {
            // Pre-fill if user already has a key
            if !settingsStore.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedProvider = .openAI
                apiKeyText = settingsStore.openAIAPIKey
            } else if !settingsStore.claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedProvider = .claude
                apiKeyText = settingsStore.claudeAPIKey
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue
                          ? Color.white.opacity(0.8)
                          : Color.white.opacity(0.12))
                    .frame(width: s == step ? 24 : 8, height: 4)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            // App icon area
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.08), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 10) {
                Text("Welcome to widgie")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Build beautiful desktop widgets from simple prompts.\nPowered by AI, styled your way.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Feature highlights
            VStack(spacing: 10) {
                featureRow(icon: "sparkles", text: "Describe any widget in plain English")
                featureRow(icon: "paintbrush.fill", text: "10+ themes that adapt to your style")
                featureRow(icon: "arrow.up.left.and.arrow.down.right", text: "Resize freely — content auto-adapts")
                featureRow(icon: "bolt.fill", text: "Live data: weather, stocks, music, and more")
            }
            .padding(.top, 8)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - API Key Step

    private var apiKeyStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.6))

                Text("Connect your AI")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Enter your API key to generate widgets.\nYour key is stored securely in macOS Keychain.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Provider picker
            HStack(spacing: 0) {
                providerTab(.openAI, label: "OpenAI", icon: "brain")
                providerTab(.claude, label: "Claude", icon: "sparkle")
            }
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            // Key input
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .frame(width: 32)

                    SecureField(
                        selectedProvider == .openAI ? "sk-..." : "sk-ant-...",
                        text: $apiKeyText
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white)

                    if keyValidationState == .valid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                            .padding(.trailing, 10)
                    } else if keyValidationState == .validating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 10)
                    }
                }
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )

                if case .invalid(let msg) = keyValidationState {
                    Text(msg)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.8))
                }

                // Help links
                HStack(spacing: 16) {
                    if selectedProvider == .openAI {
                        linkButton("Get OpenAI key", url: "https://platform.openai.com/api-keys")
                    } else {
                        linkButton("Get Claude key", url: "https://console.anthropic.com/settings/keys")
                    }
                    Spacer()
                    Text("Stored in Keychain")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }

            // Model selection (after key is entered)
            if !apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Model")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .textCase(.uppercase)

                    if selectedProvider == .openAI {
                        Picker("", selection: $settingsStore.openAIModel) {
                            Text("gpt-4o").tag("gpt-4o")
                            Text("o3-mini").tag("o3-mini")
                            Text("o1").tag("o1")
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Picker("", selection: $settingsStore.claudeModel) {
                            Text("Opus 4.5").tag("claude-opus-4-5")
                            Text("Sonnet 4.5").tag("claude-sonnet-4-5")
                            Text("Haiku 4.5").tag("claude-haiku-4-5-20251001")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeOut(duration: 0.2), value: apiKeyText.isEmpty)
            }
        }
        .onChange(of: apiKeyText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                keyValidationState = .idle
            } else {
                // Save to keychain as user types (debounced by SwiftUI)
                if selectedProvider == .openAI {
                    settingsStore.openAIAPIKey = trimmed
                } else {
                    settingsStore.claudeAPIKey = trimmed
                }
                settingsStore.selectedProvider = selectedProvider
                keyValidationState = .valid
            }
        }
        .onChange(of: selectedProvider) { _, _ in
            // Reset when switching providers
            apiKeyText = ""
            keyValidationState = .idle
            if selectedProvider == .openAI {
                apiKeyText = settingsStore.openAIAPIKey
            } else {
                apiKeyText = settingsStore.claudeAPIKey
            }
        }
    }

    private var borderColor: Color {
        switch keyValidationState {
        case .valid: return .green.opacity(0.4)
        case .invalid: return .red.opacity(0.4)
        default: return Color.white.opacity(0.1)
        }
    }

    private func providerTab(_ provider: AIProvider, label: String, icon: String) -> some View {
        let isActive = selectedProvider == provider
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedProvider = provider
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? Color.white.opacity(0.1) : Color.clear)
            .foregroundStyle(isActive ? .white : Color.white.opacity(0.4))
        }
        .buttonStyle(.plain)
    }

    private func linkButton(_ title: String, url: String) -> some View {
        Button {
            if let nsURL = URL(string: url) {
                NSWorkspace.shared.open(nsURL)
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.white.opacity(0.4))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Preferences Step

    private var preferencesStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.6))

                Text("Make it yours")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Pick a theme and set your defaults.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            // Theme picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Theme")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .textCase(.uppercase)

                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(WidgetTheme.activeThemes, id: \.rawValue) { theme in
                        OnboardingThemeChip(
                            theme: theme,
                            isSelected: settingsStore.defaultTheme == theme
                        ) {
                            settingsStore.defaultTheme = theme
                            onApplyTheme(theme)
                        }
                    }
                }

                // Live preview
                OnboardingWidgetPreview(theme: settingsStore.defaultTheme)
                    .frame(height: 90)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // Quick settings
            VStack(spacing: 10) {
                HStack {
                    Text("Location")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                    Spacer()
                    TextField("City, State", text: $settingsStore.defaultLocation)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(width: 160)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                HStack {
                    Text("Temperature")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                    Spacer()
                    Picker("", selection: $settingsStore.useFahrenheit) {
                        Text("°C").tag(false)
                        Text("°F").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }

                HStack {
                    Text("Launch at login")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                    Spacer()
                    Toggle("", isOn: $settingsStore.launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack {
            if step != .welcome {
                Button {
                    withAnimation {
                        step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if step == .apiKey && !settingsStore.hasAnyRemoteAPIKey {
                Button {
                    withAnimation {
                        step = .preferences
                    }
                } label: {
                    Text("Skip for now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }

            if step == .preferences {
                Button {
                    onStartBuilding()
                    onDismiss()
                } label: {
                    HStack(spacing: 6) {
                        Text("Start Building")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation {
                        step = OnboardingStep(rawValue: step.rawValue + 1) ?? .preferences
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Continue")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Theme Chip

private struct OnboardingThemeChip: View {
    let theme: WidgetTheme
    let isSelected: Bool
    let action: () -> Void

    private var palette: ThemePalette { ThemeResolver.palette(for: theme) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(theme.previewBackground)
                    .frame(height: 28)
                    .overlay(
                        HStack(spacing: 3) {
                            Circle().fill(palette.accent).frame(width: 4, height: 4)
                            RoundedRectangle(cornerRadius: 1).fill(palette.primary).frame(width: 14, height: 2.5)
                            Spacer()
                        }
                        .padding(.horizontal, 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(
                                isSelected ? palette.accent : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                    )

                Text(theme.displayName)
                    .font(.system(size: 8.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : Color.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget Preview

private struct OnboardingWidgetPreview: View {
    let theme: WidgetTheme

    var body: some View {
        let palette = ThemeResolver.palette(for: theme)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.accent)
                Text("My Widget")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.primary)
                Spacer()
            }

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
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.previewBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}
