import AppKit
import SwiftUI

@MainActor
final class WidgetGalleryWindow {
    private let window: NSWindow
    private let viewModel: WidgetGalleryViewModel

    init(
        onCreateWidget: @escaping () -> Void,
        onCreateTemplate: @escaping (String) -> Void,
        onAddStoreItem: @escaping (String, WidgetTheme) -> Void,
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
            onAddStoreItem: onAddStoreItem,
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
        window.title = "Widget Store"
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setFrame(NSRect(x: 0, y: 0, width: 880, height: 660), display: false)
        window.minSize = NSSize(width: 660, height: 500)
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

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

    func setStoreItems(_ items: [StoreTemplateItem]) {
        viewModel.storeItems = items
    }

    func setStoreCategories(_ categories: [String]) {
        viewModel.storeCategories = categories
    }
}

// MARK: - ViewModel

private enum GalleryTab: String, CaseIterable {
    case store = "Store"
    case myWidgets = "My Widgets"
}

@MainActor
private final class WidgetGalleryViewModel: ObservableObject {
    @Published var summaries: [WidgetSummary] = []
    @Published var templates: [WidgetTemplateSummary] = []
    @Published var storeItems: [StoreTemplateItem] = []
    @Published var storeCategories: [String] = []
    @Published var searchText = ""
    @Published var selectedTab: GalleryTab = .store
    @Published var previewTheme: WidgetTheme = .obsidian
    @Published var selectedCategory: String? = nil
    @Published var addedItemIDs: Set<String> = []

    let onCreateWidget: () -> Void
    let onCreateTemplate: (String) -> Void
    let onAddStoreItem: (String, WidgetTheme) -> Void
    let onEditWidget: (UUID) -> Void
    let onDuplicateWidget: (UUID) -> Void
    let onToggleLock: (UUID, Bool) -> Void
    let onRemoveWidget: (UUID) -> Void
    let onAutoLayout: () -> Void
    let onApplyTheme: (WidgetTheme) -> Void

    init(
        onCreateWidget: @escaping () -> Void,
        onCreateTemplate: @escaping (String) -> Void,
        onAddStoreItem: @escaping (String, WidgetTheme) -> Void,
        onEditWidget: @escaping (UUID) -> Void,
        onDuplicateWidget: @escaping (UUID) -> Void,
        onToggleLock: @escaping (UUID, Bool) -> Void,
        onRemoveWidget: @escaping (UUID) -> Void,
        onAutoLayout: @escaping () -> Void,
        onApplyTheme: @escaping (WidgetTheme) -> Void
    ) {
        self.onCreateWidget = onCreateWidget
        self.onCreateTemplate = onCreateTemplate
        self.onAddStoreItem = onAddStoreItem
        self.onEditWidget = onEditWidget
        self.onDuplicateWidget = onDuplicateWidget
        self.onToggleLock = onToggleLock
        self.onRemoveWidget = onRemoveWidget
        self.onAutoLayout = onAutoLayout
        self.onApplyTheme = onApplyTheme
    }

    var filteredStoreItems: [StoreTemplateItem] {
        var items = storeItems
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed)
                    || $0.description.localizedCaseInsensitiveContains(trimmed)
                    || $0.category.localizedCaseInsensitiveContains(trimmed)
            }
        }
        return items
    }

    var filteredSummaries: [WidgetSummary] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return summaries }
        return summaries.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.theme.rawValue.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func addItem(_ id: String) {
        onAddStoreItem(id, previewTheme)
        addedItemIDs.insert(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.addedItemIDs.remove(id)
        }
    }
}

// MARK: - Root View

private struct WidgetGalleryRootView: View {
    @ObservedObject var viewModel: WidgetGalleryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Segmented tab picker
                HStack(spacing: 1) {
                    ForEach(GalleryTab.allCases, id: \.self) { tab in
                        GalleryTabButton(
                            title: tab.rawValue,
                            systemImage: tab == .store ? "square.grid.2x2" : "macwindow",
                            isSelected: viewModel.selectedTab == tab
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.selectedTab = tab
                            }
                        }
                    }
                }
                .padding(3)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                // Search
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("Search...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .withoutWritingTools()
                    if !viewModel.searchText.isEmpty {
                        Button { viewModel.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: 180)

                Button {
                    viewModel.onCreateWidget()
                } label: {
                    Label("Create with AI", systemImage: "sparkles")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 10)

            Divider().opacity(0.4)

            // Content
            switch viewModel.selectedTab {
            case .store:
                StoreTabView(viewModel: viewModel)
            case .myWidgets:
                MyWidgetsTabView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Gallery Tab Button

private struct GalleryTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Store Tab

private struct StoreTabView: View {
    @ObservedObject var viewModel: WidgetGalleryViewModel

    // Responsive dense grid
    private let columns = [
        GridItem(.flexible(minimum: 168, maximum: 246), spacing: 10),
        GridItem(.flexible(minimum: 168, maximum: 246), spacing: 10),
        GridItem(.flexible(minimum: 168, maximum: 246), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar: categories + theme dots
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        FilterChip(label: "All", icon: "square.grid.2x2", isSelected: viewModel.selectedCategory == nil) {
                            withAnimation(.easeInOut(duration: 0.15)) { viewModel.selectedCategory = nil }
                        }
                        ForEach(viewModel.storeCategories, id: \.self) { cat in
                            FilterChip(label: cat.capitalized, icon: categoryIcon(for: cat), isSelected: viewModel.selectedCategory == cat) {
                                withAnimation(.easeInOut(duration: 0.15)) { viewModel.selectedCategory = cat }
                            }
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 8)
                }

                Spacer(minLength: 8)

                // Theme picker
                HStack(spacing: 2) {
                    ForEach(allThemes, id: \.self) { theme in
                        ThemeDotButton(theme: theme, isSelected: viewModel.previewTheme == theme) {
                            withAnimation(.easeInOut(duration: 0.2)) { viewModel.previewTheme = theme }
                        }
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.vertical, 8)

            Divider().opacity(0.3)

            // Grid
            ScrollView {
                if viewModel.filteredStoreItems.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.filteredStoreItems) { item in
                            StoreCard(
                                item: item,
                                previewTheme: viewModel.previewTheme,
                                isAdded: viewModel.addedItemIDs.contains(item.id)
                            ) {
                                viewModel.addItem(item.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("No widgets found")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var allThemes: [WidgetTheme] {
        [.obsidian, .frosted, .neon, .paper, .transparent]
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "time": return "clock"
        case "productivity": return "checkmark.circle"
        case "weather": return "cloud.sun"
        case "finance": return "chart.line.uptrend.xyaxis"
        case "health": return "heart"
        case "system": return "cpu"
        case "media": return "play.circle"
        case "inspiration": return "quote.opening"
        case "dashboard": return "rectangle.3.group"
        default: return "square"
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor).opacity(0.7))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Dot Button

private struct ThemeDotButton: View {
    let theme: WidgetTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(dotColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle().strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
                )
                .overlay(
                    Circle().strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0)
                        .frame(width: 20, height: 20)
                )
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(theme.rawValue.capitalized)
    }

    private var dotColor: Color {
        switch theme {
        case .obsidian: return Color(hex: "#1A1F2B")
        case .frosted: return Color(hex: "#E8EDF2")
        case .neon: return Color(hex: "#0C0E1A")
        case .paper: return Color(hex: "#F4EFE6")
        case .transparent: return Color(hex: "#808080").opacity(0.35)
        case .custom: return Color.gray
        }
    }
}

// MARK: - Store Card

private struct StoreCard: View {
    let item: StoreTemplateItem
    let previewTheme: WidgetTheme
    let isAdded: Bool
    let onAdd: () -> Void

    @State private var isHovered = false

    private var themedConfig: WidgetConfig {
        var config = item.config
        config.theme = previewTheme
        config.background = BackgroundConfig.default(for: previewTheme)
        return config
    }

    // Scale to fit compact preview surface while preserving aspect ratio.
    private var previewScale: CGFloat {
        let cardWidth: CGFloat = 208
        let cardHeight: CGFloat = 104
        let widgetW = item.config.size.width.cgFloat
        let widgetH = item.config.size.height.cgFloat
        let scaleX = cardWidth / widgetW
        let scaleY = cardHeight / widgetH
        return min(scaleX, scaleY, 0.92)
    }

    // Compute the actual rendered preview size after scaling
    private var scaledSize: CGSize {
        let w = item.config.size.width.cgFloat * previewScale
        let h = item.config.size.height.cgFloat * previewScale
        return CGSize(width: w, height: h)
    }

    private var previewSurfaceHeight: CGFloat {
        (scaledSize.height + 10).clamped(72, 116)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                previewBackground
                WidgetRenderer(config: themedConfig)
                    .frame(
                        width: item.config.size.width.cgFloat,
                        height: item.config.size.height.cgFloat
                    )
                    .scaleEffect(previewScale)
                    .allowsHitTesting(false)
            }
            .frame(height: previewSurfaceHeight)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
            )

            Text(item.name)
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(item.description)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button(action: onAdd) {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isAdded ? Color.green : Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(isAdded ? "Added" : "Add")
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    isHovered ? Color.accentColor.opacity(0.35) : Color(nsColor: .separatorColor).opacity(0.12),
                    lineWidth: isHovered ? 0.9 : 0.6
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.10 : 0.03), radius: isHovered ? 6 : 2, y: 1)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var previewBackground: some View {
        Group {
            switch previewTheme {
            case .obsidian:
                LinearGradient(colors: [Color(hex: "#0D1117"), Color(hex: "#161B22")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .frosted:
                LinearGradient(colors: [Color(hex: "#EDF0F5"), Color(hex: "#F5F7FA")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .neon:
                LinearGradient(colors: [Color(hex: "#080A12"), Color(hex: "#0E1220")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .paper:
                LinearGradient(colors: [Color(hex: "#F4EFE6"), Color(hex: "#EDE7DC")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .transparent:
                LinearGradient(colors: [Color(hex: "#2A2D35"), Color(hex: "#1E2028")], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .custom:
                Color(hex: "#0D1117")
            }
        }
    }
}

// MARK: - My Widgets Tab

private struct MyWidgetsTabView: View {
    @ObservedObject var viewModel: WidgetGalleryViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(viewModel.filteredSummaries.count) widget\(viewModel.filteredSummaries.count == 1 ? "" : "s") on desktop")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(WidgetTheme.allCases.filter { $0 != .custom }, id: \.self) { theme in
                        Button(theme.rawValue.capitalized) {
                            viewModel.onApplyTheme(theme)
                        }
                    }
                } label: {
                    Label("Theme", systemImage: "paintbrush")
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 80)

                Button {
                    viewModel.onAutoLayout()
                } label: {
                    Label("Auto Layout", systemImage: "rectangle.3.group")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            Divider().opacity(0.3)

            if viewModel.filteredSummaries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(.quaternary)
                    Text("No widgets on your desktop")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Browse the Store to add widgets")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Button("Open Store") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectedTab = .store
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.filteredSummaries) { summary in
                        MyWidgetRow(summary: summary, viewModel: viewModel)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}

// MARK: - My Widget Row

private struct MyWidgetRow: View {
    let summary: WidgetSummary
    let viewModel: WidgetGalleryViewModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(themeDotColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(summary.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(summary.theme.rawValue.capitalized)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(Int(summary.size.width.rounded()))x\(Int(summary.size.height.rounded()))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 6)

            if summary.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                miniButton("pencil", help: "Edit") { viewModel.onEditWidget(summary.id) }
                miniButton("plus.square.on.square", help: "Duplicate") { viewModel.onDuplicateWidget(summary.id) }
                miniButton(summary.isLocked ? "lock.open" : "lock", help: summary.isLocked ? "Unlock" : "Lock") {
                    viewModel.onToggleLock(summary.id, !summary.isLocked)
                }
                miniButton("trash", help: "Remove", role: .destructive) { viewModel.onRemoveWidget(summary.id) }
            }
        }
        .padding(.vertical, 2)
    }

    private func miniButton(_ icon: String, help: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon).font(.system(size: 11))
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .help(help)
    }

    private var themeDotColor: Color {
        switch summary.theme {
        case .obsidian: return Color(hex: "#1A1F2B")
        case .frosted: return Color(hex: "#9DB2CC")
        case .neon: return Color(hex: "#7B61FF")
        case .paper: return Color(hex: "#C4A97D")
        case .transparent: return Color.gray.opacity(0.5)
        case .custom: return Color.gray
        }
    }
}

// MARK: - Helpers

private extension Double {
    var cgFloat: CGFloat { CGFloat(self) }
}

private extension CGFloat {
    func clamped(_ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, minValue), maxValue)
    }
}

// Color(hex:) is defined in ThemeResolver.swift
