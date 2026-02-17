import Foundation

enum WidgetStoreError: LocalizedError {
    case invalidImportFormat

    var errorDescription: String? {
        switch self {
        case .invalidImportFormat:
            return "Import file is not a valid pane export."
        }
    }
}

final class WidgetStore {
    private let fileManager: FileManager
    private let widgetsDirectoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let root = Self.resolveRootDirectory(fileManager: fileManager)
        widgetsDirectoryURL = root.appendingPathComponent("widgets", isDirectory: true)

        createDirectoriesIfNeeded()
    }

    func save(_ config: WidgetConfig, isLocked: Bool? = nil) {
        let url = fileURL(for: config.id)

        let metadata: WidgetMetadata
        if let existing = loadEnvelope(at: url) {
            metadata = WidgetMetadata(
                createdAt: existing.metadata.createdAt,
                updatedAt: Date(),
                originalPrompt: config.description,
                position: config.position,
                isLocked: isLocked ?? existing.metadata.isLocked,
                isVisible: existing.metadata.isVisible,
                space: existing.metadata.space
            )
        } else {
            metadata = WidgetMetadata(
                createdAt: Date(),
                updatedAt: Date(),
                originalPrompt: config.description,
                position: config.position,
                isLocked: isLocked ?? false,
                isVisible: true,
                space: "all"
            )
        }

        let envelope = WidgetFileEnvelope(config: config, metadata: metadata)
        writeEnvelope(envelope, to: url)
    }

    func delete(id: UUID) {
        let url = fileURL(for: id)
        try? fileManager.removeItem(at: url)
    }

    func loadAll() -> [WidgetConfig] {
        loadAllEnvelopes().map(\.config)
    }

    func loadAllEnvelopes() -> [WidgetFileEnvelope] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: widgetsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { loadEnvelope(at: $0) ?? loadConfig(at: $0).map(makeEnvelopeFromLegacyConfig) }
            .map { envelope in
                var resolved = envelope
                if resolved.config.position == nil, let persisted = resolved.metadata.position {
                    resolved.config.position = persisted
                }
                return resolved
            }
    }

    func exportAll(to url: URL) throws {
        let envelopes = loadAllEnvelopes()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(envelopes)
        try data.write(to: url, options: .atomic)
    }

    @discardableResult
    func importFrom(url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let imported = try decodeImportPayload(data: data, decoder: decoder)
        guard !imported.isEmpty else { return 0 }

        createDirectoriesIfNeeded()

        var existingIDs = Set(loadAllEnvelopes().map { $0.config.id })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        var importedCount = 0
        for incoming in imported {
            var envelope = incoming

            if existingIDs.contains(envelope.config.id) {
                envelope.config.id = UUID()
            }
            existingIDs.insert(envelope.config.id)

            if envelope.metadata.originalPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                envelope.metadata.originalPrompt = envelope.config.description
            }

            if envelope.metadata.position == nil {
                envelope.metadata.position = envelope.config.position
            }

            envelope.metadata.updatedAt = Date()

            let encoded = try encoder.encode(envelope)
            try encoded.write(to: fileURL(for: envelope.config.id), options: .atomic)
            importedCount += 1
        }

        return importedCount
    }

    private func loadConfig(at url: URL) -> WidgetConfig? {
        if let envelope = loadEnvelope(at: url) {
            return envelope.config
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetConfig.self, from: data)
    }

    private func makeEnvelopeFromLegacyConfig(_ config: WidgetConfig) -> WidgetFileEnvelope {
        WidgetFileEnvelope(
            config: config,
            metadata: WidgetMetadata(
                createdAt: Date(),
                updatedAt: Date(),
                originalPrompt: config.description,
                position: config.position,
                isLocked: false,
                isVisible: true,
                space: "all"
            )
        )
    }

    private func loadEnvelope(at url: URL) -> WidgetFileEnvelope? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetFileEnvelope.self, from: data)
    }

    private func writeEnvelope(_ envelope: WidgetFileEnvelope, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(envelope) else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }

    private func fileURL(for id: UUID) -> URL {
        widgetsDirectoryURL.appendingPathComponent("\(id.uuidString).json")
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: widgetsDirectoryURL, withIntermediateDirectories: true)
    }

    private func decodeImportPayload(data: Data, decoder: JSONDecoder) throws -> [WidgetFileEnvelope] {
        if let envelopes = try? decoder.decode([WidgetFileEnvelope].self, from: data) {
            return envelopes
        }

        if let singleEnvelope = try? decoder.decode(WidgetFileEnvelope.self, from: data) {
            return [singleEnvelope]
        }

        if let configs = try? decoder.decode([WidgetConfig].self, from: data) {
            return configs.map(makeEnvelopeFromLegacyConfig)
        }

        if let singleConfig = try? decoder.decode(WidgetConfig.self, from: data) {
            return [makeEnvelopeFromLegacyConfig(singleConfig)]
        }

        throw WidgetStoreError.invalidImportFormat
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
