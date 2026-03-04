import Foundation
import Security

final class KeychainStore {
    private let service = "widgie"
    private let legacyServices = ["pane", "WidgetForge"]

    func set(_ value: String, for key: String) {
        if value.isEmpty {
            delete(key: key, service: service)
            for legacyService in legacyServices {
                delete(key: key, service: legacyService)
            }
            return
        }

        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func string(for key: String) -> String? {
        if let value = string(for: key, service: service) {
            return value
        }
        for legacyService in legacyServices {
            if let value = string(for: key, service: legacyService) {
                return value
            }
        }
        return nil
    }

    private func string(for key: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(key: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
