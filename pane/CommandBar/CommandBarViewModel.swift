import Foundation

@MainActor
final class CommandBarViewModel: ObservableObject {
    @Published var prompt: String = "" {
        didSet {
            suggestion = suggestionEngine.suggestion(for: prompt)
            if prompt != oldValue {
                statusMessage = nil
            }
        }
    }

    @Published var suggestion: String?
    @Published var isLoading = false
    @Published var statusMessage: String?
    @Published var isError = false
    @Published var editing = false

    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private let suggestionEngine = SuggestionEngine()

    var placeholder: String {
        editing ? "Update this widget..." : "Describe your widget..."
    }

    func prepare(prefill: String?, editing: Bool) {
        self.editing = editing
        prompt = prefill ?? ""
        statusMessage = nil
        isError = false
        isLoading = false
    }

    func submit() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setStatus("Enter a widget request first.", isError: true)
            return
        }

        onSubmit?(trimmed)
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

    func cancel() {
        onCancel?()
    }
}
