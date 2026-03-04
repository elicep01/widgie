import Foundation

enum WidgetStoreError: LocalizedError {
    case invalidImportFormat

    var errorDescription: String? {
        switch self {
        case .invalidImportFormat:
            return "Import file is not a valid widgie export."
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

        let entries: [(url: URL, envelope: WidgetFileEnvelope)] = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { fileURL in
                if let envelope = loadEnvelope(at: fileURL) {
                    return (fileURL, envelope)
                }
                if let config = loadConfig(at: fileURL) {
                    return (fileURL, makeEnvelopeFromLegacyConfig(config))
                }
                return nil
            }

        return entries.map { entry in
            var resolved = entry.envelope
            let repaired = repairLegacyLayoutWrappers(&resolved.config)
            if resolved.config.position == nil, let persisted = resolved.metadata.position {
                resolved.config.position = persisted
            }
            if repaired {
                writeEnvelope(resolved, to: entry.url)
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

    @discardableResult
    private func repairLegacyLayoutWrappers(_ config: inout WidgetConfig) -> Bool {
        repairLegacyLayoutWrappers(component: config.content)
    }

    @discardableResult
    private func repairLegacyLayoutWrappers(component: ComponentConfig) -> Bool {
        var changed = false

        if component.type == .icon,
           let children = component.children,
           !children.isEmpty {
            component.type = .hstack
            if component.alignment == nil {
                component.alignment = "center"
            }
            if component.spacing == nil {
                component.spacing = 12
            }
            changed = true
        }

        if let child = component.child {
            changed = repairLegacyLayoutWrappers(component: child) || changed
        }

        if let children = component.children {
            for child in children {
                changed = repairLegacyLayoutWrappers(component: child) || changed
            }
        }

        return changed
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
        let currentRoot = appSupport.appendingPathComponent("widgie", isDirectory: true)
        let legacyPaneRoot = appSupport.appendingPathComponent("pane", isDirectory: true)
        let legacyWidgetForgeRoot = appSupport.appendingPathComponent("WidgetForge", isDirectory: true)

        if fileManager.fileExists(atPath: currentRoot.path) {
            return currentRoot
        }

        if fileManager.fileExists(atPath: legacyPaneRoot.path) {
            do {
                try fileManager.moveItem(at: legacyPaneRoot, to: currentRoot)
                return currentRoot
            } catch {
                return legacyPaneRoot
            }
        }

        if fileManager.fileExists(atPath: legacyWidgetForgeRoot.path) {
            do {
                try fileManager.moveItem(at: legacyWidgetForgeRoot, to: currentRoot)
                return currentRoot
            } catch {
                return legacyWidgetForgeRoot
            }
        }

        return currentRoot
    }
}
