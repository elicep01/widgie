import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Picker("Global Hotkey", selection: $settingsStore.hotkeyPreset) {
                ForEach(HotkeyPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            HStack {
                Text("Launch At Login")
                Spacer()
                Toggle("", isOn: $settingsStore.launchAtLogin)
                    .labelsHidden()
            }

            HStack {
                Text("Current Trigger")
                Spacer()
                Text(settingsStore.hotkeyPreset.displayName)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
