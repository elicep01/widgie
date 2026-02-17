import SwiftUI

struct CommandBarView: View {
    @ObservedObject var viewModel: CommandBarViewModel

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.bottom, 2)

            if !viewModel.prompt.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Full Prompt")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(viewModel.prompt)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .frame(minHeight: 56, maxHeight: 148)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }

            if let suggestion = viewModel.suggestion,
               !viewModel.isLoading {
                Text(suggestion)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let statusMessage = viewModel.statusMessage {
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.isError ? "Error" : "Status")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(viewModel.isError ? Color.red.opacity(0.9) : Color.secondary)

                    ScrollView(.vertical, showsIndicators: true) {
                        Text(statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(viewModel.isError ? Color.red : Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .frame(minHeight: 48, maxHeight: 136)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill((viewModel.isError ? Color.red : Color.black).opacity(viewModel.isError ? 0.11 : 0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke((viewModel.isError ? Color.red : Color.white).opacity(viewModel.isError ? 0.35 : 0.08), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.vertical, 16)
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
