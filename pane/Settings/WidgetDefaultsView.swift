import SwiftUI

struct WidgetDefaultsView: View {
    @ObservedObject var settingsStore: SettingsStore
    var onApplyTheme: ((WidgetTheme) -> Void)?

    private let themeColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: themeColumns, spacing: 10) {
                    ForEach(WidgetTheme.allCases.filter { $0 != .custom }, id: \.rawValue) { theme in
                        ThemeCardView(
                            theme: theme,
                            isSelected: settingsStore.defaultTheme == theme
                        ) {
                            settingsStore.defaultTheme = theme
                            onApplyTheme?(theme)
                        }
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    Text("Theme applies to all existing and future widgets.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            } header: {
                Text("Theme")
            }

            Section("Layout") {
                Toggle("Snap Widgets To Grid", isOn: $settingsStore.snapToGrid)

                HStack {
                    Text("Grid Size")
                    Spacer()
                    Stepper(value: $settingsStore.gridSize, in: 8...64, step: 2) {
                        Text("\(Int(settingsStore.gridSize)) pt")
                    }
                    .frame(maxWidth: 170)
                    .disabled(!settingsStore.snapToGrid)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ThemeCardView: View {
    let theme: WidgetTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.previewBackground)

                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(palette.primary.opacity(0.55))
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 3) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(palette.primary)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(palette.accent)
                                    .frame(width: 24, height: 3)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(palette.accent.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 3)
                            .padding(.horizontal, 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isSelected ? palette.accent : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)

                Text(theme.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var palette: ThemePalette { ThemeResolver.palette(for: theme) }
}

extension WidgetTheme {
    var displayName: String {
        switch self {
        case .obsidian:    return "Obsidian"
        case .frosted:     return "Frosted"
        case .neon:        return "Neon"
        case .paper:       return "Paper"
        case .transparent: return "Glass"
        case .pastel:      return "Pastel"
        case .sakura:      return "Sakura"
        case .ocean:       return "Ocean"
        case .sunset:      return "Sunset"
        case .lavender:    return "Lavender"
        case .retro:       return "Retro"
        case .cyberpunk:   return "Cyberpunk"
        case .midnight:    return "Midnight"
        case .roseGold:    return "Rose Gold"
        case .mono:        return "Mono"
        case .custom:      return "Custom"
        }
    }

    var previewBackground: Color {
        switch self {
        case .obsidian:    return Color(hex: "#0D1117")
        case .frosted:     return Color(white: 0.96)
        case .neon:        return Color(hex: "#080A12")
        case .paper:       return Color(hex: "#F4EFE6")
        case .transparent: return Color(hex: "#111827").opacity(0.85)
        case .pastel:      return Color(hex: "#F5F0EC")
        case .sakura:      return Color(hex: "#FFF0F3")
        case .ocean:       return Color(hex: "#0B1A2E")
        case .sunset:      return Color(hex: "#1C1018")
        case .lavender:    return Color(hex: "#F3F0F8")
        case .retro:       return Color(hex: "#F5EDDA")
        case .cyberpunk:   return Color(hex: "#0A0614")
        case .midnight:    return Color(hex: "#0E1529")
        case .roseGold:    return Color(hex: "#F5E6E0")
        case .mono:        return Color(hex: "#FAFAFA")
        case .custom:      return Color(hex: "#0D1117")
        }
    }
}
