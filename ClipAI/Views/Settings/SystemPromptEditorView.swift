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
    
    private var isEditing: Bool {
        return viewModel.editingPrompt != nil
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerView
            
            // Form content
            formView
            
            // Action buttons
            actionButtonsView
            
            Spacer()
        }
        .padding(24)
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            setupInitialValues()
        }
        .onChange(of: title) { validateForm() }
        .onChange(of: template) { validateForm() }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text(isEditing ? "Edit System Prompt" : "New System Prompt")
                .font(.title)
                .fontWeight(.semibold)
            
            Text(isEditing ? "Modify your custom system prompt" : "Create a new system prompt for AI interactions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var formView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title input
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.headline)
                
                TextField("Enter prompt title...", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                Text("A short, descriptive name for this prompt")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Template input
            VStack(alignment: .leading, spacing: 8) {
                Text("Template")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: $template)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Use {input} to represent clipboard content")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(template.count) characters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show detected placeholders
                        let placeholders = getPlaceholders(from: template)
                        if !placeholders.isEmpty {
                            HStack {
                                Text("Variables found:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(placeholders, id: \.self) { placeholder in
                                    Text("{\(placeholder)}")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.blue.opacity(0.1))
                                        )
                                }
                            }
                        }
                        
                        // Show helpful examples
                        if placeholders.isEmpty && !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("💡 Add {input} to use clipboard content, or create custom variables like {language}")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            // Save button
            Button(isEditing ? "Update" : "Create") {
                Task {
                    await savePrompt()
                }
            }
            .disabled(!isValid || viewModel.isLoadingPrompts)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command])
            
            // Create and add another (only for create mode)
            if !isEditing {
                Button("Create & Add Another") {
                    Task {
                        await createAndReset()
                    }
                }
                .disabled(!isValid || viewModel.isLoadingPrompts)
                .buttonStyle(.bordered)
            }

            if viewModel.isLoadingPrompts {
                ProgressView()
                    .scaleEffect(0.8)
            }
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
                 !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func createAndReset() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !isEditing else { return }
        
        await viewModel.createSystemPrompt(
            title: trimmedTitle,
            template: trimmedTemplate,
            closeEditorOnSuccess: false
        )
        
        if viewModel.promptErrorMessage == nil {
            // Reset fields for adding another prompt quickly
            title = ""
            template = ""
            validateForm()
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

// MARK: - Preview

#Preview {
    SystemPromptEditorView(viewModel: LLMSettingsViewModel(generalSettingsViewModel: GeneralSettingsViewModel()))
}