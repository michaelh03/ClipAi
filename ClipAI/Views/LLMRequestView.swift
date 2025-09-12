//
//  LLMRequestView.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import SwiftUI

/// Modal sheet for submitting LLM requests with provider and prompt selection
struct LLMRequestView: View {
    @StateObject private var viewModel: LLMRequestViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPromptListFocused: Bool
    
    // MARK: - Initialization
    
    init(clipboardContent: String) {
        self._viewModel = StateObject(wrappedValue: LLMRequestViewModel(clipboardContent: clipboardContent))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main content
            if viewModel.isRequestInProgress {
                progressView
            } else if viewModel.requestResult != nil {
                resultView
            } else {
                requestFormView
            }
            
            // Footer with action buttons
            footerView
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            // Focus the prompt list for keyboard navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPromptListFocused = true
            }
        }
        .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }

    }

    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Ask AI")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    viewModel.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isHovering in
                    // Add subtle hover effect
                }
            }
            
            Divider()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Request Form View
    
    private var requestFormView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Provider Selection
                providerSelectionView
                
                // Prompt Selection
                promptSelectionView
                
                // Clipboard Content Preview
                clipboardContentView
                
                // Prompt Preview
                promptPreviewView
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Provider Selection
    
    private var providerSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Provider")
                .font(.headline)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(viewModel.availableProviders) { provider in
                    Button(action: {
                        viewModel.selectProvider(provider)
                    }) {
                        HStack {
                            Text(provider.displayName)
                            Spacer()
                            if provider.id == viewModel.selectedProvider?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(!provider.isConfigured)
                }
            } label: {
                HStack {
                    if let selectedProvider = viewModel.selectedProvider {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedProvider.displayName)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(selectedProvider.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Select Provider")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Prompt Selection
    
    private var promptSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Prompt")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(viewModel.availablePrompts.enumerated()), id: \.element.id) { index, prompt in
                        promptRowView(prompt: prompt, index: index)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            )
            .focused($isPromptListFocused)
            .onKeyPress { keyPress in
                if keyPress.key == .upArrow {
                    viewModel.movePromptSelection(up: true)
                    return .handled
                } else if keyPress.key == .downArrow {
                    viewModel.movePromptSelection(up: false)
                    return .handled
                } else if keyPress.key == .space || keyPress.key == .return {
                    if viewModel.selectedPromptIndex < viewModel.availablePrompts.count {
                        let selectedPrompt = viewModel.availablePrompts[viewModel.selectedPromptIndex]
                        viewModel.selectPrompt(selectedPrompt)
                    }
                    return .handled
                }
                return .ignored
            }
        }
    }
    
    private func promptRowView(prompt: SystemPrompt, index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(prompt.template)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if prompt.id == viewModel.selectedPrompt?.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(prompt.id == viewModel.selectedPrompt?.id ?
                      Color.accentColor.opacity(0.1) :
                      (index == viewModel.selectedPromptIndex ? Color.primary.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    prompt.id == viewModel.selectedPrompt?.id ?
                        Color.accentColor.opacity(0.3) :
                        (index == viewModel.selectedPromptIndex ? Color.primary.opacity(0.2) : Color.clear),
                    lineWidth: 1
                )
        )
        .onTapGesture {
            viewModel.selectPrompt(prompt)
        }
    }
    
    // MARK: - Clipboard Content View
    
    private var clipboardContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clipboard Content")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView {
                Text(viewModel.clipboardContent)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Prompt Preview View
    
    private var promptPreviewView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt Preview")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView {
                Text(viewModel.getPromptPreview())
                    .font(.body)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Progress View
    
    private var progressView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(viewModel.progressMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Result View
    
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.hasError {
                // Error State
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    Text("Request Failed")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Success State
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Response")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    ScrollView {
                        Text(viewModel.requestResult ?? "")
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                // Keyboard shortcut hint
                if !viewModel.isRequestInProgress && viewModel.requestResult == nil {
                    Text("⌘↩ to send")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.requestResult != nil {
                    // Result state buttons
                    HStack(spacing: 12) {
                        Button("Send Another") {
                            viewModel.resetRequest()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Close") {
                            viewModel.dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if !viewModel.isRequestInProgress {
                    // Request form buttons
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            viewModel.dismiss()
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                        
                        Button("Send Request") {
                            Task {
                                await viewModel.sendRequest()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedProvider == nil || viewModel.selectedPrompt == nil)
                        .keyboardShortcut(.return, modifiers: [.command])
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}