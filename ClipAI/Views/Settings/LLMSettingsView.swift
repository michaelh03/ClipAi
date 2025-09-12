//
//  LLMSettingsView.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import SwiftUI

/// Settings view for managing LLM provider API keys
struct LLMSettingsView: View {
    @StateObject private var viewModel: LLMSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(generalSettingsViewModel: GeneralSettingsViewModel) {
        self._viewModel = StateObject(wrappedValue: LLMSettingsViewModel(generalSettingsViewModel: generalSettingsViewModel))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.bottom, 16)
            
            // Custom Tab View
            CustomTabView(
                content: [
                    (
                        title: "General",
                        icon: "gearshape",
                        view: { AnyView(generalTab) }
                    ),
                    (
                        title: "AI Models",
                        icon: "cpu",
                        view: { AnyView(aiModelsTab) }
                    ),
                    (
                        title: "Prompts", 
                        icon: "text.bubble",
                        view: { AnyView(systemPromptsTab) }
                    )
                ]
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Footer with help link
            footerView
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .padding(24)
        .frame(width: 600, height: 800)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: viewModel.selectedProvider) { _, _ in
            viewModel.providerDidChange()
        }
        .onChange(of: viewModel.apiKeyInput) { _, _ in
            // Validate on change but with slight delay to avoid too frequent validation
            if !viewModel.apiKeyInput.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.validateAPIKey()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingPromptEditor) {
            SystemPromptEditorView(viewModel: viewModel)
        }
    }
    
    // MARK: - Tab Views
    
    private var aiModelsTab: some View {
        AIConfigurationView(viewModel: viewModel)
    }
    
    private var systemPromptsTab: some View {
        PromptsEditorView(viewModel: viewModel)
    }

    private var generalTab: some View {
        GeneralSettingsView(viewModel: viewModel.generalSettingsViewModel)
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("ClipAI Settings")
                .font(.title)
                .fontWeight(.semibold)
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 8) {
            Text("Your API keys are stored securely in the system keychain")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

}



// MARK: - Preview

#Preview {
    LLMSettingsView(generalSettingsViewModel: GeneralSettingsViewModel())
        .frame(width: 600, height: 800)
}

// MARK: - Temporary Placeholder

struct GeneralSettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text("General Settings")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Configure global shortcuts and startup behavior. Coming soon.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
