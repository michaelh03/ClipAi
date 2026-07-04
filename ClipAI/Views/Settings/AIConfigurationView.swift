//
//  AIConfigurationView.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import SwiftUI

/// View for managing AI provider configuration, API keys, and model selection
struct AIConfigurationView: View {
    @ObservedObject var viewModel: LLMSettingsViewModel
    @State private var customModelIdInput: String = ""
    @State private var customModelEndpointInput: String = ""
    @State private var customModelConfigJSONInput: String = ""
    @State private var customModelError: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Provider configuration section
                VStack(spacing: 20) {
                    providerConfigurationHeaderView
                    
                    VStack(spacing: 16) {
                        // Provider Selection
                        providerSelectionView
                        
                        // Model Selection
                        modelSelectionView
                        
                        // API Key Configuration
                        apiKeyConfigurationView
                        
                        // Action Buttons
                        actionButtonsView
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                // Status Messages
                statusMessagesView
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
          Task {
            await viewModel.loadProviderAvailabilityStatus()
          }
        }
        .onChange(of: viewModel.selectedProvider) { _ in
            customModelIdInput = ""
            customModelEndpointInput = ""
            customModelConfigJSONInput = ""
            customModelError = nil
        }
    }
    
    // MARK: - View Components

    private var providerConfigurationHeaderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                Text("AI Provider Setup")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Show current active provider status
            HStack(spacing: 8) {
                if let defaultId = viewModel.defaultProviderId,
                   let defaultProvider = viewModel.availableProviders.first(where: { $0.id == defaultId }) {
                    // Status indicator for active provider
                    if viewModel.providerAvailabilityStatus[defaultProvider.id] == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    } else if viewModel.providerKeyStatus[defaultProvider.id] == true {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    } else {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }

                    Text("Active Provider: \(defaultProvider.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.secondary)
                        .font(.subheadline)

                    Text("No active provider - configure one below")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }

                Spacer()
            }
        }
    }
    
    private var providerSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Provider")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("Step 1 of 3")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Picker("Provider", selection: $viewModel.selectedProvider) {
                ForEach(viewModel.availableProviders) { provider in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(provider.displayName)
                                .fontWeight(.medium)
                            Spacer()

                            // Active indicator
                            if viewModel.defaultProviderId == provider.id {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .help("Currently active provider")
                            }

                            // Status indicators
                            if viewModel.providerAvailabilityStatus[provider.id] == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                    .help("Configured and working")
                            } else if viewModel.providerKeyStatus[provider.id] == true {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .help("API key saved but not verified")
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .help("Not configured")
                            }
                        }

                        // Status text
                        HStack {
                            if viewModel.defaultProviderId == provider.id {
                                Text("ACTIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            if viewModel.providerAvailabilityStatus[provider.id] == true {
                                Text("Ready")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .fontWeight(.medium)
                            } else if viewModel.providerKeyStatus[provider.id] == true {
                                Text("Needs verification")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .fontWeight(.medium)
                            } else {
                                Text("Not configured")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .tag(provider)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Provider description
            Text(viewModel.selectedProvider.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    private var modelSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Model")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("Step 2 of 3")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            
            if viewModel.availableModels.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("No models available for this provider")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            } else {
                Picker("Model", selection: Binding<LLMSettingsViewModel.ModelInfo?>(
                    get: { viewModel.selectedModel },
                    set: { newModel in
                        viewModel.selectedModel = newModel
                        viewModel.saveSelectedModel()
                    }
                )) {
                    ForEach(viewModel.availableModels) { model in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(model.displayName)
                                    .font(.system(.body))
                                Spacer()
                                // Model capabilities indicators
                                if model.capabilities.contains("Vision") {
                                    Image(systemName: "eye.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                        .help("Supports vision/image inputs")
                                }
                                if model.capabilities.contains("Function Calling") {
                                    Image(systemName: "function")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                        .help("Supports function calling")
                                }
                                if let maxTokens = model.maxTokens {
                                    Text("\(formatTokenCount(maxTokens))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .help("Maximum context length")
                                }
                            }
                            if let description = model.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(nil)
                            }
                        }
                        .tag(model as LLMSettingsViewModel.ModelInfo?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Selected model info card
                if let selectedModel = viewModel.selectedModel {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.accentColor)
                            Text("Selected Model")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedModel.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let description = selectedModel.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                if let maxTokens = selectedModel.maxTokens {
                                    Label("\(formatTokenCount(maxTokens)) tokens", systemImage: "doc.text")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !selectedModel.capabilities.isEmpty {
                                    Text("• \(selectedModel.capabilities.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            if viewModel.supportsCustomModelEndpoints {
                customModelManagementView
            }
        }
    }

    private var customModelManagementView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Custom Model Endpoint")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Model ID (e.g., llama-3.1-70b)", text: $customModelIdInput)
                    .textFieldStyle(.roundedBorder)
                TextField("Endpoint URL (e.g., https://api.example.com/v1)", text: $customModelEndpointInput)
                    .textFieldStyle(.roundedBorder)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Additional JSON (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $customModelConfigJSONInput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 70, maxHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    Text("Merged into the request body. Example: {\"reasoning\":{\"enabled\":true}}")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Button {
                        let error = viewModel.addCustomModel(
                            modelId: customModelIdInput,
                            endpointURL: customModelEndpointInput,
                            additionalConfigJSON: customModelConfigJSONInput
                        )
                        customModelError = error
                        if error == nil {
                            customModelIdInput = ""
                            customModelEndpointInput = ""
                            customModelConfigJSONInput = ""
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Model")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(
                        customModelIdInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        customModelEndpointInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    Spacer()
                }

                if let customModelError = customModelError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(customModelError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            if !viewModel.customModelsForSelectedProvider.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Custom Models")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(viewModel.customModelsForSelectedProvider, id: \.modelId) { model in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.modelId)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(model.endpointURL)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                if let extra = model.additionalConfigJSON, !extra.isEmpty {
                                    Text("Extra config: \(extra)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Button {
                                viewModel.removeCustomModel(modelId: model.modelId)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                            .help("Remove custom model")
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
    
    private var apiKeyConfigurationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("API Key")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Step 3 of 3")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // API Key input field
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SecureField("Enter your API key", text: $viewModel.apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    
                    // Get API Key button
                    Button("Get Key") {
                        guard let url = providerKeyURL else { return }
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(providerKeyURL == nil)
                }
                
                // Format hint and validation
                VStack(alignment: .leading, spacing: 6) {
                    Text("Format: \(viewModel.selectedProvider.keyFormat)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Validation feedback
                    if let validationError = viewModel.validationError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(validationError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    } else if viewModel.apiKeyIsValid && !viewModel.apiKeyInput.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API key format is valid")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 12) {
                // Test API Key button
                Button {
                    Task {
                        await viewModel.testAPIKey()
                    }
                } label: {
                    HStack {
                        if viewModel.isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text("Test Connection")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.apiKeyInput.isEmpty || viewModel.isValidating)
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                // Save button
                Button {
                    viewModel.saveAPIKey()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Configuration")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.apiKeyInput.isEmpty)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            // Remove button (only show if key exists)
            if viewModel.providerKeyStatus[viewModel.selectedProvider.id] == true {
                Button {
                    viewModel.removeAPIKey()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove API Key")
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .controlSize(.small)
            }
        }
    }
    
    private var statusMessagesView: some View {
        VStack(spacing: 12) {
            // Success message
            if viewModel.saveSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Configuration Saved!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        Text("Your API key has been saved and this provider is now active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Configuration Error")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }

    private var providerKeyURL: URL? {
        let trimmed = viewModel.selectedProvider.websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

// MARK: - Preview

#Preview {
    AIConfigurationView(viewModel: LLMSettingsViewModel(generalSettingsViewModel: GeneralSettingsViewModel()))
        .frame(width: 500, height: 600)
}
