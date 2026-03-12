import AppKit
import SwiftUI

@MainActor
final class WidgetGalleryWindow {
    private let window: NSPanel
    private let rootView: GalleryRootView

    init(
        templateStore: WidgetTemplateStore,
        settingsStore: SettingsStore,
        activeWidgetCounts: @escaping () -> [String: Int],
        onAddWidget: @escaping (String, WidgetTheme) -> Void,
        onRemoveWidget: @escaping (String) -> Void
    ) {
        let root = GalleryRootView(
            templateStore: templateStore,
            settingsStore: settingsStore,
            activeWidgetCountsProvider: activeWidgetCounts,
            onAddWidget: onAddWidget,
            onRemoveWidget: onRemoveWidget
        )
        self.rootView = root

        let hostingController = NSHostingController(rootView: root)
        let win = NSPanel(contentViewController: hostingController)
        win.title = "Widget Gallery"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.setFrame(NSRect(x: 0, y: 0, width: 860, height: 620), display: false)
        win.minSize = NSSize(width: 700, height: 480)
        win.center()
        win.isReleasedWhenClosed = false
        win.isFloatingPanel = false
        win.becomesKeyOnlyIfNeeded = false
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.toolbar = NSToolbar()
        win.toolbarStyle = .unifiedCompact
        self.window = win
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    var isVisible: Bool { window.isVisible }
}

// MARK: - Gallery Root View

private struct GalleryRootView: View {
    let templateStore: WidgetTemplateStore
    let settingsStore: SettingsStore
    let activeWidgetCountsProvider: () -> [String: Int]
    let onAddWidget: (String, WidgetTheme) -> Void
    let onRemoveWidget: (String) -> Void

    @State private var selectedTheme: WidgetTheme = .obsidian
    @State private var selectedCategory: String = "all"
    @State private var hoveredItem: String?
    @State private var justAdded: String?
    @State private var scrollTarget: String?
    @State private var hoveredSidebarItem: String?

    private var allItems: [StoreTemplateItem] {
        templateStore.storeItems()
    }

    private var categories: [String] {
        templateStore.storeCategories()
    }

    private var items: [StoreTemplateItem] {
        if selectedCategory == "all" { return allItems }
        return allItems.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                // Sidebar: widget name list
                sidebar
                Divider()
                // Main grid
                ScrollViewReader { proxy in
                    ScrollView {
                        galleryGrid
                            .padding(20)
                    }
                    .onChange(of: scrollTarget) { target in
                        guard let target else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        // Clear after scrolling so the same item can be tapped again
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            scrollTarget = nil
                        }
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            selectedTheme = settingsStore.defaultTheme
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(allItems) { item in
                    let isHovered = hoveredSidebarItem == item.id
                    let counts = activeWidgetCountsProvider()
                    let count = counts[item.name] ?? 0

                    Button {
                        // Switch category to "all" or the item's category so it's visible
                        if selectedCategory != "all" && item.category != selectedCategory {
                            selectedCategory = "all"
                        }
                        scrollTarget = item.id
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(isHovered ? .primary : .secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 14, minHeight: 14)
                                    .background(
                                        Capsule()
                                            .fill(ThemeResolver.palette(for: selectedTheme).accent)
                                    )
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredSidebarItem = hovering ? item.id : nil
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
        .frame(width: 150)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            // Title row with theme picker on the right
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Widget Gallery")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Preview widgets in any theme and add them to your desktop.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Compact theme dropdown
                HStack(spacing: 6) {
                    Circle()
                        .fill(ThemeResolver.palette(for: selectedTheme).accent)
                        .frame(width: 10, height: 10)
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(WidgetTheme.activeThemes, id: \.rawValue) { theme in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(ThemeResolver.palette(for: theme).accent)
                                    .frame(width: 8, height: 8)
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }
            }

            // Category filter row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryChip("all", label: "All")
                    ForEach(categories, id: \.self) { cat in
                        categoryChip(cat, label: cat.capitalized)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func categoryChip(_ id: String, label: String) -> some View {
        let isSelected = selectedCategory == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = id
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gallery Grid

    private let gridColumns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)
    ]

    private var galleryGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(items) { item in
                galleryCard(item)
                    .id(item.id)
            }
        }
    }

    /// Uniform preview size for all gallery cards so they look consistent.
    private static let previewWidth: CGFloat = 260
    private static let previewHeight: CGFloat = 160

    private func galleryCard(_ item: StoreTemplateItem) -> some View {
        let isHovered = hoveredItem == item.id
        let counts = activeWidgetCountsProvider()
        let count = counts[item.name] ?? 0
        let isJustAdded = justAdded == item.id
        var themedConfig = item.config
        themedConfig.theme = selectedTheme
        themedConfig.background = BackgroundConfig.default(for: selectedTheme)

        let widgetW = CGFloat(item.config.size.width)
        let widgetH = CGFloat(item.config.size.height)
        let scaleX = Self.previewWidth / widgetW
        let scaleY = Self.previewHeight / widgetH
        let fitScale = min(scaleX, scaleY, 1.0)

        return VStack(spacing: 0) {
            ZStack {
                Color.clear
                WidgetRenderer(config: themedConfig)
                    .frame(width: widgetW, height: widgetH)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .scaleEffect(fitScale)
                    .allowsHitTesting(false)

                if count > 0 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(
                                    Capsule()
                                        .fill(ThemeResolver.palette(for: selectedTheme).accent)
                                )
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: Self.previewWidth, height: Self.previewHeight)
            .clipped()
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(item.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()

                HStack(spacing: 4) {
                    if count > 0 {
                        Button {
                            onRemoveWidget(item.name)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Remove one from desktop")
                    }

                    if isJustAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Button {
                            onAddWidget(item.id, selectedTheme)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                justAdded = item.id
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if justAdded == item.id { justAdded = nil }
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(ThemeResolver.palette(for: selectedTheme).accent)
                        }
                        .buttonStyle(.plain)
                        .help("Add to desktop")
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(isHovered ? 0.12 : 0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.12 : 0.05), radius: isHovered ? 8 : 3, y: isHovered ? 4 : 2)
        .onHover { hovering in
            hoveredItem = hovering ? item.id : nil
        }
    }
}
