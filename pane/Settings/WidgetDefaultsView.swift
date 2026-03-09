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
                    ForEach(WidgetTheme.activeThemes, id: \.rawValue) { theme in
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
        case .obsidian:    return "Dark"
        case .frosted:     return "Light"
        case .transparent: return "Glass"
        case .mono:        return "Mono"
        case .paper:       return "Paper"
        default:           return canonical.displayName
        }
    }

    var previewBackground: Color {
        switch self {
        case .obsidian:    return Color(hex: "#1C1C1E")
        case .frosted:     return Color(white: 0.97)
        case .transparent: return Color(hex: "#1C1C1E").opacity(0.75)
        case .mono:        return Color(hex: "#FFFFFF")
        case .paper:       return Color(hex: "#F5F0E8")
        default:           return canonical.previewBackground
        }
    }
}
