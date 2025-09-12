//
//  LLMProviderRegistry.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import Foundation

/// Centralized registry for managing multiple LLM providers and their availability
/// Handles provider registration, availability checking, and default provider selection
class LLMProviderRegistry {
    
    // MARK: - Properties
    
    /// Singleton instance for app-wide access
    static let shared = LLMProviderRegistry()
    
    /// Keychain service for API key management
    private let keychainService: KeychainService
    
    /// Dictionary of registered providers by their ID
    private var providers: [String: LLMProvider] = [:]
    
    /// Array of provider IDs in preferred order for default selection
    private let providerPriority: [String] = ["openai", "gemini", "claude"]

    /// UserDefaults key for storing user-selected default provider
    private let defaultProviderIdKey: String = "defaultProviderId"
    
    // MARK: - Initialization
    
    /// Private initializer for singleton pattern
    private init() {
        self.keychainService = KeychainService()
        registerDefaultProviders()
    }
    
    /// Initialize with custom keychain service (for testing)
    /// - Parameter keychainService: Custom keychain service instance
    init(keychainService: KeychainService) {
        self.keychainService = keychainService
        registerDefaultProviders()
    }
    
    // MARK: - Provider Registration
    
    /// Register the default providers that ship with the app
    private func registerDefaultProviders() {
        // Note: Providers will be instantiated lazily when API keys are available
        // This avoids creating provider instances without valid configuration
    }
    
    /// Register a custom provider
    /// - Parameter provider: The provider instance to register
    /// - Throws: LLMError if provider ID conflicts with existing provider
    func register(provider: LLMProvider) throws {
        guard providers[provider.id] == nil else {
            throw LLMError.invalidResponse(
                provider: provider.id,
                details: "Provider with ID '\(provider.id)' is already registered"
            )
        }
        
        providers[provider.id] = provider
    }
    
    /// Unregister a provider
    /// - Parameter providerId: The ID of the provider to unregister
    func unregister(providerId: String) {
        providers.removeValue(forKey: providerId)
    }
    
    // MARK: - Provider Access
    
    /// Get all registered provider IDs
    /// - Returns: Array of provider IDs
    func getAllProviderIds() -> [String] {
        return Array(providers.keys).sorted()
    }
    
    /// Get all registered providers
    /// - Returns: Array of provider instances
    func getAllProviders() -> [LLMProvider] {
        return Array(providers.values)
    }
    
    /// Get a specific provider by ID
    /// - Parameter id: The provider ID
    /// - Returns: Provider instance if found, nil otherwise
    func getProvider(id: String) -> LLMProvider? {
        return providers[id]
    }
    
    /// Get provider display name by ID
    /// - Parameter id: The provider ID
    /// - Returns: Display name if provider exists, nil otherwise
    func getProviderDisplayName(id: String) -> String? {
        return providers[id]?.displayName
    }
    
    // MARK: - Provider Availability
    
    /// Check if a provider is available (has valid API key and is configured)
    /// - Parameter providerId: The provider ID to check
    /// - Returns: True if provider is available and configured
    func isProviderAvailable(_ providerId: String) async -> Bool {
        // First check if we have an API key
        guard hasAPIKey(for: providerId) else {
            return false
        }
        
        // Get or create provider instance
        guard let provider = await getOrCreateProvider(id: providerId) else {
            return false
        }
        
        // Check if provider is properly configured
        return await provider.isConfigured()
    }
    
    /// Get all available (configured) providers
    /// - Returns: Array of provider IDs that are available
    func getAvailableProviderIds() async -> [String] {
        var availableIds: [String] = []
        
        for providerId in getAllKnownProviderIds() {
            if await isProviderAvailable(providerId) {
                availableIds.append(providerId)
            }
        }
        
        return availableIds
    }
    
    /// Get all available (configured) providers with their display names
    /// - Returns: Dictionary mapping provider ID to display name
    func getAvailableProvidersWithNames() async -> [String: String] {
        var availableProviders: [String: String] = [:]
        
        for providerId in await getAvailableProviderIds() {
            if let provider = await getOrCreateProvider(id: providerId) {
                availableProviders[providerId] = provider.displayName
            }
        }
        
        return availableProviders
    }
    
    // MARK: - Default Provider Selection
    
    /// Get the default provider based on availability and priority
    /// - Returns: Provider ID of the default provider, nil if none available
    func getDefaultProviderId() async -> String? {
        // Do not perform network checks; return the user-selected default if present
        return UserDefaults.standard.string(forKey: defaultProviderIdKey)
    }
    
    /// Get the default provider instance
    /// - Returns: Default provider instance, nil if none available
    func getDefaultProvider() async -> LLMProvider? {
        guard let defaultId = await getDefaultProviderId() else {
            return nil
        }
        
        return await getOrCreateProvider(id: defaultId)
    }

    /// Persist the user-selected default provider ID (set to nil to clear)
    func setDefaultProviderId(_ id: String?) {
        if let id = id {
            UserDefaults.standard.set(id, forKey: defaultProviderIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultProviderIdKey)
        }
    }
    
    // MARK: - Provider Capability Detection
    
    /// Get available models for a specific provider
    /// - Parameter providerId: The provider ID
    /// - Returns: Array of model identifiers, empty if provider not available
    func getAvailableModels(for providerId: String) async -> [String] {
        guard let provider = await getOrCreateProvider(id: providerId) else {
            return []
        }
        
        return provider.availableModels()
    }
    
    /// Get capabilities summary for all available providers
    /// - Returns: Dictionary mapping provider ID to model count
    func getProviderCapabilities() async -> [String: Int] {
        var capabilities: [String: Int] = [:]
        
        for providerId in await getAvailableProviderIds() {
            let models = await getAvailableModels(for: providerId)
            capabilities[providerId] = models.count
        }
        
        return capabilities
    }
    
    // MARK: - API Key Management Integration
    
    /// Check if API key exists for a provider
    /// - Parameter providerId: The provider ID
    /// - Returns: True if API key exists in keychain
    private func hasAPIKey(for providerId: String) -> Bool {
        do {
            return try keychainService.hasAPIKey(for: providerId)
        } catch {
            return false
        }
    }
    
    /// Get or create a provider instance with API key from keychain
    /// - Parameter id: The provider ID
    /// - Returns: Provider instance if successful, nil otherwise
    private func getOrCreateProvider(id: String) async -> LLMProvider? {
        // Return existing provider if already created
        if let existingProvider = providers[id] {
            return existingProvider
        }
        
        // Try to create new provider instance with API key
        do {
            guard let apiKey = try keychainService.retrieveAPIKey(for: id), !apiKey.isEmpty else {
                return nil
            }
            let provider = try createProvider(id: id, apiKey: apiKey)
            providers[id] = provider
            return provider
        } catch {
            return nil
        }
    }
    
    /// Create a provider instance for a given ID and API key
    /// - Parameters:
    ///   - id: The provider ID
    ///   - apiKey: The API key for the provider
    /// - Returns: Provider instance
    /// - Throws: LLMError if provider ID is not supported
    private func createProvider(id: String, apiKey: String) throws -> LLMProvider {
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
    
    /// Get all known provider IDs (including those not yet implemented)
    /// - Returns: Array of all known provider IDs
    private func getAllKnownProviderIds() -> [String] {
        return ["openai", "gemini", "claude"]
    }
    
    // MARK: - Provider Management
    
    /// Refresh provider availability (useful when API keys change)
    func refreshProviderAvailability() {
        // Clear cached provider instances to force re-creation with new API keys
        providers.removeAll()
    }
    
    /// Get provider status information for debugging/monitoring
    /// - Returns: Dictionary with provider status information
    func getProviderStatus() async -> [String: [String: Any]] {
        var status: [String: [String: Any]] = [:]
        
        for providerId in getAllKnownProviderIds() {
            let hasKey = hasAPIKey(for: providerId)
            let isAvailable = await isProviderAvailable(providerId)
            let modelCount = await getAvailableModels(for: providerId).count
            
            status[providerId] = [
                "hasAPIKey": hasKey,
                "isAvailable": isAvailable,
                "modelCount": modelCount,
                "displayName": getProviderDisplayName(id: providerId) ?? "Unknown"
            ]
        }
        
        return status
    }
}

// MARK: - Provider Registry Extensions

extension LLMProviderRegistry {
    
    /// Convenience method to send a request using the default provider
    /// - Parameters:
    ///   - prompt: The text prompt to send
    ///   - systemPrompt: Optional system prompt
    ///   - model: Optional model specification (if nil, uses selected model from settings)
    /// - Returns: LLM response text
    /// - Throws: LLMError if no providers available or request fails
    func sendWithDefaultProvider(
        prompt: String,
        systemPrompt: String? = nil,
        model: String? = nil
    ) async throws -> String {
        guard let defaultProviderId = await getDefaultProviderId(),
              let provider = await getDefaultProvider() else {
            throw LLMError.serviceUnavailable(provider: "Registry")
        }
        
        let selectedModel = model ?? getSelectedModel(for: defaultProviderId)
        
        return try await provider.send(
            prompt: prompt,
            systemPrompt: systemPrompt,
            model: selectedModel
        )
    }
    
    /// Convenience method to send a request using a specific provider
    /// - Parameters:
    ///   - providerId: The provider ID to use
    ///   - prompt: The text prompt to send
    ///   - systemPrompt: Optional system prompt
    ///   - model: Optional model specification (if nil, uses selected model from settings)
    /// - Returns: LLM response text
    /// - Throws: LLMError if provider not available or request fails
    func sendWithProvider(
        _ providerId: String,
        prompt: String,
        systemPrompt: String? = nil,
        model: String? = nil
    ) async throws -> String {
        guard let provider = await getOrCreateProvider(id: providerId) else {
            throw LLMError.serviceUnavailable(provider: providerId)
        }
        
        let selectedModel = model ?? getSelectedModel(for: providerId)
        
        return try await provider.send(
            prompt: prompt,
            systemPrompt: systemPrompt,
            model: selectedModel
        )
    }
    
    /// Get the selected model for a provider from user settings
    /// - Parameter providerId: The provider ID
    /// - Returns: Selected model ID if available, nil otherwise
    private func getSelectedModel(for providerId: String) -> String? {
        let selectedModels = UserDefaults.standard.dictionary(forKey: "selectedModels") as? [String: String] ?? [:]
        return selectedModels[providerId]
    }
}