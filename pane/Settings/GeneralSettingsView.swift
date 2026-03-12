import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("General") {
                HStack {
                    Text("Launch at Login")
                    Spacer()
                    Toggle("", isOn: $settingsStore.launchAtLogin)
                        .labelsHidden()
                }
            }

            Section("Keyboard Shortcuts") {
                Picker("Open widgie", selection: $settingsStore.hotkeyPreset) {
                    ForEach(HotkeyPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                shortcutDisplay(label: "Gallery", shortcut: "\u{2318}G")
                shortcutDisplay(label: "New Widget", shortcut: "\u{2318}N")
                shortcutDisplay(label: "Auto Layout", shortcut: "\u{2318}L")
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutDisplay(label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
    }
}
