//
//  PromptsEditorView.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import SwiftUI

/// View for managing system prompts (create, read, update, delete)
struct PromptsEditorView: View {
    @ObservedObject var viewModel: LLMSettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // System Prompts Section
                systemPromptsView
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Ensure prompts are loaded when this tab actually appears
            await viewModel.loadSystemPrompts()
        }
    }
    
    // MARK: - View Components
    
    private var systemPromptsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("System Prompts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // One-click AI configurations
            oneClickAIConfigurationsView
            
            // Prompt messages
            promptMessagesView
            
            if viewModel.isLoadingPrompts {
                loadingStateView
            } else if viewModel.systemPrompts.isEmpty {
                emptyStateView
            } else {
                // Custom prompts section
                customPromptsSection
                
                // Default prompts section
                defaultPromptsSection
            }
            
            Text("Global prompts available across all LLM providers")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var loadingStateView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading prompts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No prompts available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Create your first custom prompt to get started")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private var defaultPromptsSection: some View {
        let defaultPrompts = viewModel.systemPrompts.filter { $0.isSystemPrompt }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Built-in Prompts", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text("\(defaultPrompts.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
            }
            
            if !defaultPrompts.isEmpty {
                VStack(spacing: 1) {
                    ForEach(defaultPrompts) { prompt in
                        promptRowView(prompt: prompt, isFirst: prompt.id == defaultPrompts.first?.id, isLast: prompt.id == defaultPrompts.last?.id)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var customPromptsSection: some View {
        let customPrompts = viewModel.systemPrompts.filter { !$0.isSystemPrompt }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Custom Prompts", systemImage: "person.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                HStack(spacing: 8) {
                    Text("\(customPrompts.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    Button(action: {
                        viewModel.showNewPromptEditor()
                    }) {
                        Label("New Prompt", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            if customPrompts.isEmpty {
                VStack(spacing: 8) {
                    Text("No custom prompts yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Create your first prompt") {
                        viewModel.showNewPromptEditor()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                VStack(spacing: 1) {
                    ForEach(customPrompts) { prompt in
                        promptRowView(prompt: prompt, isFirst: prompt.id == customPrompts.first?.id, isLast: prompt.id == customPrompts.last?.id)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private func promptRowView(prompt: SystemPrompt, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: prompt.isSystemPrompt ? "star.fill" : "person.fill")
                .font(.system(size: 16))
                .foregroundColor(prompt.isSystemPrompt ? .orange : .blue)
                .frame(width: 20, alignment: .center)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(prompt.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Template preview
                Text(prompt.template.replacingOccurrences(of: "\n", with: " "))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Metadata
                HStack(spacing: 12) {
                    Label("\(prompt.template.count) chars", systemImage: "textformat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if prompt.containsPlaceholder("input") {
                        Label("Uses clipboard", systemImage: "doc.on.clipboard")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    let placeholders = prompt.getPlaceholders()
                    if placeholders.count > 1 {
                        Label("\(placeholders.count) variables", systemImage: "curlybraces")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            if !prompt.isSystemPrompt {
                VStack(spacing: 8) {
                    Button(action: {
                        viewModel.showEditPromptEditor(for: prompt)
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                    .help("Edit prompt")
                    
                    Button(action: {
                        Task {
                            await viewModel.deleteSystemPrompt(id: prompt.id)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete prompt")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(NSColor.textBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: isLast ? 0 : 1)
                .foregroundColor(Color.primary.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    private var promptMessagesView: some View {
        VStack(spacing: 4) {
            // Success message
            if let successMessage = viewModel.promptSuccessMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Error message
            if let errorMessage = viewModel.promptErrorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
    
    private var oneClickAIConfigurationsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("One-Click AI Actions")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Action 1
                oneClickAIActionRow(
                    action: 1,
                    title: "Action 1",
                    shortcutDisplay: "⌃⌘⌥1",
                    selectedPromptId: Binding(
                        get: { 
                            guard let stringId = viewModel.defaultSystemPromptIds[0] else { return nil }
                            return UUID(uuidString: stringId) 
                        },
                        set: { 
                            print("🔧 PromptsEditorView binding set for Action 1: \($0?.uuidString ?? "nil")")
                            viewModel.setDefaultSystemPrompt($0, for: 1) 
                        }
                    )
                )
                
                // Action 2
                oneClickAIActionRow(
                    action: 2,
                    title: "Action 2",
                    shortcutDisplay: "⌃⌘⌥2",
                    selectedPromptId: Binding(
                        get: { 
                            guard let stringId = viewModel.defaultSystemPromptIds[1] else { return nil }
                            return UUID(uuidString: stringId) 
                        },
                        set: { 
                            print("🔧 PromptsEditorView binding set for Action 2: \($0?.uuidString ?? "nil")")
                            viewModel.setDefaultSystemPrompt($0, for: 2) 
                        }
                    )
                )
                
                // Action 3
                oneClickAIActionRow(
                    action: 3,
                    title: "Action 3",
                    shortcutDisplay: "⌃⌘⌥3",
                    selectedPromptId: Binding(
                        get: { 
                            guard let stringId = viewModel.defaultSystemPromptIds[2] else { return nil }
                            return UUID(uuidString: stringId) 
                        },
                        set: { 
                            print("🔧 PromptsEditorView binding set for Action 3: \($0?.uuidString ?? "nil")")
                            viewModel.setDefaultSystemPrompt($0, for: 3) 
                        }
                    )
                )
            }
            
            Text("Configure different system prompts for each one-click AI action. Each action has its own keyboard shortcut.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func oneClickAIActionRow(action: Int, title: String, shortcutDisplay: String, selectedPromptId: Binding<UUID?>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(shortcutDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if let promptId = selectedPromptId.wrappedValue,
                   let prompt = viewModel.systemPrompts.first(where: { $0.id == promptId }) {
                    Text(prompt.title)
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("No prompt selected")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            Picker("Prompt", selection: selectedPromptId) {
                Text("None").tag(nil as UUID?)
                ForEach(viewModel.systemPrompts) { prompt in
                    Text(prompt.title).tag(prompt.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 150, maxWidth: 250)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
  PromptsEditorView(viewModel: LLMSettingsViewModel(generalSettingsViewModel: GeneralSettingsViewModel()))
        .frame(width: 500, height: 600)
}
