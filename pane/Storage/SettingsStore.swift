import Carbon.HIToolbox
import Combine
import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .claude:
            return "Claude"
        }
    }
}

enum HotkeyPreset: String, Codable, CaseIterable, Identifiable {
    case cmdShiftW

    var id: String { rawValue }

    var displayName: String {
        "Cmd+Shift+W"
    }

    var registration: HotkeyRegistration {
        HotkeyRegistration(
            keyCode: UInt32(kVK_ANSI_W),
            modifiers: UInt32(cmdKey | shiftKey),
            displayName: displayName
        )
    }
}

extension Notification.Name {
    static let settingsDidChange = Notification.Name("widgie.SettingsDidChange")
}

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var selectedProvider: AIProvider {
        didSet {
            defaults.set(selectedProvider.rawValue, forKey: Keys.provider)
            notifyChange()
        }
    }

    @Published var hotkeyPreset: HotkeyPreset {
        didSet {
            defaults.set(hotkeyPreset.rawValue, forKey: Keys.hotkey)
            notifyChange()
        }
    }

    @Published var defaultTheme: WidgetTheme {
        didSet {
            defaults.set(defaultTheme.rawValue, forKey: Keys.defaultTheme)
            notifyChange()
        }
    }

    @Published var openAIModel: String {
        didSet {
            defaults.set(openAIModel, forKey: Keys.openAIModel)
            notifyChange()
        }
    }

    @Published var claudeModel: String {
        didSet {
            defaults.set(claudeModel, forKey: Keys.claudeModel)
            notifyChange()
        }
    }

    @Published var openAIAPIKey: String {
        didSet {
            keychainStore.set(openAIAPIKey, for: Keys.openAIAPIKey)
            _ = ensureUsableProviderSelection()
            notifyChange()
        }
    }

    @Published var claudeAPIKey: String {
        didSet {
            keychainStore.set(claudeAPIKey, for: Keys.claudeAPIKey)
            _ = ensureUsableProviderSelection()
            notifyChange()
        }
    }

    @Published var defaultLocation: String {
        didSet {
            defaults.set(defaultLocation, forKey: Keys.defaultLocation)
            notifyChange()
        }
    }

    @Published var useFahrenheit: Bool {
        didSet {
            defaults.set(useFahrenheit, forKey: Keys.useFahrenheit)
            notifyChange()
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            notifyChange()
        }
    }

    @Published var snapToGrid: Bool {
        didSet {
            defaults.set(snapToGrid, forKey: Keys.snapToGrid)
            notifyChange()
        }
    }

    @Published var gridSize: Double {
        didSet {
            defaults.set(gridSize, forKey: Keys.gridSize)
            notifyChange()
        }
    }

    @Published var enableWebDiscovery: Bool {
        didSet {
            defaults.set(enableWebDiscovery, forKey: Keys.enableWebDiscovery)
            notifyChange()
        }
    }

    @Published var didCompleteOnboarding: Bool {
        didSet {
            defaults.set(didCompleteOnboarding, forKey: Keys.didCompleteOnboarding)
            notifyChange()
        }
    }

    private let defaults: UserDefaults
    private let keychainStore: KeychainStore

    init(defaults: UserDefaults = .standard, keychainStore: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychainStore = keychainStore

        selectedProvider = AIProvider(rawValue: defaults.string(forKey: Keys.provider) ?? "") ?? .openAI
        hotkeyPreset = HotkeyPreset(rawValue: defaults.string(forKey: Keys.hotkey) ?? "") ?? .cmdShiftW
        defaultTheme = WidgetTheme(rawValue: defaults.string(forKey: Keys.defaultTheme) ?? "") ?? .obsidian
        openAIModel = defaults.string(forKey: Keys.openAIModel) ?? "o3-mini"
        claudeModel = defaults.string(forKey: Keys.claudeModel) ?? "claude-opus-4-5"
        openAIAPIKey = keychainStore.string(for: Keys.openAIAPIKey) ?? ""
        claudeAPIKey = keychainStore.string(for: Keys.claudeAPIKey) ?? ""
        defaultLocation = defaults.string(forKey: Keys.defaultLocation) ?? "Madison, WI"
        useFahrenheit = defaults.object(forKey: Keys.useFahrenheit) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? true
        snapToGrid = defaults.object(forKey: Keys.snapToGrid) as? Bool ?? true
        gridSize = defaults.object(forKey: Keys.gridSize) as? Double ?? 20
        enableWebDiscovery = defaults.object(forKey: Keys.enableWebDiscovery) as? Bool ?? true
        didCompleteOnboarding = defaults.object(forKey: Keys.didCompleteOnboarding) as? Bool ?? false

        _ = ensureUsableProviderSelection()
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .settingsDidChange, object: self)
    }

    var hasAnyRemoteAPIKey: Bool {
        !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func hasAPIKey(for provider: AIProvider) -> Bool {
        switch provider {
        case .openAI:
            return !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .claude:
            return !claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @discardableResult
    func ensureUsableProviderSelection() -> Bool {
        if hasAPIKey(for: selectedProvider) {
            return true
        }

        if hasAPIKey(for: .openAI) {
            selectedProvider = .openAI
            return true
        }

        if hasAPIKey(for: .claude) {
            selectedProvider = .claude
            return true
        }

        return false
    }

    var shouldShowOnboarding: Bool {
        !didCompleteOnboarding
    }
}

private enum Keys {
    static let provider = "settings.provider"
    static let hotkey = "settings.hotkey"
    static let defaultTheme = "settings.defaultTheme"
    static let openAIModel = "settings.openAI.model"
    static let claudeModel = "settings.claude.model"
    static let openAIAPIKey = "settings.openAI.apiKey"
    static let claudeAPIKey = "settings.claude.apiKey"
    static let defaultLocation = "settings.data.defaultLocation"
    static let useFahrenheit = "settings.data.useFahrenheit"
    static let launchAtLogin = "settings.general.launchAtLogin"
    static let snapToGrid = "settings.widgets.snapToGrid"
    static let gridSize = "settings.widgets.gridSize"
    static let enableWebDiscovery = "settings.ai.enableWebDiscovery"
    static let didCompleteOnboarding = "settings.general.didCompleteOnboarding"
}
