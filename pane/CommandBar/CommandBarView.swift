import SwiftUI

struct CommandBarView: View {
    @ObservedObject var viewModel: CommandBarViewModel

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField(viewModel.placeholder, text: $viewModel.prompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .regular))
                    .lineLimit(1)
                    .disabled(viewModel.isLoading)
                    .focused($isInputFocused)
                    .onSubmit {
                        viewModel.submit()
                    }

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if viewModel.prompt.count > 48 && !viewModel.isLoading {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Prompt")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(viewModel.prompt)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 18)
                }
            }

            if let suggestion = viewModel.suggestion,
               !viewModel.isLoading {
                Text(suggestion)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.tertiary)
            }

            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(viewModel.isError ? Color.red : Color.secondary)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
        .onAppear {
            DispatchQueue.main.async {
                isInputFocused = true
            }
        }
        .onExitCommand {
            viewModel.cancel()
        }
    }
}
