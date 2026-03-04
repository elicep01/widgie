import Foundation

enum CommandBarMode: Equatable {
    case input
    case clarifying(questions: [ClarificationQuestion], originalPrompt: String)
    case feedback(widgetID: UUID, originalPrompt: String)

    static func == (lhs: CommandBarMode, rhs: CommandBarMode) -> Bool {
        switch (lhs, rhs) {
        case (.input, .input): return true
        case (.clarifying, .clarifying): return true
        case (.feedback, .feedback): return true
        default: return false
        }
    }
}

struct BuildChecklistItem: Identifiable, Equatable {
    let id: String
    let text: String
    var isDone: Bool
}

@MainActor
final class CommandBarViewModel: ObservableObject {
    @Published var prompt: String = "" {
        didSet {
            if case .input = mode {
                suggestion = suggestionEngine.suggestion(for: prompt)
            }
            if prompt != oldValue, case .input = mode {
                statusMessage = nil
            }
        }
    }

    @Published var suggestion: String?
    @Published var isLoading = false
    @Published var statusMessage: String?
    @Published var isError = false
    @Published var editing = false
    @Published var mode: CommandBarMode = .input
    @Published var clarificationAnswers: [String: [String]] = [:]
    @Published var agentTraceLines: [String] = []
    @Published var buildChecklist: [BuildChecklistItem] = []

    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onClarificationSubmit: ((String, [ClarificationQuestion], [String: [String]]) -> Void)?
    var onFeedbackAccepted: (() -> Void)?
    var onFeedbackTweak: ((UUID, String) -> Void)?

    private let suggestionEngine = SuggestionEngine()
    private var feedbackDismissTask: Task<Void, Never>?

    var placeholder: String {
        editing ? "Update this widget..." : "Describe your widget..."
    }

    func prepare(prefill: String?, editing: Bool) {
        self.editing = editing
        prompt = prefill ?? ""
        statusMessage = nil
        isError = false
        isLoading = false
        mode = .input
        clarificationAnswers = [:]
        agentTraceLines = []
        buildChecklist = []
    }

    func submit() {
        switch mode {
        case .input:
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                setStatus("Enter a widget request first.", isError: true)
                return
            }
            onSubmit?(trimmed)

        case .clarifying:
            submitClarification()

        case .feedback:
            acceptFeedback()
        }
    }

    func showClarification(questions: [ClarificationQuestion], originalPrompt: String) {
        mode = .clarifying(questions: questions, originalPrompt: originalPrompt)
        clarificationAnswers = [:]
        statusMessage = nil
        isError = false
    }

    func toggleOption(questionId: String, option: String, allowsMultiple: Bool) {
        var current = clarificationAnswers[questionId] ?? []
        if allowsMultiple {
            if let idx = current.firstIndex(of: option) {
                current.remove(at: idx)
            } else {
                current.append(option)
            }
            clarificationAnswers[questionId] = current
        } else {
            // Radio: replace selection
            clarificationAnswers[questionId] = [option]
        }
    }

    func isOptionSelected(questionId: String, option: String) -> Bool {
        clarificationAnswers[questionId]?.contains(option) == true
    }

    func submitClarification() {
        guard case .clarifying(let questions, let originalPrompt) = mode else { return }
        onClarificationSubmit?(originalPrompt, questions, clarificationAnswers)
    }

    func resetToInput() {
        feedbackDismissTask?.cancel()
        feedbackDismissTask = nil
        mode = .input
        clarificationAnswers = [:]
        statusMessage = nil
        isError = false
        agentTraceLines = []
        buildChecklist = []
    }

    func showFeedback(widgetID: UUID, originalPrompt: String) {
        feedbackDismissTask?.cancel()
        mode = .feedback(widgetID: widgetID, originalPrompt: originalPrompt)
        isLoading = false
        statusMessage = nil
        isError = false

        // Auto-accept after 6 seconds if the user doesn't interact
        feedbackDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if case .feedback = self.mode {
                self.acceptFeedback()
            }
        }
    }

    func acceptFeedback() {
        feedbackDismissTask?.cancel()
        feedbackDismissTask = nil
        onFeedbackAccepted?()
    }

    func tweakFeedback() {
        feedbackDismissTask?.cancel()
        feedbackDismissTask = nil
        guard case .feedback(let widgetID, let original) = mode else { return }
        onFeedbackTweak?(widgetID, original)
    }

    func setLoading(_ loading: Bool, message: String?) {
        isLoading = loading
        if loading {
            statusMessage = message
            isError = false
        }
    }

    func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        self.isError = isError
    }

    func clearAgentTrace() {
        agentTraceLines = []
    }

    func appendAgentTrace(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        agentTraceLines.append(trimmed)
        if agentTraceLines.count > 16 {
            agentTraceLines.removeFirst(agentTraceLines.count - 16)
        }
    }

    func setBuildChecklist(_ items: [BuildChecklistItem]) {
        buildChecklist = items
    }

    func completeChecklistItem(id: String) {
        guard let index = buildChecklist.firstIndex(where: { $0.id == id }) else { return }
        buildChecklist[index].isDone = true
    }

    func clearBuildChecklist() {
        buildChecklist = []
    }

    func cancel() {
        onCancel?()
    }
}
