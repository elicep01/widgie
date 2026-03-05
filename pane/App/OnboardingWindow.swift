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
        onOpenGallery: @escaping () -> Void,
        onStartBuilding: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onDismiss = onDismiss
        super.init()

        let rootView = OnboardingRootView(
            settingsStore: settingsStore,
            onOpenAISettings: onOpenAISettings,
            onOpenGallery: onOpenGallery,
            onStartBuilding: onStartBuilding,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to widgie"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setFrame(NSRect(x: 0, y: 0, width: 760, height: 560), display: false)
        window.minSize = NSSize(width: 700, height: 520)
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
    let onOpenGallery: () -> Void
    let onStartBuilding: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            header
            features
            setupPanel
            footer
        }
        .padding(22)
        .frame(minWidth: 700, minHeight: 520)
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
            FeatureCard(
                icon: "square.grid.2x2",
                title: "Gallery + Templates",
                detail: "Start from elegant snippets and customize with one click."
            )
        }
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
            Button("Browse Gallery") {
                onOpenGallery()
            }
            .buttonStyle(.bordered)

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
