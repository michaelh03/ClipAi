//
//  LLMSettingsViewModel.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import Foundation
import SwiftUI

/// ViewModel for managing LLM provider settings and API keys
@MainActor
class LLMSettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current API key text input
    @Published var apiKeyInput: String = ""
    
    /// Whether the API key input is valid
    @Published var apiKeyIsValid: Bool = false
    
    /// Current validation error message
    @Published var validationError: String? = nil
    
    /// Whether API key validation is in progress
    @Published var isValidating: Bool = false
    
    /// Whether the API key was successfully saved
    @Published var saveSuccess: Bool = false
    
    /// Current save/validation error message
    @Published var errorMessage: String? = nil
    
    /// Available LLM providers
    @Published var availableProviders: [ProviderInfo] = []
    
    /// Currently selected provider
    @Published var selectedProvider: ProviderInfo
    
    /// Whether each provider has a stored API key
    @Published var providerKeyStatus: [String: Bool] = [:]
    
    /// Default provider ID selection
    @Published var defaultProviderId: String? = nil
    
    /// Provider availability status (configured and working)
    @Published var providerAvailabilityStatus: [String: Bool] = [:]
    
    /// Available models for the selected provider
    @Published var availableModels: [ModelInfo] = []
    
    /// Currently selected model for the selected provider
    @Published var selectedModel: ModelInfo?
    
    /// Selected models for all providers
    @Published var providerSelectedModels: [String: String] = [:]
    
    // MARK: - System Prompts Properties
    
    /// All available system prompts
    @Published var systemPrompts: [SystemPrompt] = []
    
    /// Default system prompt IDs for one-click processing (Actions 1, 2, 3)
    @Published var defaultSystemPromptIds: [String?] = [nil, nil, nil]
    
    /// Whether the system prompts section is currently loading
    @Published var isLoadingPrompts: Bool = false
    
    /// Error message for system prompt operations
    @Published var promptErrorMessage: String? = nil
    
    /// Success message for system prompt operations
    @Published var promptSuccessMessage: String? = nil
    
    /// Whether the add/edit prompt sheet is showing
    @Published var showingPromptEditor: Bool = false
    
    /// The prompt being edited (nil for new prompt)
    @Published var editingPrompt: SystemPrompt? = nil
    
    // MARK: - Services
    
    private let keychainService: KeychainService
    private let providerRegistry: LLMProviderRegistry
    // Defer PromptStore creation until first use to avoid blocking first appearance
    private var injectedPromptStore: PromptStore? = nil
    private var promptStore: PromptStore { injectedPromptStore ?? PromptStore.shared }
    
    // MARK: - Shared View Models
    
    /// Shared general settings view model for consistent settings across the app
    let generalSettingsViewModel: GeneralSettingsViewModel
    
    // MARK: - Provider Information
    
    struct ProviderInfo: Identifiable, Equatable, Hashable {
        let id: String
        let displayName: String
        let description: String
        let keyFormat: String
        let websiteURL: String
        
        static func == (lhs: ProviderInfo, rhs: ProviderInfo) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    struct ModelInfo: Identifiable, Equatable, Hashable {
        let id: String
        let displayName: String
        let description: String?
        let maxTokens: Int?
        let capabilities: [String]
        
        static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    // MARK: - Initialization
    
    init(keychainService: KeychainService = KeychainService(), providerRegistry: LLMProviderRegistry = LLMProviderRegistry.shared, promptStore: PromptStore? = nil, generalSettingsViewModel: GeneralSettingsViewModel) {
        AppLog("Initializing LLMSettingsViewModel", level: .info, category: "Settings")
        self.keychainService = keychainService
        self.providerRegistry = providerRegistry
        self.generalSettingsViewModel = generalSettingsViewModel
        // Allow injection for tests; otherwise, computed property will use shared on first access
        if let promptStore = promptStore { injectedPromptStore = promptStore }
        
        // Initialize available providers from registry
        let availableProviders = Self.getAvailableProviders()
        self.selectedProvider = availableProviders.first!
        self.availableProviders = availableProviders
        
        // Load initial state
        loadProviderKeyStatus()
        loadAPIKeyForSelectedProvider()
        loadSelectedModels()
        loadAvailableModelsForSelectedProvider()
        loadDefaultSystemPromptIds()
        
        // Load default provider (no network) and align selection accordingly
        Task { [availableProviders] in
            await loadDefaultProvider()
            await MainActor.run {
                if let id = defaultProviderId,
                   let match = availableProviders.first(where: { $0.id == id }) {
                    selectedProvider = match
                    providerDidChange()
                }
            }
            // Defer loading system prompts until the Prompts tab is actually shown
        }
    }
    
    // MARK: - Public Methods
    
    /// Load API key for the currently selected provider
    func loadAPIKeyForSelectedProvider() {
        do {
            if let existingKey = try keychainService.retrieveAPIKey(for: selectedProvider.id) {
                apiKeyInput = existingKey
                apiKeyIsValid = true
                validationError = nil
            } else {
                apiKeyInput = ""
                apiKeyIsValid = false
                validationError = nil
            }
        } catch {
            apiKeyInput = ""
            apiKeyIsValid = false
            validationError = "Failed to load existing API key"
        }
        
        // Clear any previous messages
        saveSuccess = false
        errorMessage = nil
    }
    
    /// Validate the current API key input
    func validateAPIKey() {
        guard !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            apiKeyIsValid = false
            validationError = "API key cannot be empty"
            return
        }
        
        do {
            // Validate format without persisting or mutating stored key.
            try keychainService.validateAPIKeyFormat(apiKeyInput, for: selectedProvider.id)

            // If we get here, the key is valid format-wise
            apiKeyIsValid = true
            validationError = nil
        } catch let error as LLMError {
            apiKeyIsValid = false
            validationError = error.errorDescription
        } catch {
            apiKeyIsValid = false
            validationError = "Invalid API key format"
        }
    }
    
    /// Test the API key by making a real API call
    func testAPIKey() async {
        guard !apiKeyInput.isEmpty else { return }
        
        isValidating = true
        errorMessage = nil
        
        do {
            // Create a temporary provider instance to test the key
            let provider = try createTempProvider(id: selectedProvider.id, apiKey: apiKeyInput)
            let isConfigured = await provider.isConfigured()
            
            if isConfigured {
                apiKeyIsValid = true
                validationError = nil
                errorMessage = nil
            } else {
                apiKeyIsValid = false
                validationError = "API key test failed"
                errorMessage = "The API key appears to be invalid or inactive"
            }
        } catch let error as LLMError {
            apiKeyIsValid = false
            validationError = "API key test failed"
            errorMessage = error.errorDescription
        } catch {
            apiKeyIsValid = false
            validationError = "API key test failed"
            errorMessage = error.localizedDescription
        }
        
        isValidating = false
    }
    
    /// Save the current API key
    func saveAPIKey() {
        guard !apiKeyInput.isEmpty else {
            errorMessage = "Please enter an API key"
            return
        }
        
        do {
            try keychainService.storeAPIKey(apiKeyInput, for: selectedProvider.id)
            saveSuccess = true
            errorMessage = nil
            
            // Update provider key status
            loadProviderKeyStatus()
            
            // Refresh provider registry and update availability status
            providerRegistry.refreshProviderAvailability()
            Task {
                await loadDefaultProvider()
                await loadProviderAvailabilityStatus()
            }
            
            // Clear success message after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.saveSuccess = false
            }
            
        } catch let error as LLMError {
            saveSuccess = false
            errorMessage = error.errorDescription
        } catch {
            saveSuccess = false
            errorMessage = "Failed to save API key"
        }
    }
    
    /// Remove the API key for the current provider
    func removeAPIKey() {
        do {
            try keychainService.removeAPIKey(for: selectedProvider.id)
            apiKeyInput = ""
            apiKeyIsValid = false
            validationError = nil
            saveSuccess = false
            errorMessage = nil
            
            // Update provider key status
            loadProviderKeyStatus()
            
            // Refresh provider registry and update availability status
            providerRegistry.refreshProviderAvailability()
            Task {
                await loadDefaultProvider()
                await loadProviderAvailabilityStatus()
            }
            
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to remove API key"
        }
    }
    
    /// Called when the selected provider changes
    func providerDidChange() {
        loadAPIKeyForSelectedProvider()
        loadAvailableModelsForSelectedProvider()
    }
    
    /// Load the default provider from the registry
    func loadDefaultProvider() async {
        defaultProviderId = await providerRegistry.getDefaultProviderId()
    }
    
    /// Load provider availability status from the registry
    func loadProviderAvailabilityStatus() async {
        providerAvailabilityStatus.removeAll()
        
        for provider in availableProviders {
            let isAvailable = await providerRegistry.isProviderAvailable(provider.id)
            providerAvailabilityStatus[provider.id] = isAvailable
        }
    }
    
    /// Load available models for the currently selected provider
    func loadAvailableModelsForSelectedProvider() {
        do {
            let provider = try createTempProvider(id: selectedProvider.id, apiKey: "dummy-key")
            let models = provider.availableModels()
            
            availableModels = models.map { modelId in
                ModelInfo(
                    id: modelId,
                    displayName: getDisplayName(for: modelId, providerId: selectedProvider.id),
                    description: getModelDescription(for: modelId, providerId: selectedProvider.id),
                    maxTokens: getMaxTokens(for: modelId, providerId: selectedProvider.id),
                    capabilities: getModelCapabilities(for: modelId, providerId: selectedProvider.id)
                )
            }
            
            // Set the selected model for this provider
            if let selectedModelId = providerSelectedModels[selectedProvider.id],
               let model = availableModels.first(where: { $0.id == selectedModelId }) {
                selectedModel = model
            } else if let firstModel = availableModels.first {
                selectedModel = firstModel
                providerSelectedModels[selectedProvider.id] = firstModel.id
                saveSelectedModels()
            }
            
        } catch {
            availableModels = []
            selectedModel = nil
        }
    }
    
    /// Load selected models from UserDefaults
    func loadSelectedModels() {
        providerSelectedModels = UserDefaults.standard.dictionary(forKey: "selectedModels") as? [String: String] ?? [:]
    }
    
    /// Save selected models to UserDefaults
    func saveSelectedModels() {
        UserDefaults.standard.set(providerSelectedModels, forKey: "selectedModels")
    }
    
    /// Save the selected model for the current provider
    func saveSelectedModel() {
        guard let selectedModel = selectedModel else { return }
        
        providerSelectedModels[selectedProvider.id] = selectedModel.id
        saveSelectedModels()
    }
    
    /// Get the selected model ID for a provider
    func getSelectedModel(for providerId: String) -> String? {
        return providerSelectedModels[providerId]
    }
    
    // MARK: - System Prompts Management
    
    /// Load system prompts from the prompt store
    func loadSystemPrompts() async {
        isLoadingPrompts = true
        
        // Wait for the prompt store's initial load to complete instead of triggering a new load
        await promptStore.waitForInitialLoad()
        systemPrompts = promptStore.prompts
        
        isLoadingPrompts = false
    }
    
    /// Show the prompt editor for creating a new prompt
    func showNewPromptEditor() {
        editingPrompt = nil
        showingPromptEditor = true
        clearPromptMessages()
    }
    
    /// Show the prompt editor for editing an existing prompt
    func showEditPromptEditor(for prompt: SystemPrompt) {
        guard !prompt.isSystemPrompt else {
            promptErrorMessage = "Cannot edit built-in system prompts"
            clearPromptMessagesAfterDelay()
            return
        }
        
        editingPrompt = prompt
        showingPromptEditor = true
        clearPromptMessages()
    }
    
    /// Create a new system prompt
    /// - Parameters:
    ///   - title: Prompt title
    ///   - template: Prompt template
    ///   - closeEditorOnSuccess: If true, closes the editor sheet after successful creation
    func createSystemPrompt(title: String, template: String, closeEditorOnSuccess: Bool = true) async {
        isLoadingPrompts = true
        clearPromptMessages()
        
        do {
            try await promptStore.createPrompt(title: title, template: template)
            await loadSystemPrompts()
            promptSuccessMessage = "System prompt created successfully"
            if closeEditorOnSuccess {
                showingPromptEditor = false
            }
            clearPromptMessagesAfterDelay()
        } catch {
            promptErrorMessage = error.localizedDescription
            clearPromptMessagesAfterDelay()
        }
        
        isLoadingPrompts = false
    }
    
    /// Update an existing system prompt
    func updateSystemPrompt(id: UUID, title: String, template: String) async {
        isLoadingPrompts = true
        clearPromptMessages()
        
        do {
            try await promptStore.updatePrompt(id: id, title: title, template: template)
            await loadSystemPrompts()
            promptSuccessMessage = "System prompt updated successfully"
            showingPromptEditor = false
            clearPromptMessagesAfterDelay()
        } catch {
            promptErrorMessage = error.localizedDescription
            clearPromptMessagesAfterDelay()
        }
        
        isLoadingPrompts = false
    }
    
    /// Delete a system prompt
    func deleteSystemPrompt(id: UUID) async {
        isLoadingPrompts = true
        clearPromptMessages()
        
        do {
            try await promptStore.deletePrompt(id: id)
            await loadSystemPrompts()
            promptSuccessMessage = "System prompt deleted successfully"
            clearPromptMessagesAfterDelay()
        } catch {
            promptErrorMessage = error.localizedDescription
            clearPromptMessagesAfterDelay()
        }
        
        isLoadingPrompts = false
    }
    
    /// Clear prompt messages
    private func clearPromptMessages() {
        promptErrorMessage = nil
        promptSuccessMessage = nil
    }
    
    /// Clear prompt messages after a delay
    private func clearPromptMessagesAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.clearPromptMessages()
        }
    }
    
    // MARK: - Default System Prompt Management
    
    /// Load default system prompt IDs from UserDefaults
    func loadDefaultSystemPromptIds() {
        AppLog("Loading default system prompt IDs from UserDefaults", level: .debug, category: "Prompts")
        // Load individual action prompts
        for action in 1...3 {
            let key = "userSelectedPrompt\(action)"
            if let storedId = UserDefaults.standard.string(forKey: key) {
                defaultSystemPromptIds[action - 1] = storedId
                AppLog("Loaded \(key): \(storedId)", level: .debug, category: "Prompts")
            } else {
                defaultSystemPromptIds[action - 1] = nil
                AppLog("No stored value for \(key)", level: .debug, category: "Prompts")
            }
        }
        AppLog("Final loaded defaultSystemPromptIds: \(defaultSystemPromptIds)", level: .debug, category: "Prompts")
    }
    
    /// Save default system prompt IDs to UserDefaults
    func saveDefaultSystemPromptIds() {
        AppLog("Saving default system prompt IDs: \(defaultSystemPromptIds)", level: .debug, category: "Prompts")
        for action in 1...3 {
            let key = "userSelectedPrompt\(action)"
            if let id = defaultSystemPromptIds[action - 1] {
                UserDefaults.standard.set(id, forKey: key)
                AppLog("Saved \(key): \(id)", level: .debug, category: "Prompts")
            } else {
                UserDefaults.standard.removeObject(forKey: key)
                AppLog("Removed \(key)", level: .debug, category: "Prompts")
            }
        }
        // Force synchronization to disk
        UserDefaults.standard.synchronize()
        AppLog("UserDefaults synchronized", level: .debug, category: "Prompts")
    }
    
    /// Get the default system prompt object for a specific action
    /// - Parameter action: Action number (1, 2, or 3)
    /// - Returns: The system prompt for the action, or nil if not set
    func getDefaultSystemPrompt(for action: Int) -> SystemPrompt? {
        guard action >= 1 && action <= 3 else { return nil }
        guard let defaultId = defaultSystemPromptIds[action - 1],
              let uuid = UUID(uuidString: defaultId) else { return nil }
        return systemPrompts.first { $0.id == uuid }
    }
    
    /// Get the default system prompt object (legacy method - uses Action 1)
    func getDefaultSystemPrompt() -> SystemPrompt? {
        return getDefaultSystemPrompt(for: 1)
    }
    
    /// Set the default system prompt ID for a specific action
    /// - Parameters:
    ///   - promptId: The prompt ID to set, or nil to clear
    ///   - action: Action number (1, 2, or 3)
    func setDefaultSystemPrompt(_ promptId: UUID?, for action: Int) {
        guard action >= 1 && action <= 3 else { return }
        let promptIdString = promptId?.uuidString
        AppLog("Setting default system prompt for action \(action): \(promptIdString ?? "nil")", level: .info, category: "Prompts")
        defaultSystemPromptIds[action - 1] = promptIdString
        AppLog("Updated defaultSystemPromptIds: \(defaultSystemPromptIds)", level: .debug, category: "Prompts")
        // Explicitly call save since didSet might not trigger for array element changes
        saveDefaultSystemPromptIds()
    }

    
    
    // MARK: - Private Methods
    
    /// Load the key status for all providers
    private func loadProviderKeyStatus() {
        providerKeyStatus.removeAll()
        
        for provider in availableProviders {
            do {
                providerKeyStatus[provider.id] = try keychainService.hasAPIKey(for: provider.id)
            } catch {
                providerKeyStatus[provider.id] = false
            }
        }
    }
    
    /// Get the list of available providers
    private static func getAvailableProviders() -> [ProviderInfo] {
        return [
            ProviderInfo(
                id: "openai",
                displayName: "OpenAI GPT",
                description: "Access to GPT models from OpenAI",
                keyFormat: "sk-...  (starts with 'sk-')",
                websiteURL: "https://platform.openai.com/api-keys"
            ),
            ProviderInfo(
                id: "gemini",
                displayName: "Google Gemini",
                description: "Access to Gemini Pro models from Google AI",
                keyFormat: "AI...  (starts with 'AI')",
                websiteURL: "https://makersuite.google.com/app/apikey"
            )
            // ProviderInfo(
            //     id: "claude",
            //     displayName: "Anthropic Claude",
            //     description: "Access to Claude models from Anthropic",
            //     keyFormat: "sk-ant-...  (starts with 'sk-ant-')",
            //     websiteURL: "https://console.anthropic.com/account/keys"
            // )
        ]
    }
    
    /// Create a temporary provider instance for testing (without registering)
    private func createTempProvider(id: String, apiKey: String) throws -> LLMProvider {
        switch id {
        case "openai":
            return MacPawOpenAIProvider(apiKey: apiKey)
        case "gemini":
            return GeminiProvider(apiKey: apiKey)
        case "claude":
            // TODO: Implement ClaudeProvider when available
            throw LLMError.serviceUnavailable(provider: id)
        default:
            throw LLMError.invalidResponse(
                provider: id,
                details: "Unknown provider ID: \(id)"
            )
        }
    }
    
    /// Get display name for a model
    private func getDisplayName(for modelId: String, providerId: String) -> String {
        switch providerId {
        case "openai":
            return MacPawOpenAIProvider.displayName(for: modelId)
        case "gemini":
            return GeminiProvider.displayName(for: modelId)
        default:
            return modelId.capitalized
        }
    }
    
    /// Get description for a model
    private func getModelDescription(for modelId: String, providerId: String) -> String? {
        switch providerId {
        case "openai":
            switch modelId {
            case "gpt-4o":
                return "Most advanced GPT-4 model with improved capabilities"
            case "gpt-4-turbo":
                return "Fast and powerful GPT-4 with 128k context window"
            case "gpt-3.5-turbo":
                return "Fast and cost-effective model for most tasks"
            case "gpt-4":
                return "Original GPT-4 model with strong reasoning"
            default:
                return nil
            }
        case "gemini":
            switch modelId {
            case "gemini-2.5-pro":
                return "Google's most advanced model with 2M token context"
            case "gemini-2.5-flash":
                return "Ultra-fast model with excellent performance and 1M token context"
            case "gemini-2.5-flash-lite":
                return "Lightweight version of 2.5 Flash for fast inference"
            case "gemini-2.0-flash":
                return "Latest generation model with multimodal capabilities"
            default:
                return nil
            }
        default:
            return nil
        }
    }
    
    /// Get maximum tokens for a model
    private func getMaxTokens(for modelId: String, providerId: String) -> Int? {
        switch providerId {
        case "openai":
            return MacPawOpenAIProvider.maxContextLength(for: modelId)
        case "gemini":
            return GeminiProvider.maxContextLength(for: modelId)
        default:
            return nil
        }
    }
    
    /// Get capabilities for a model
    private func getModelCapabilities(for modelId: String, providerId: String) -> [String] {
        var capabilities: [String] = []
        
        switch providerId {
        case "openai":
            if MacPawOpenAIProvider.supportsFunctionCalling(model: modelId) {
                capabilities.append("Function Calling")
            }
            capabilities.append("Text Generation")
        case "gemini":
            if GeminiProvider.supportsFunctionCalling(model: modelId) {
                capabilities.append("Function Calling")
            }
            if GeminiProvider.supportsVision(model: modelId) {
                capabilities.append("Vision")
            }
            capabilities.append("Text Generation")
        default:
            capabilities.append("Text Generation")
        }
        
        return capabilities
    }
}
