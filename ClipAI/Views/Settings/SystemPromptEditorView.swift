//
//  SystemPromptEditorView.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import SwiftUI

/// View for creating and editing system prompts
struct SystemPromptEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LLMSettingsViewModel

    @State private var title: String = ""
    @State private var template: String = ""
    @State private var isValid: Bool = false
    @State private var focusedField: Field? = .title
  
  
  

    private enum Field {
        case title, template
    }

    private var isEditing: Bool {
        return viewModel.editingPrompt != nil
    }

    private var isSystemPrompt: Bool {
        return viewModel.editingPrompt?.isSystemPrompt ?? false
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.05),
                    Color.purple.opacity(0.03),
                    Color.blue.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header with icon and title
                    headerView
                        .padding(.top, 32)
                        .padding(.bottom, 24)

                    // Main form card
                    VStack(spacing: 28) {
                        formView
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
                    )
                    .padding(.horizontal, 32)

                    // Action buttons
                    actionButtonsView
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                }
            }
        }
        .frame(width: 600, height: 720)
        .onAppear {
            setupInitialValues()
        }
        .onChange(of: title) { validateForm() }
        .onChange(of: template) { validateForm() }
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(spacing: 16) {
            // Animated icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: isEditing ? "pencil.and.outline" : "sparkles")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(isEditing ? "Edit Prompt" : "Create New Prompt")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(isEditing ? "Modify your AI prompt" : "Design a new AI prompt for your workflow")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title input with floating label effect
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Title", systemImage: "tag.fill")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(title.count)/100")
                        .font(.caption)
                        .foregroundColor(title.count > 100 ? .red : .secondary)
                        .monospacedDigit()
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            focusedField == .title ? Color.accentColor : Color.gray.opacity(0.2),
                            lineWidth: focusedField == .title ? 2 : 1
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                        .frame(height: 44)

                    TextField("e.g., Code Reviewer, Email Writer, Summarizer...", text: $title)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .onTapGesture {
                            focusedField = .title
                        }
                }

                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                    Text("Give your prompt a memorable, descriptive name")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            // Template input with enhanced UI
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Prompt Template", systemImage: "doc.text.fill")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(template.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                // Text editor with modern styling
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            focusedField == .template ? Color.accentColor : Color.gray.opacity(0.2),
                            lineWidth: focusedField == .template ? 2 : 1
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.textBackgroundColor))
                        )

                    if template.isEmpty {
                        Text("Write your AI instruction here...\n\nExample:\nReview the following code and suggest improvements:\n\n{input}")
                            .font(.body)
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(16)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $template)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(12)
                        .onTapGesture {
                            focusedField = .template
                        }
                }
                .frame(height: 200)

                // Variables and tips section
                VStack(alignment: .leading, spacing: 12) {
                    // Detected variables
                    let placeholders = getPlaceholders(from: template)
                    if !placeholders.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "curlybraces")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("Variables detected:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            FlowLayout(spacing: 8) {
                                ForEach(placeholders, id: \.self) { placeholder in
                                    HStack(spacing: 4) {
                                        Image(systemName: placeholder == "input" ? "doc.on.clipboard.fill" : "curlybraces")
                                            .font(.caption2)
                                        Text("{\(placeholder)}")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: placeholder == "input" ?
                                                        [Color.green, Color.green.opacity(0.8)] :
                                                        [Color.blue, Color.blue.opacity(0.8)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.05))
                        )
                    }

                    // Tips section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Pro Tips")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }

                        tipRow(icon: "doc.on.clipboard", text: "Use {input} to insert clipboard content", color: .green)
                        tipRow(icon: "curlybraces", text: "Create custom variables like {language} or {style}", color: .blue)
                        tipRow(icon: "text.quote", text: "Be specific and clear for best AI results", color: .purple)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.05))
                    )
                }
            }
        }
    }

    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button(action: {
                dismiss()
            }) {
                HStack {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)

            // Save button
            Button(action: {
                Task {
                    await savePrompt()
                }
            }) {
                HStack(spacing: 6) {
                    if viewModel.isLoadingPrompts {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: isEditing ? "checkmark" : "plus.circle.fill")
                    }
                    Text(isEditing ? "Update Prompt" : "Create Prompt")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .disabled(!isValid || viewModel.isLoadingPrompts)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [.command])
        }
    }

    // MARK: - Helper Views

    private func tipRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Methods

    private func setupInitialValues() {
        if let editingPrompt = viewModel.editingPrompt {
            title = editingPrompt.title
            template = editingPrompt.template
        } else {
            title = ""
            template = ""
        }
        validateForm()
    }

    private func validateForm() {
        isValid = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                 !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                 title.count <= 100
    }

    private func savePrompt() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingPrompt = viewModel.editingPrompt {
            // Update existing prompt
            await viewModel.updateSystemPrompt(
                id: editingPrompt.id,
                title: trimmedTitle,
                template: trimmedTemplate
            )
        } else {
            // Create new prompt
            await viewModel.createSystemPrompt(
                title: trimmedTitle,
                template: trimmedTemplate,
                closeEditorOnSuccess: true
            )
        }

        // If successful, the viewModel will close the sheet
        if viewModel.promptErrorMessage == nil {
            dismiss()
        }
    }

    /// Extract placeholders from template text
    private func getPlaceholders(from text: String) -> [String] {
        let pattern = "\\{([^}]+)\\}"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let regex = regex else { return [] }

        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
            return nil
        }
    }
}

// MARK: - Flow Layout for Variables

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    SystemPromptEditorView(viewModel: LLMSettingsViewModel(generalSettingsViewModel: GeneralSettingsViewModel()))
}
