import SwiftUI

struct APISettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    @StateObject private var openAIModelCatalog = OpenAIModelCatalog()
    private let providers: [AIProvider] = [.openAI, .claude]

    private let claudeModels: [(id: String, label: String)] = [
        ("claude-opus-4-5",            "Claude Opus 4.5  ★ Best reasoning"),
        ("claude-sonnet-4-5",          "Claude Sonnet 4.5  — Balanced"),
        ("claude-haiku-4-5-20251001",  "Claude Haiku 4.5  — Fast / cheap"),
        ("claude-3-5-sonnet-latest",   "Claude 3.5 Sonnet"),
        ("claude-3-5-haiku-latest",    "Claude 3.5 Haiku"),
    ]

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
                    .withoutWritingTools()

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
                SecureField("API Key", text: $settingsStore.claudeAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .withoutWritingTools()

                Picker("Model", selection: $settingsStore.claudeModel) {
                    ForEach(claudeModels, id: \.id) { entry in
                        Text(entry.label).tag(entry.id)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Agent") {
                Toggle("Enable web discovery", isOn: $settingsStore.enableWebDiscovery)
                Text("Allows agent planning to resolve unknown sources from DuckDuckGo and Wikipedia with attribution in Agent Trace.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
