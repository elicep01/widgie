import AppKit
import SwiftUI

@MainActor
final class WidgetGalleryWindow {
    private let window: NSWindow
    private let viewModel: WidgetGalleryViewModel

    init(
        onCreateWidget: @escaping () -> Void,
        onCreateTemplate: @escaping (String) -> Void,
        onEditWidget: @escaping (UUID) -> Void,
        onDuplicateWidget: @escaping (UUID) -> Void,
        onToggleLock: @escaping (UUID, Bool) -> Void,
        onRemoveWidget: @escaping (UUID) -> Void,
        onAutoLayout: @escaping () -> Void,
        onApplyTheme: @escaping (WidgetTheme) -> Void
    ) {
        viewModel = WidgetGalleryViewModel(
            onCreateWidget: onCreateWidget,
            onCreateTemplate: onCreateTemplate,
            onEditWidget: onEditWidget,
            onDuplicateWidget: onDuplicateWidget,
            onToggleLock: onToggleLock,
            onRemoveWidget: onRemoveWidget,
            onAutoLayout: onAutoLayout,
            onApplyTheme: onApplyTheme
        )

        let rootView = WidgetGalleryRootView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Widget Gallery"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrame(NSRect(x: 0, y: 0, width: 720, height: 520), display: false)
        window.minSize = NSSize(width: 560, height: 380)
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func setSummaries(_ summaries: [WidgetSummary]) {
        viewModel.summaries = summaries
    }

    func setTemplates(_ templates: [WidgetTemplateSummary]) {
        viewModel.templates = templates
    }
}

@MainActor
private final class WidgetGalleryViewModel: ObservableObject {
    @Published var summaries: [WidgetSummary] = []
    @Published var templates: [WidgetTemplateSummary] = []
    @Published var searchText = ""

    let onCreateWidget: () -> Void
    let onCreateTemplate: (String) -> Void
    let onEditWidget: (UUID) -> Void
    let onDuplicateWidget: (UUID) -> Void
    let onToggleLock: (UUID, Bool) -> Void
    let onRemoveWidget: (UUID) -> Void
    let onAutoLayout: () -> Void
    let onApplyTheme: (WidgetTheme) -> Void

    init(
        onCreateWidget: @escaping () -> Void,
        onCreateTemplate: @escaping (String) -> Void,
        onEditWidget: @escaping (UUID) -> Void,
        onDuplicateWidget: @escaping (UUID) -> Void,
        onToggleLock: @escaping (UUID, Bool) -> Void,
        onRemoveWidget: @escaping (UUID) -> Void,
        onAutoLayout: @escaping () -> Void,
        onApplyTheme: @escaping (WidgetTheme) -> Void
    ) {
        self.onCreateWidget = onCreateWidget
        self.onCreateTemplate = onCreateTemplate
        self.onEditWidget = onEditWidget
        self.onDuplicateWidget = onDuplicateWidget
        self.onToggleLock = onToggleLock
        self.onRemoveWidget = onRemoveWidget
        self.onAutoLayout = onAutoLayout
        self.onApplyTheme = onApplyTheme
    }

    var filteredSummaries: [WidgetSummary] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return summaries
        }

        return summaries.filter { summary in
            summary.name.localizedCaseInsensitiveContains(trimmed)
                || summary.theme.rawValue.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

private struct WidgetGalleryRootView: View {
    @ObservedObject var viewModel: WidgetGalleryViewModel

    var body: some View {
        VStack(spacing: 14) {
            controls

            if viewModel.filteredSummaries.isEmpty {
                ContentUnavailableView(
                    "No Widgets",
                    systemImage: "square.grid.2x2",
                    description: Text("Create a widget to see and manage it here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.filteredSummaries) { summary in
                        WidgetGalleryRow(summary: summary, viewModel: viewModel)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            TextField("Search widgets", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220)

            Spacer(minLength: 8)

            Menu("Templates") {
                if viewModel.templates.isEmpty {
                    Text("No templates")
                } else {
                    ForEach(viewModel.templates) { template in
                        Button(template.name) {
                            viewModel.onCreateTemplate(template.id)
                        }
                    }
                }
            }
            .menuStyle(.borderlessButton)

            Menu("Theme") {
                ForEach(availableThemes, id: \.self) { theme in
                    Button(theme.label) {
                        viewModel.onApplyTheme(theme)
                    }
                }
            }
            .menuStyle(.borderlessButton)

            Button("Auto Layout") {
                viewModel.onAutoLayout()
            }
            .buttonStyle(.bordered)

            Button("New Widget") {
                viewModel.onCreateWidget()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var availableThemes: [WidgetTheme] {
        WidgetTheme.allCases.filter { $0 != .custom }
    }
}

private struct WidgetGalleryRow: View {
    let summary: WidgetSummary
    let viewModel: WidgetGalleryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(summary.name)
                    .font(.system(size: 14, weight: .semibold))
                Text(summary.theme.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 10)
                if summary.isLocked {
                    Label("Locked", systemImage: "lock.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 14) {
                Text(sizeText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                if let position = summary.position {
                    Text(positionText(position))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button("Edit") {
                    viewModel.onEditWidget(summary.id)
                }
                .buttonStyle(.bordered)

                Button("Duplicate") {
                    viewModel.onDuplicateWidget(summary.id)
                }
                .buttonStyle(.bordered)

                Button(summary.isLocked ? "Unlock" : "Lock") {
                    viewModel.onToggleLock(summary.id, !summary.isLocked)
                }
                .buttonStyle(.bordered)

                Button("Remove", role: .destructive) {
                    viewModel.onRemoveWidget(summary.id)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private var sizeText: String {
        "\(Int(summary.size.width.rounded())) × \(Int(summary.size.height.rounded()))"
    }

    private func positionText(_ position: WidgetPosition) -> String {
        "x:\(Int(position.x.rounded())) y:\(Int(position.y.rounded()))"
    }
}

private extension WidgetTheme {
    var label: String {
        rawValue.capitalized
    }
}
