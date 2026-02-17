import SwiftUI

struct APISettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    @StateObject private var openAIModelCatalog = OpenAIModelCatalog()
    private let providers: [AIProvider] = [.openAI, .claude]

    var body: some View {
        Form {
            Picker("Provider", selection: $settingsStore.selectedProvider) {
                ForEach(providers) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }

            Section("OpenAI") {
                SecureField("API Key", text: $settingsStore.openAIAPIKey)
                    .textFieldStyle(.roundedBorder)

                if settingsStore.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Enter an OpenAI API key to load available models.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    if openAIModelCatalog.models.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading models...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 10) {
                            Picker("Model", selection: $settingsStore.openAIModel) {
                                ForEach(openAIModelCatalog.models, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)

                            if openAIModelCatalog.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Button("Refresh") {
                                Task {
                                    await loadOpenAIModels(force: true)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let errorMessage = openAIModelCatalog.errorMessage {
                        Text("Model list fallback is shown. \(errorMessage)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Claude") {
                TextField("Model", text: $settingsStore.claudeModel)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $settingsStore.claudeAPIKey)
                    .textFieldStyle(.roundedBorder)
            }

            Text("API keys are stored in Keychain and used only for widget generation.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .task {
            await loadOpenAIModels(force: false)
        }
        .onChange(of: settingsStore.openAIAPIKey) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if newValue != trimmed {
                settingsStore.openAIAPIKey = trimmed
                return
            }

            Task {
                await loadOpenAIModels(force: true)

                if !settingsStore.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   settingsStore.selectedProvider != .openAI {
                    settingsStore.selectedProvider = .openAI
                }
            }
        }
        .onChange(of: settingsStore.claudeAPIKey) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if newValue != trimmed {
                settingsStore.claudeAPIKey = trimmed
                return
            }

            if !trimmed.isEmpty,
               settingsStore.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               settingsStore.selectedProvider != .claude {
                settingsStore.selectedProvider = .claude
            }
        }
    }

    private func loadOpenAIModels(force: Bool) async {
        await openAIModelCatalog.refreshModels(apiKey: settingsStore.openAIAPIKey, force: force)

        guard !openAIModelCatalog.models.isEmpty else {
            return
        }

        if !openAIModelCatalog.models.contains(settingsStore.openAIModel) {
            settingsStore.openAIModel = openAIModelCatalog.models[0]
        }
    }
}
