import SwiftUI

struct MainChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let templateStore: WidgetTemplateStore
    let settingsStore: SettingsStore
    let onAddWidget: (String, WidgetTheme) -> Void

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 250)

            Divider()
                .ignoresSafeArea()

            // Main content
            if viewModel.sidebarTab == .gallery {
                InlineGalleryView(
                    templateStore: templateStore,
                    settingsStore: settingsStore,
                    activeWidgetCounts: viewModel.activeWidgetCounts,
                    onAddWidget: onAddWidget,
                    onRemoveWidget: { name in
                        viewModel.onRemoveWidgetByName?(name)
                    }
                )
            } else if viewModel.activeConversationID != nil {
                ChatDetailView(viewModel: viewModel)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 680, minHeight: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Top area with new button
            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        viewModel.startNewConversation()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("New Widget")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\u{2318}N")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 52) // Account for titlebar
            .padding(.bottom, 12)

            // Segmented control
            Picker("", selection: $viewModel.sidebarTab) {
                Text("My Widgets").tag(ChatSidebarTab.myWidgets)
                Text("Gallery").tag(ChatSidebarTab.gallery)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // Content
            if viewModel.sidebarTab == .myWidgets {
                widgetsList
            } else {
                galleryTab
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Widgets List

    private var widgetsList: some View {
        Group {
            if viewModel.conversations.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "square.on.square.dashed")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.quaternary)
                    Text("No widgets yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.conversations) { conv in
                            ConversationRow(
                                conversation: conv,
                                isSelected: viewModel.activeConversationID == conv.id,
                                onSelect: {
                                    withAnimation(.easeOut(duration: 0.12)) {
                                        viewModel.selectConversation(conv.id)
                                    }
                                },
                                onDelete: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        viewModel.deleteConversation(conv.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Gallery Sidebar List

    private var galleryTab: some View {
        ScrollView {
            VStack(spacing: 1) {
                let categories = templateStore.storeCategories()
                let items = templateStore.storeItems()

                ForEach(categories, id: \.self) { category in
                    let catItems = items.filter { $0.category == category }
                    if !catItems.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.capitalized)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                                .padding(.bottom, 2)

                            ForEach(catItems) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: iconForCategory(category))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)
                                    Text(item.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "weather": return "cloud.sun.fill"
        case "finance": return "chart.line.uptrend.xyaxis"
        case "productivity": return "checkmark.circle"
        case "media": return "music.note"
        case "system": return "cpu"
        case "social": return "person.2"
        case "news": return "newspaper"
        default: return "square.grid.2x2"
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Logo / hero
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(width: 72, height: 72)
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.accentColor.opacity(0.6))
                }

                VStack(spacing: 6) {
                    Text("What would you like to build?")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Describe a widget and I'll create it for your desktop")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                // Quick start suggestions
                VStack(spacing: 6) {
                    quickStartChip("A minimal clock with date")
                    quickStartChip("Weather for my city")
                    quickStartChip("Now playing from Spotify")
                    quickStartChip("Bitcoin price tracker")
                }
                .padding(.top, 4)
            }

            Spacer()

            // Bottom hint
            HStack(spacing: 4) {
                Text("Press")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                Text("\u{2318}K")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .foregroundStyle(.tertiary)
                Text("to toggle this window anytime")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func quickStartChip(_ text: String) -> some View {
        Button {
            viewModel.startNewConversation()
            viewModel.inputText = text
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline Gallery View

private struct InlineGalleryView: View {
    let templateStore: WidgetTemplateStore
    let settingsStore: SettingsStore
    let activeWidgetCounts: [String: Int]
    let onAddWidget: (String, WidgetTheme) -> Void
    let onRemoveWidget: (String) -> Void

    @State private var selectedTheme: WidgetTheme = .obsidian
    @State private var selectedCategory: String = "all"
    @State private var hoveredItem: String?
    @State private var justAdded: String?

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
            galleryHeader
            Divider().opacity(0.5)
            ScrollView {
                galleryGrid
                    .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            selectedTheme = settingsStore.defaultTheme
        }
    }

    private var galleryHeader: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Widget Gallery")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Browse and add pre-built widgets to your desktop.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()

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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    galleryCategoryChip("all", label: "All")
                    ForEach(categories, id: \.self) { cat in
                        galleryCategoryChip(cat, label: cat.capitalized)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 52) // Account for titlebar
        .padding(.bottom, 14)
    }

    private func galleryCategoryChip(_ id: String, label: String) -> some View {
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

    private let gridColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 14)
    ]

    private var galleryGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(items) { item in
                galleryCard(item)
            }
        }
    }

    private static let previewWidth: CGFloat = 240
    private static let previewHeight: CGFloat = 150

    private func galleryCard(_ item: StoreTemplateItem) -> some View {
        let isHovered = hoveredItem == item.id
        let count = activeWidgetCounts[item.name] ?? 0
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

                // Count badge
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
                    // Remove button (visible when instances exist)
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

                    // Add button (always visible)
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

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: ChatConversation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                // Widget indicator dot
                Circle()
                    .fill(isSelected ? Color.white : (conversation.widgetID != nil ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.15)))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(conversation.title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    if let lastMessage = conversation.messages.last {
                        Text(lastMessage.content)
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.6)) : AnyShapeStyle(.tertiary))
                            .lineLimit(1)
                    } else {
                        Text(relativeDate(conversation.updatedAt))
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.6)) : AnyShapeStyle(.tertiary))
                    }
                }

                Spacer(minLength: 0)

                if isHovered && !isSelected {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
