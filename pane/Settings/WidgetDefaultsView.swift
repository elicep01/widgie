import SwiftUI

struct WidgetDefaultsView: View {
    @ObservedObject var settingsStore: SettingsStore
    var onApplyTheme: ((WidgetTheme) -> Void)?

    private let themeColumns = [
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

private struct ThemeCardView: View {
    let theme: WidgetTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Mini widget preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(themeBackground)

                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(themePrimary.opacity(0.55))
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 3) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(themePrimary)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(themeAccent)
                                    .frame(width: 24, height: 3)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(themeAccent.opacity(0.6))
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
                            isSelected ? themeAccent : Color.primary.opacity(0.08),
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

    private var themeBackground: Color {
        switch theme {
        case .obsidian: return Color(hex: "#0D1117")
        case .frosted:  return Color(white: 0.96)
        case .neon:     return Color(hex: "#080A12")
        case .paper:    return Color(hex: "#F4EFE6")
        case .transparent: return Color(hex: "#111827").opacity(0.85)
        case .custom:   return Color(hex: "#0D1117")
        }
    }

    private var themePrimary: Color {
        switch theme {
        case .obsidian: return Color(hex: "#E6EDF3")
        case .frosted:  return Color(hex: "#1A1A1A")
        case .neon:     return Color(hex: "#F3F7FF")
        case .paper:    return Color(hex: "#2C261F")
        case .transparent: return .white
        case .custom:   return Color(hex: "#E6EDF3")
        }
    }

    private var themeAccent: Color {
        switch theme {
        case .obsidian: return Color(hex: "#58A6FF")
        case .frosted:  return Color(hex: "#0066CC")
        case .neon:     return Color(hex: "#18F0FF")
        case .paper:    return Color(hex: "#7A5020")
        case .transparent: return Color(hex: "#8BC4FF")
        case .custom:   return Color(hex: "#58A6FF")
        }
    }
}

extension WidgetTheme {
    var displayName: String {
        switch self {
        case .obsidian:    return "Obsidian"
        case .frosted:     return "Frosted"
        case .neon:        return "Neon"
        case .paper:       return "Paper"
        case .transparent: return "Glass"
        case .custom:      return "Custom"
        }
    }
}
