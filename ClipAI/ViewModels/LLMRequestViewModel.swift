//
//  LLMRequestViewModel.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import Foundation
import SwiftUI

/// ViewModel for managing LLM request modal sheet
@MainActor
class LLMRequestViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The clipboard content to send to LLM
    @Published var clipboardContent: String = ""
    
    /// Available providers for selection
    @Published var availableProviders: [ProviderInfo] = []
    
    /// Currently selected provider
    @Published var selectedProvider: ProviderInfo?
    
    /// Available system prompts
    @Published var availablePrompts: [SystemPrompt] = []
    
    /// Currently selected prompt
    @Published var selectedPrompt: SystemPrompt?
    
    /// Keyboard navigation selection index for prompts
    @Published var selectedPromptIndex: Int = 0
    
    /// Whether a request is currently in progress
    @Published var isRequestInProgress: Bool = false
    
    /// Current progress message
    @Published var progressMessage: String = ""
    
    /// Request result or error message
    @Published var requestResult: String? = nil
    
    /// Whether there was an error
    @Published var hasError: Bool = false
    
    /// Error message to display
    @Published var errorMessage: String? = nil
    
    /// Whether the modal should be dismissed
    @Published var shouldDismiss: Bool = false
    
    // MARK: - Private Properties
    
    private let promptStore: PromptStore
    
    // MARK: - Provider Information
    
    struct ProviderInfo: Identifiable, Equatable, Hashable {
        let id: String
        let displayName: String
        let description: String
        let isConfigured: Bool
        
        static func == (lhs: ProviderInfo, rhs: ProviderInfo) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    // MARK: - Initialization
    
    init(clipboardContent: String, promptStore: PromptStore = PromptStore.shared) {
        self.clipboardContent = clipboardContent
        self.promptStore = promptStore
        
        loadAvailableProviders()
        loadAvailablePrompts()
    }
    
    // MARK: - Public Methods
    
    /// Send the request to the selected LLM provider
    func sendRequest() async {
        guard let selectedProvider = selectedProvider,
              let selectedPrompt = selectedPrompt,
              !clipboardContent.isEmpty else {
            showError("Please select a provider and prompt")
            return
        }
        
        // Start request
        isRequestInProgress = true
        hasError = false
        errorMessage = nil
        requestResult = nil
        progressMessage = "Sending request to \(selectedProvider.displayName)..."
        
        do {
            NotificationCenter.default.post(name: .aiActivityDidStart, object: nil)
            // TODO: Implement actual LLM request through LLMRequestManager
            // For now, simulate the request
            try await simulateRequest()
            
        } catch {
            showError("Request failed: \(error.localizedDescription)")
        }
        
        isRequestInProgress = false
        NotificationCenter.default.post(name: .aiActivityDidFinish, object: nil)
    }
    
    /// Handle keyboard navigation for prompt selection
    func movePromptSelection(up: Bool) {
        if up {
            selectedPromptIndex = max(0, selectedPromptIndex - 1)
        } else {
            selectedPromptIndex = min(availablePrompts.count - 1, selectedPromptIndex + 1)
        }
        
        if selectedPromptIndex < availablePrompts.count {
            selectedPrompt = availablePrompts[selectedPromptIndex]
        }
    }
    
    /// Handle prompt selection change
    func selectPrompt(_ prompt: SystemPrompt) {
        selectedPrompt = prompt
        if let index = availablePrompts.firstIndex(where: { $0.id == prompt.id }) {
            selectedPromptIndex = index
        }
    }
    
    /// Handle provider selection change
    func selectProvider(_ provider: ProviderInfo) {
        selectedProvider = provider
    }
    
    /// Get preview of the processed prompt
    func getPromptPreview() -> String {
        guard let selectedPrompt = selectedPrompt else {
            return "Select a prompt to see preview..."
        }
        
        let processedPrompt = selectedPrompt.processTemplate(with: clipboardContent)
        
        // Truncate if too long for preview
        let maxPreviewLength = 200
        if processedPrompt.count > maxPreviewLength {
            return String(processedPrompt.prefix(maxPreviewLength)) + "..."
        }
        
        return processedPrompt
    }
    
    /// Close the modal
    func dismiss() {
        shouldDismiss = true
    }
    
    /// Reset the request state
    func resetRequest() {
        isRequestInProgress = false
        hasError = false
        errorMessage = nil
        requestResult = nil
        progressMessage = ""
    }
    
    // MARK: - Private Methods
    
    /// Load available providers from the system
    private func loadAvailableProviders() {
        // TODO: Replace with actual provider registry when available
        // For now, use hardcoded providers similar to LLMSettingsViewModel
        availableProviders = [
            ProviderInfo(
                id: "openai",
                displayName: "OpenAI GPT",
                description: "GPT-4, GPT-4 Turbo, and GPT-3.5 models",
                isConfigured: true // TODO: Check actual configuration status
            )
        ]
        
        // Select first configured provider by default
        selectedProvider = availableProviders.first { $0.isConfigured }
    }
    
    /// Load available prompts from the prompt store
    private func loadAvailablePrompts() {
        availablePrompts = promptStore.prompts
        
        // Select the first prompt by default
        if let firstPrompt = availablePrompts.first {
            selectedPrompt = firstPrompt
            selectedPromptIndex = 0
        }
    }
    
    /// Show error message
    private func showError(_ message: String) {
        hasError = true
        errorMessage = message
        isRequestInProgress = false
    }
    
    /// Simulate an LLM request for testing
    private func simulateRequest() async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simulate successful response
        requestResult = "This is a simulated response from \(selectedProvider?.displayName ?? "Unknown Provider"). " +
                       "The actual implementation will integrate with the LLMRequestManager to send real requests to the LLM providers."
        progressMessage = "Request completed successfully"
    }
}