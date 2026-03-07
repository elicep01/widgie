import AppKit
import SwiftUI

@MainActor
final class WidgetGalleryWindow {
    private let window: NSPanel
    private let rootView: GalleryRootView

    init(
        templateStore: WidgetTemplateStore,
        settingsStore: SettingsStore,
        onAddWidget: @escaping (String, WidgetTheme) -> Void
    ) {
        let root = GalleryRootView(
            templateStore: templateStore,
            settingsStore: settingsStore,
            onAddWidget: onAddWidget
        )
        self.rootView = root

        let hostingController = NSHostingController(rootView: root)
        let panel = NSPanel(contentViewController: hostingController)
        panel.title = "Widget Gallery"
        panel.styleMask = [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel]
        panel.setFrame(NSRect(x: 0, y: 0, width: 780, height: 620), display: false)
        panel.minSize = NSSize(width: 600, height: 480)
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = true
        self.window = panel
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
    let onAddWidget: (String, WidgetTheme) -> Void

    @State private var selectedTheme: WidgetTheme = .obsidian
    @State private var selectedCategory: String = "all"
    @State private var hoveredItem: String?

    private var categories: [String] {
        templateStore.storeCategories()
    }

    private var items: [StoreTemplateItem] {
        let all = templateStore.storeItems()
        if selectedCategory == "all" { return all }
        return all.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                galleryGrid
                    .padding(20)
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            selectedTheme = settingsStore.defaultTheme
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Widget Gallery")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Pick a widget, preview it in any theme, and add it to your desktop.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                // Theme picker
                HStack(spacing: 6) {
                    Text("Theme")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(WidgetTheme.allCases.filter { $0 != .custom }, id: \.rawValue) { theme in
                                themeChip(theme)
                            }
                        }
                    }
                }

                Spacer()

                // Category filter
                HStack(spacing: 4) {
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

    private func themeChip(_ theme: WidgetTheme) -> some View {
        let palette = ThemeResolver.palette(for: theme)
        let isSelected = selectedTheme == theme
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTheme = theme
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 8, height: 8)
                Text(theme.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? palette.accent.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? palette.accent.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func categoryChip(_ id: String, label: String) -> some View {
        let isSelected = selectedCategory == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = id
            }
        } label: {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
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
            }
        }
    }

    private func galleryCard(_ item: StoreTemplateItem) -> some View {
        let isHovered = hoveredItem == item.id
        var themedConfig = item.config
        themedConfig.theme = selectedTheme
        themedConfig.background = BackgroundConfig.default(for: selectedTheme)

        return VStack(spacing: 0) {
            // Widget preview
            WidgetRenderer(config: themedConfig)
                .frame(
                    width: min(item.config.size.width, 280),
                    height: min(item.config.size.height, 200)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .scaleEffect(isHovered ? 1.03 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHovered)

            // Info + Add button
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
                Button {
                    onAddWidget(item.id, selectedTheme)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ThemeResolver.palette(for: selectedTheme).accent)
                }
                .buttonStyle(.plain)
                .help("Add to desktop")
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
