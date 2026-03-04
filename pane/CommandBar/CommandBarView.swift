import SwiftUI

struct CommandBarView: View {
    @ObservedObject var viewModel: CommandBarViewModel

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Input row — always visible
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)

                if case .clarifying(_, let original) = viewModel.mode {
                    // Show original prompt dimmed while clarifying
                    Text(original)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField(viewModel.placeholder, text: $viewModel.prompt)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .regular))
                        .lineLimit(1)
                        .withoutWritingTools()
                        .disabled(viewModel.isLoading)
                        .focused($isInputFocused)
                        .onSubmit {
                            viewModel.submit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.bottom, 2)

            // Mode-dependent content area
            switch viewModel.mode {
            case .input:
                inputModeContent

            case .clarifying(let questions, _):
                ClarificationQuestionsView(
                    questions: questions,
                    answers: viewModel.clarificationAnswers,
                    onToggle: { qId, option, multiple in
                        viewModel.toggleOption(questionId: qId, option: option, allowsMultiple: multiple)
                    },
                    onBack: {
                        viewModel.resetToInput()
                    },
                    onBuild: {
                        viewModel.submitClarification()
                    }
                )

            case .feedback(_, let originalPrompt):
                FeedbackView(
                    originalPrompt: originalPrompt,
                    onAccept: { viewModel.acceptFeedback() },
                    onTweak: { viewModel.tweakFeedback() }
                )
            }

            if case .feedback = viewModel.mode {
                EmptyView()
            } else if !viewModel.buildChecklist.isEmpty {
                BuildChecklistView(items: viewModel.buildChecklist)
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

    @ViewBuilder
    private var inputModeContent: some View {
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

        if !viewModel.agentTraceLines.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Agent Trace")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if let confidence = latestConfidence(from: viewModel.agentTraceLines) {
                        Text("Confidence \(Int((confidence * 100).rounded()))%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(confidenceColor(confidence))
                        ProgressView(value: confidence)
                            .progressViewStyle(.linear)
                            .tint(confidenceColor(confidence))
                            .frame(width: 80)
                    }
                }

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(viewModel.agentTraceLines.enumerated()), id: \.offset) { _, line in
                            Text("• \(line)")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(colorForTraceLine(line))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(minHeight: 54, maxHeight: 148)
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
    }

    private func latestConfidence(from lines: [String]) -> Double? {
        for line in lines.reversed() {
            let lower = line.lowercased()
            guard lower.contains("confidence") else { continue }
            guard let match = lower.range(of: #"[0-9]+(?:\.[0-9]+)?"#, options: .regularExpression) else { continue }
            guard let value = Double(lower[match]) else { continue }
            if value > 1 {
                return min(1.0, max(0.0, value / 100.0))
            }
            return min(1.0, max(0.0, value))
        }
        return nil
    }

    private func colorForTraceLine(_ line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("issue") || lower.contains("warning") || lower.contains("unsupported") {
            return .orange
        }
        if lower.contains("done") || lower.contains("final confidence") || lower.contains("completed") {
            return .green
        }
        if lower.contains("phase:") {
            return .cyan
        }
        return .secondary
    }

    private func confidenceColor(_ value: Double) -> Color {
        if value >= 0.85 { return .green }
        if value >= 0.65 { return .yellow }
        return .orange
    }
}

private struct BuildChecklistView: View {
    let items: [BuildChecklistItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Build Checklist")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(item.isDone ? Color.green : Color.secondary.opacity(0.8))
                                .padding(.top, 1)
                            Text(item.text)
                                .font(.system(size: 11, weight: .regular))
                                .strikethrough(item.isDone, color: .green)
                                .foregroundStyle(item.isDone ? Color.secondary : Color.primary.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(minHeight: 64, maxHeight: 170)
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
}

// MARK: - Feedback UI

private struct FeedbackView: View {
    let originalPrompt: String
    let onAccept: () -> Void
    let onTweak: () -> Void

    @State private var countdown: Double = 1.0  // 1.0 → 0.0 over 6 seconds

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
                Text("Widget created!")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                // Countdown bar
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: geo.size.width)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: geo.size.width * countdown)
                        .animation(.linear(duration: 6), value: countdown)
                }
                .frame(width: 48, height: 4)
            }

            Text(originalPrompt)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button(action: onTweak) {
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11))
                        Text("Tweak it")
                            .font(.system(size: 12, weight: .regular))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.09))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onAccept) {
                    HStack(spacing: 5) {
                        Text("Looks right")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.8))
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            countdown = 0.0
        }
    }
}

// MARK: - Clarification Questions UI

private struct ClarificationQuestionsView: View {
    let questions: [ClarificationQuestion]
    let answers: [String: [String]]
    let onToggle: (String, String, Bool) -> Void
    let onBack: () -> Void
    let onBuild: () -> Void

    private var hasAnyAnswer: Bool {
        questions.contains { q in
            answers[q.id]?.isEmpty == false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("A few quick questions...")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onBack) {
                    Text("← Back")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            ForEach(questions) { question in
                QuestionRow(
                    question: question,
                    selectedOptions: answers[question.id] ?? [],
                    onToggle: { option in
                        onToggle(question.id, option, question.allowsMultiple)
                    }
                )
            }

            HStack {
                Spacer()
                Button(action: onBuild) {
                    HStack(spacing: 6) {
                        Text("Build Widget")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(hasAnyAnswer ? Color.accentColor : Color.secondary.opacity(0.25))
                    )
                    .foregroundStyle(hasAnyAnswer ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!hasAnyAnswer)
            }
        }
    }
}

private struct QuestionRow: View {
    let question: ClarificationQuestion
    let selectedOptions: [String]
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(question.question)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            // Wrap chips: use a simple flow layout via flexible width chips in an HStack
            // For simplicity, a single HStack with wrapping via GeometryReader trick is complex;
            // We just use a LazyVGrid or an HStack that allows wrapping via layout
            ChipFlowLayout(spacing: 6) {
                ForEach(question.options, id: \.self) { option in
                    OptionChip(
                        label: option,
                        isSelected: selectedOptions.contains(option),
                        onTap: { onToggle(option) }
                    )
                }
            }
        }
    }
}

private struct OptionChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.18), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple chip flow layout

private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { row in
            row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        }.reduce(0) { $0 + $1 } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(subview)
            rowWidth += size.width + spacing
        }
        return rows
    }
}
