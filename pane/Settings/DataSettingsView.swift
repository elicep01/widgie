import SwiftUI

struct DataSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            TextField("Default Location", text: $settingsStore.defaultLocation)
                .textFieldStyle(.roundedBorder)
                .withoutWritingTools()

            HStack {
                Text("Temperature Unit")
                Spacer()
                Picker("", selection: $settingsStore.useFahrenheit) {
                    Text("F").tag(true)
                    Text("C").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
        .formStyle(.grouped)
    }
}
