import Foundation

/// Protocol defining the interface for Large Language Model providers
/// This abstraction allows the app to support multiple LLM services (OpenAI, Gemini, Claude, etc.)
protocol LLMProvider {
    /// Unique identifier for the provider (e.g., "openai", "gemini", "claude")
    var id: String { get }
    
    /// Human-readable display name for the provider (e.g., "OpenAI GPT", "Google Gemini", "Anthropic Claude")
    var displayName: String { get }
    
    /// Sends a prompt to the LLM provider and returns the response
    /// - Parameters:
    ///   - prompt: The text prompt to send to the LLM
    ///   - systemPrompt: Optional system prompt to provide context/instructions
    ///   - model: Optional model identifier (provider-specific)
    /// - Returns: The LLM's text response
    /// - Throws: LLMError for various failure cases (network, quota, invalid key, etc.)
    func send(
        prompt: String,
        systemPrompt: String?,
        model: String?
    ) async throws -> String
    
    /// Validates whether the provider is properly configured and ready for use
    /// - Returns: true if the provider has valid credentials and can make requests
    func isConfigured() async -> Bool
    
    /// Returns the available models for this provider
    /// - Returns: Array of model identifiers supported by this provider
    func availableModels() -> [String]
}

/// Extension providing default implementations for optional functionality
extension LLMProvider {
    /// Default implementation returns empty array - providers can override
    func availableModels() -> [String] {
        return []
    }
    
    /// Convenience method for sending prompts without system prompt or model specification
    func send(prompt: String) async throws -> String {
        return try await send(prompt: prompt, systemPrompt: nil, model: nil)
    }
    
    /// Convenience method for sending prompts with system prompt but default model
    func send(prompt: String, systemPrompt: String) async throws -> String {
        return try await send(prompt: prompt, systemPrompt: systemPrompt, model: nil)
    }
}