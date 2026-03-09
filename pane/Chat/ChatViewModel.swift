import Foundation
import SwiftUI

enum ChatSidebarTab: Equatable {
    case myWidgets
    case gallery
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var conversations: [ChatConversation] = []
    @Published var activeConversationID: UUID?
    @Published var activeMessages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isProcessing: Bool = false
    @Published var processingStatus: String = ""
    @Published var sidebarTab: ChatSidebarTab = .myWidgets
    @Published var traceLines: [String] = []
    @Published var pendingClarification: PendingClarification?
    @Published var activeWidgetCounts: [String: Int] = [:]  // template name → count on desktop

    let conversationStore: ConversationStore

    /// Callbacks wired by AppCoordinator
    var onSubmitPrompt: ((String, UUID?) -> Void)?  // (prompt, existingWidgetID?)
    var onAnswerClarification: ((String) -> Void)?   // user's answer to clarification
    var onDeleteWidget: ((UUID) -> Void)?
    var onRemoveWidgetByName: ((String) -> Void)?    // remove one instance by name

    /// Pending clarification state — when the AI asks questions before building
    struct PendingClarification {
        let plan: AgentBuildPlan
        let questions: [ClarificationQuestion]
        let conversation: AgentConversation
    }

    init(conversationStore: ConversationStore) {
        self.conversationStore = conversationStore
        refreshConversations()
    }

    func refreshConversations() {
        conversations = conversationStore.all()
        // Refresh active messages if viewing a conversation
        if let id = activeConversationID,
           let conv = conversationStore.conversation(for: id) {
            activeMessages = conv.messages
        }
    }

    func startNewConversation() {
        let conv = conversationStore.create(title: "New Widget")
        refreshConversations()
        selectConversation(conv.id)
    }

    func selectConversation(_ id: UUID) {
        activeConversationID = id
        if let conv = conversationStore.conversation(for: id) {
            activeMessages = conv.messages
        }
        inputText = ""
        traceLines = []
    }

    func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        inputText = ""
        traceLines = []

        // Append user message
        if let id = activeConversationID {
            appendUserMessage(text, to: id)
        } else {
            // Create a new conversation
            let conv = conversationStore.create(title: deriveTitle(from: text))
            activeConversationID = conv.id
            refreshConversations()
            appendUserMessage(text, to: conv.id)
        }

        // If there's a pending clarification, this is the user's answer
        if pendingClarification != nil {
            isProcessing = true
            processingStatus = "Processing your answer..."
            pendingClarification = nil
            onAnswerClarification?(text)
            return
        }

        // Find linked widget ID if editing
        let widgetID = activeConversationID.flatMap { conversationStore.conversation(for: $0)?.widgetID }

        isProcessing = true
        processingStatus = "Thinking..."
        onSubmitPrompt?(text, widgetID)
    }

    func appendUserMessage(_ text: String, to conversationID: UUID) {
        guard var conv = conversationStore.conversation(for: conversationID) else { return }
        conv.appendUser(text)
        conversationStore.update(conv)
        activeMessages = conv.messages
        refreshConversations()
    }

    func appendAssistantMessage(_ text: String) {
        guard let id = activeConversationID,
              var conv = conversationStore.conversation(for: id) else { return }
        conv.appendAssistant(text)
        conversationStore.update(conv)
        activeMessages = conv.messages
        refreshConversations()
    }

    func appendSystemMessage(_ text: String) {
        guard let id = activeConversationID,
              var conv = conversationStore.conversation(for: id) else { return }
        conv.appendSystem(text)
        conversationStore.update(conv)
        activeMessages = conv.messages
        refreshConversations()
    }

    func appendTrace(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        traceLines.append(trimmed)
        if traceLines.count > 20 {
            traceLines.removeFirst(traceLines.count - 20)
        }
    }

    func clearTrace() {
        traceLines = []
    }

    func setProcessing(_ processing: Bool, status: String = "") {
        isProcessing = processing
        processingStatus = status
    }

    func linkWidgetToActiveConversation(_ widgetID: UUID) {
        guard let id = activeConversationID else { return }
        conversationStore.linkWidget(widgetID, to: id)

        // Update conversation title to widget name if still default
        if var conv = conversationStore.conversation(for: id), conv.title == "New Widget" {
            // Title will be updated when we get the widget config
            conversationStore.update(conv)
        }
        refreshConversations()
    }

    func updateConversationTitle(_ title: String) {
        guard let id = activeConversationID,
              var conv = conversationStore.conversation(for: id) else { return }
        conv.title = title
        conversationStore.update(conv)
        refreshConversations()
    }

    func deleteConversation(_ id: UUID) {
        // Also delete the linked widget
        if let conv = conversationStore.conversation(for: id), let widgetID = conv.widgetID {
            onDeleteWidget?(widgetID)
        }
        conversationStore.delete(id)
        if activeConversationID == id {
            activeConversationID = nil
            activeMessages = []
        }
        refreshConversations()
    }

    private func deriveTitle(from prompt: String) -> String {
        let words = prompt.split(separator: " ").prefix(5).joined(separator: " ")
        if words.count > 40 {
            return String(words.prefix(40)) + "..."
        }
        return words.isEmpty ? "New Widget" : words
    }
}
