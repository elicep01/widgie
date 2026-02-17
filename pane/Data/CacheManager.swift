import Foundation

actor CacheManager {
    private struct CacheEnvelope: Codable {
        var expiresAt: Date
        var payload: Data
    }

    private let fileManager: FileManager
    private let cacheDirectoryURL: URL
    private var memory: [String: CacheEnvelope] = [:]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let root = Self.resolveRootDirectory(fileManager: fileManager)
        cacheDirectoryURL = root.appendingPathComponent("data_cache", isDirectory: true)

        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
    }

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let now = Date()

        if let envelope = memory[key] {
            guard envelope.expiresAt > now else {
                memory[key] = nil
                deleteDiskCache(for: key)
                return nil
            }
            return try? JSONDecoder().decode(T.self, from: envelope.payload)
        }

        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: data) else {
            return nil
        }

        guard envelope.expiresAt > now else {
            try? fileManager.removeItem(at: url)
            return nil
        }

        memory[key] = envelope
        return try? JSONDecoder().decode(T.self, from: envelope.payload)
    }

    func store<T: Encodable>(_ value: T, key: String, ttl: TimeInterval) {
        guard let payload = try? JSONEncoder().encode(value) else {
            return
        }

        let envelope = CacheEnvelope(
            expiresAt: Date().addingTimeInterval(max(1, ttl)),
            payload: payload
        )

        memory[key] = envelope
        guard let data = try? JSONEncoder().encode(envelope) else {
            return
        }
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    private func fileURL(for key: String) -> URL {
        let safe = key
            .replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
            .prefix(96)
        return cacheDirectoryURL.appendingPathComponent("\(safe).json")
    }

    private func deleteDiskCache(for key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    private static func resolveRootDirectory(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let paneRoot = appSupport.appendingPathComponent("pane", isDirectory: true)
        let legacyRoot = appSupport.appendingPathComponent("WidgetForge", isDirectory: true)

        let paneExists = fileManager.fileExists(atPath: paneRoot.path)
        let legacyExists = fileManager.fileExists(atPath: legacyRoot.path)

        if paneExists {
            return paneRoot
        }

        if legacyExists {
            do {
                try fileManager.moveItem(at: legacyRoot, to: paneRoot)
                return paneRoot
            } catch {
                return legacyRoot
            }
        }

        return paneRoot
    }
}
