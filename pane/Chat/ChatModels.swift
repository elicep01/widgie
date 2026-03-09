import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date

    init(role: ChatRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

struct ChatConversation: Codable, Identifiable {
    let id: UUID
    var widgetID: UUID?
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date

    init(title: String = "New Widget", widgetID: UUID? = nil) {
        self.id = UUID()
        self.widgetID = widgetID
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func append(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
    }

    mutating func appendUser(_ text: String) {
        append(ChatMessage(role: .user, content: text))
    }

    mutating func appendAssistant(_ text: String) {
        append(ChatMessage(role: .assistant, content: text))
    }

    mutating func appendSystem(_ text: String) {
        append(ChatMessage(role: .system, content: text))
    }
}
