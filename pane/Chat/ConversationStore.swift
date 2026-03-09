import Foundation

final class ConversationStore {
    private let directory: URL
    private var conversations: [UUID: ChatConversation] = [:]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("widgie/conversations", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        loadAll()
    }

    func all() -> [ChatConversation] {
        Array(conversations.values).sorted { $0.updatedAt > $1.updatedAt }
    }

    func conversation(for id: UUID) -> ChatConversation? {
        conversations[id]
    }

    func conversationForWidget(_ widgetID: UUID) -> ChatConversation? {
        conversations.values.first { $0.widgetID == widgetID }
    }

    @discardableResult
    func create(title: String = "New Widget", widgetID: UUID? = nil) -> ChatConversation {
        var conv = ChatConversation(title: title, widgetID: widgetID)
        // If there's already a conversation for this widget, reuse it
        if let widgetID, let existing = conversationForWidget(widgetID) {
            return existing
        }
        conversations[conv.id] = conv
        save(conv)
        return conv
    }

    func update(_ conversation: ChatConversation) {
        conversations[conversation.id] = conversation
        save(conversation)
    }

    func linkWidget(_ widgetID: UUID, to conversationID: UUID) {
        guard var conv = conversations[conversationID] else { return }
        conv.widgetID = widgetID
        update(conv)
    }

    func delete(_ id: UUID) {
        conversations.removeValue(forKey: id)
        let file = directory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: file)
    }

    private func save(_ conversation: ChatConversation) {
        let file = directory.appendingPathComponent("\(conversation.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(conversation) else { return }
        try? data.write(to: file, options: .atomic)
    }

    private func loadAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let conv = try? decoder.decode(ChatConversation.self, from: data) else {
                continue
            }
            conversations[conv.id] = conv
        }
    }
}
