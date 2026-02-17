import SwiftUI

struct WidgetDefaultsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Picker("Default Theme", selection: $settingsStore.defaultTheme) {
                ForEach(WidgetTheme.allCases, id: \.rawValue) { theme in
                    Text(theme.rawValue.capitalized).tag(theme)
                }
            }

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

            HStack {
                Text("Theme Used For")
                Spacer()
                Text("AI-generated widgets without explicit theme")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
