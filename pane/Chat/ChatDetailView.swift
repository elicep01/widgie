import SwiftUI

struct ChatDetailView: View {
    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Conversation start header
                        if let conv = viewModel.activeConversationID.flatMap({ viewModel.conversationStore.conversation(for: $0) }) {
                            conversationHeader(conv)
                        }

                        LazyVStack(spacing: 2) {
                            ForEach(viewModel.activeMessages) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            if viewModel.isProcessing {
                                thinkingRow
                                    .id("processing")
                                    .transition(.opacity)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .scrollContentBackground(.hidden)
                .onChange(of: viewModel.activeMessages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.isProcessing) { _, _ in
                    scrollToBottom(proxy)
                }
                .onAppear {
                    scrollToBottom(proxy)
                }
            }

            // Trace bar
            if !viewModel.traceLines.isEmpty {
                traceBar
            }

            // Input composer
            composerBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
    }

    // MARK: - Conversation Header

    private func conversationHeader(_ conv: ChatConversation) -> some View {
        VStack(spacing: 6) {
            Spacer()
                .frame(height: 60)

            if conv.messages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.accentColor.opacity(0.4))

                    Text("What should this widget do?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Thinking Row

    private var thinkingRow: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ThinkingDotsView()
                    Text(viewModel.processingStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
    }

    // MARK: - Trace Bar

    private var traceBar: some View {
        HStack(spacing: 0) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 8))
                .foregroundStyle(.quaternary)
                .padding(.trailing, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(viewModel.traceLines.suffix(4).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.quaternary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.015))
    }

    // MARK: - Composer Bar

    private var composerBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            HStack(alignment: .bottom, spacing: 0) {
                TextField("Message...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !NSEvent.modifierFlags.contains(.shift) {
                            viewModel.submit()
                        }
                    }
                    .disabled(viewModel.isProcessing)
                    .padding(.leading, 14)
                    .padding(.vertical, 10)

                Button {
                    viewModel.submit()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(canSubmit ? AnyShapeStyle(.white) : AnyShapeStyle(.quaternary))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(canSubmit ? Color.accentColor : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .padding(.trailing, 8)
                .padding(.bottom, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var canSubmit: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isProcessing
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.2)) {
                if viewModel.isProcessing {
                    proxy.scrollTo("processing", anchor: .bottom)
                } else if let last = viewModel.activeMessages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 80)
                userBubble
            } else {
                assistantRow
                Spacer(minLength: 80)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 6)
    }

    // User messages: right-aligned bubble
    private var userBubble: some View {
        Text(message.content)
            .font(.system(size: 13))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
    }

    // Assistant/system messages: left-aligned with avatar
    private var assistantRow: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(message.role == .system ? Color.orange.opacity(0.12) : Color.accentColor.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: message.role == .system ? "info" : "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(message.role == .system ? Color.orange : Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
        }
    }
}

// MARK: - Thinking Dots Animation

private struct ThinkingDotsView: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.accentColor.opacity(phase == i ? 0.8 : 0.2))
                    .frame(width: 5, height: 5)
                    .animation(.easeInOut(duration: 0.4).delay(Double(i) * 0.15), value: phase)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}
