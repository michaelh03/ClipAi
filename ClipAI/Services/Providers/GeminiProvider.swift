//
//  GeminiProvider.swift  
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import Foundation
import OpenAI

/// Concrete implementation of LLMProvider using MacPaw/OpenAI SDK configured for Google Gemini API
/// Supports Gemini Pro models with custom host configuration and comprehensive error handling
class GeminiProvider: LLMProvider {
    
    // MARK: - Properties
    
    /// OpenAI client instance configured for Gemini API
    private let client: OpenAI
    
    /// Default model to use when none is specified
    private let defaultModel: String
    
    /// Provider configuration
    private let configuration: Configuration
    
    // MARK: - LLMProvider Protocol Properties
    
    var id: String {
        return "gemini"
    }
    
    var displayName: String {
        return "Google Gemini"
    }
    
    // MARK: - Configuration
    
    struct Configuration {
        let apiKey: String
        let defaultModel: String
        let timeout: TimeInterval
        let host: String
        let basePath: String
        
        init(
            apiKey: String,
            defaultModel: String = "gemini-2.0-flash",
            timeout: TimeInterval = 120.0,
            host: String = "generativelanguage.googleapis.com",
            basePath: String = "/v1beta"
        ) {
            self.apiKey = apiKey
            self.defaultModel = defaultModel
            self.timeout = timeout
            self.host = host
            self.basePath = basePath
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize the provider with configuration
    /// - Parameter configuration: Provider configuration including API key and settings
    init(configuration: Configuration) {
        self.configuration = configuration
        self.defaultModel = configuration.defaultModel
        
        // Initialize OpenAI client with custom configuration for Gemini API
        let openAIConfig = OpenAI.Configuration(
            token: configuration.apiKey,
            organizationIdentifier: nil,
            host: configuration.host,
            scheme: "https",
            basePath: configuration.basePath,
            timeoutInterval: configuration.timeout
        )
        
        self.client = OpenAI(configuration: openAIConfig)
    }
    
    /// Convenience initializer with just API key
    /// - Parameter apiKey: Google AI API key
    convenience init(apiKey: String) {
        let config = Configuration(apiKey: apiKey)
        self.init(configuration: config)
    }
    
    // MARK: - LLMProvider Protocol Methods
    
    func send(
        prompt: String,
        systemPrompt: String? = nil,
        model: String? = nil
    ) async throws -> String {
        
        // Validate inputs
        guard !prompt.isEmpty else {
            throw LLMError.invalidResponse(provider: id, details: "Empty prompt provided")
        }
        
        // Determine model to use
        let selectedModel = resolveModel(from: model)
        
        // Build messages array
        var messages: [ChatQuery.ChatCompletionMessageParam] = []
        
        // Add system prompt if provided
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append(.system(.init(content: .textContent(systemPrompt))))
        }
        
        // Add user prompt
        messages.append(.user(.init(content: .string(prompt))))
        
        // Create chat query with Gemini-specific parameters
        let query = ChatQuery(
            messages: messages,
            model: selectedModel,
            frequencyPenalty: nil, // Gemini doesn't support frequency penalty
            presencePenalty: nil,  // Gemini doesn't support presence penalty
            temperature: 0.7,      // Balanced creativity vs consistency
            topP: 0.9             // Slightly more focused than OpenAI default
        )
        
        do {
            // Send request to Gemini API via OpenAI SDK
            let result = try await client.chats(query: query)
            
            // Extract response text
            guard let choice = result.choices.first,
                  let content = choice.message.content else {
                throw LLMError.invalidResponse(
                    provider: id,
                    details: "No response content received"
                )
            }
            
            return content
            
        } catch {
            // Map errors to LLMError
            throw mapError(error)
        }
    }
    
    func isConfigured() async -> Bool {
        // Check if API key is present and valid by making a lightweight request
        do {
            // Try to make a simple request to verify the API key
            let testQuery = ChatQuery(
                messages: [.user(.init(content: .string("Hi")))],
                model: defaultModel
            )
            _ = try await client.chats(query: testQuery)
            return true
        } catch {
            return false
        }
    }
    
    func availableModels() -> [String] {
        return [
            "gemini-2.5-pro",
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite",
            "gemini-2.0-flash",
        ]
    }
    
    // MARK: - Private Helper Methods
    
    /// Resolves the model to use based on the provided string
    /// - Parameter modelString: Optional model identifier string
    /// - Returns: Model string to use
    private func resolveModel(from modelString: String?) -> String {
        guard let modelString = modelString else {
            return defaultModel
        }
        
        // Map common model strings to Gemini model names
        switch modelString.lowercased() {
        case "gemini-2.5-pro":
            return "gemini-2.5-pro"
        case "gemini-2.5-flash":
            return "gemini-2.5-flash"
        case "gemini-2.5-flash-lite":
            return "gemini-2.5-flash-lite"
        case "gemini-2.0-flash":
            return "gemini-2.0-flash"
        default:
            // Return the string directly if it's a valid Gemini model
            return "gemini-2.0-flash"
        }
    }
    
    /// Maps errors to our unified LLMError enum
    /// - Parameter error: The error from the API call
    /// - Returns: Mapped LLMError instance
    private func mapError(_ error: Error) -> LLMError {
        // Handle URLErrors (network issues)
        if let urlError = error as? URLError {
            return LLMError.fromURLError(urlError, provider: id)
        }
        
        // Handle OpenAI SDK errors (which includes Gemini API errors)
        if let openAIError = error as? OpenAIError {
            return mapGeminiError(openAIError)
        }
        
        // Handle HTTP response errors if available
        if let nsError = error as NSError? {
            let statusCode = nsError.code
            if statusCode >= 400 && statusCode < 600 {
                return mapGeminiHTTPError(statusCode, nsError: nsError)
            }
        }
        
        // Default to unknown error
        return LLMError.unknown(provider: id, underlyingError: error)
    }
    
    /// Maps specific OpenAI SDK errors to LLMError cases for Gemini
    /// - Parameter error: OpenAI SDK error
    /// - Returns: Mapped LLMError instance
    private func mapGeminiError(_ error: OpenAIError) -> LLMError {
        // Map generic OpenAI errors to appropriate Gemini errors
        return LLMError.unknown(provider: id, underlyingError: error)
    }
    
    /// Maps HTTP status codes specific to Gemini API errors
    /// - Parameters:
    ///   - statusCode: HTTP status code
    ///   - nsError: NSError containing additional information
    /// - Returns: Mapped LLMError instance
    private func mapGeminiHTTPError(_ statusCode: Int, nsError: NSError) -> LLMError {
        switch statusCode {
        case 400:
            // Gemini-specific 400 errors
            let userInfo = nsError.userInfo
            if let errorMessage = userInfo[NSLocalizedDescriptionKey] as? String {
                if errorMessage.lowercased().contains("safety") || errorMessage.lowercased().contains("blocked") {
                    return .contentFiltered(provider: id, reason: "Content blocked by Gemini safety filters")
                } else if errorMessage.lowercased().contains("token") || errorMessage.lowercased().contains("length") {
                    return .tokenLimitExceeded(provider: id, maxTokens: getMaxTokensForModel(defaultModel))
                }
            }
            return .invalidResponse(provider: id, details: "Bad Request - Invalid input format")
            
        case 401:
            return .invalidKey(provider: id)
            
        case 403:
            // Gemini API quota exceeded or access denied
            return .quotaExceeded(provider: id)
            
        case 429:
            // Rate limiting
            let retryAfter = extractRetryAfter(from: nsError)
            return .rateLimited(provider: id, retryAfter: retryAfter)
            
        case 500, 502, 503, 504:
            return .serviceUnavailable(provider: id)
            
        default:
            return LLMError.fromHTTPStatus(statusCode, provider: id, data: nil)
        }
    }
    
    /// Extracts retry-after value from error if available
    /// - Parameter error: NSError containing HTTP response information
    /// - Returns: Retry after interval in seconds, if available
    private func extractRetryAfter(from error: NSError) -> TimeInterval? {
        // Try to extract retry-after from error userInfo
        if let retryAfterString = error.userInfo["Retry-After"] as? String,
           let retryAfter = TimeInterval(retryAfterString) {
            return retryAfter
        }
        return nil
    }
    
    /// Returns maximum tokens for a given Gemini model
    /// - Parameter model: Model identifier
    /// - Returns: Maximum context length in tokens
    private func getMaxTokensForModel(_ model: String) -> Int {
        switch model {
        case "gemini-2.5-pro":
            return 2097152  // 2M tokens
        case "gemini-2.5-flash":
            return 1048576  // 1M tokens
        case "gemini-2.5-flash-lite":
            return 1048576  // 1M tokens
        case "gemini-2.0-flash":
            return 1048576  // 1M tokens
        default:
            return 1048576    // Safe default for newer models
        }
    }
}

// MARK: - Model Helper Functions

extension GeminiProvider {
    /// Returns human-readable description for a Gemini model
    /// - Parameter model: The model string
    /// - Returns: Display name for the model
    static func displayName(for model: String) -> String {
        switch model {
        case "gemini-2.5-pro":
            return "Gemini 2.5 Pro"
        case "gemini-2.5-flash":
            return "Gemini 2.5 Flash"
        case "gemini-2.5-flash-lite":
            return "Gemini 2.5 Flash Lite"
        case "gemini-2.0-flash":
            return "Gemini 2.0 Flash"
        default:
            return model.capitalized
        }
    }
    
    /// Returns whether a model supports vision/image inputs
    /// - Parameter model: The model string
    /// - Returns: true if the model supports vision
    static func supportsVision(model: String) -> Bool {
        switch model {
        case "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash":
            return true
        default:
            return false
        }
    }
    
    /// Returns maximum context length for a model
    /// - Parameter model: The model string
    /// - Returns: Maximum context length in tokens
    static func maxContextLength(for model: String) -> Int {
        switch model {
        case "gemini-2.5-pro":
            return 2097152  // 2M tokens
        case "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash":
            return 1048576  // 1M tokens
        default:
            return 1048576    // Safe default for newer models
        }
    }
    
    /// Returns whether a model supports function calling
    /// - Parameter model: The model string
    /// - Returns: true if the model supports function calling
    static func supportsFunctionCalling(model: String) -> Bool {
        switch model {
        case "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash":
            return true
        default:
            return true  // Most newer models support function calling
        }
    }
}
