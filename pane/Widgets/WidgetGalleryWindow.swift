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
        let win = NSPanel(contentViewController: hostingController)
        win.title = "Widget Gallery"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setFrame(NSRect(x: 0, y: 0, width: 780, height: 620), display: false)
        win.minSize = NSSize(width: 600, height: 480)
        win.center()
        win.isReleasedWhenClosed = false
        win.isFloatingPanel = false
        win.becomesKeyOnlyIfNeeded = false
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
    let onAddWidget: (String, WidgetTheme) -> Void

    @State private var selectedTheme: WidgetTheme = .obsidian
    @State private var selectedCategory: String = "all"
    @State private var hoveredItem: String?
    @State private var addedItems: Set<String> = []

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
                        ForEach(WidgetTheme.allCases.filter { $0 != .custom }, id: \.rawValue) { theme in
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
            }
        }
    }

    /// Uniform preview size for all gallery cards so they look consistent.
    private static let previewWidth: CGFloat = 260
    private static let previewHeight: CGFloat = 160

    private func galleryCard(_ item: StoreTemplateItem) -> some View {
        let isHovered = hoveredItem == item.id
        let isAdded = addedItems.contains(item.id)
        var themedConfig = item.config
        themedConfig.theme = selectedTheme
        themedConfig.background = BackgroundConfig.default(for: selectedTheme)

        // Scale the widget to fit uniformly inside the preview box
        let widgetW = CGFloat(item.config.size.width)
        let widgetH = CGFloat(item.config.size.height)
        let scaleX = Self.previewWidth / widgetW
        let scaleY = Self.previewHeight / widgetH
        let fitScale = min(scaleX, scaleY, 1.0)  // never upscale past 1×

        return VStack(spacing: 0) {
            // Uniform preview container — centers the widget inside
            ZStack {
                Color.clear
                WidgetRenderer(config: themedConfig)
                    .frame(width: widgetW, height: widgetH)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .scaleEffect(fitScale)
                    .allowsHitTesting(false)
            }
            .frame(width: Self.previewWidth, height: Self.previewHeight)
            .clipped()
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
                if isAdded {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text("Added")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        onAddWidget(item.id, selectedTheme)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            addedItems.insert(item.id)
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
