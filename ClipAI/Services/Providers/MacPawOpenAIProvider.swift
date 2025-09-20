//
//  MacPawOpenAIProvider.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import Foundation
import OpenAI

/// Concrete implementation of LLMProvider using MacPaw/OpenAI SDK
/// Supports OpenAI GPT models with configurable model selection and comprehensive error handling
class MacPawOpenAIProvider: LLMProvider {
    
    // MARK: - Properties
    
    /// OpenAI client instance
    private let client: OpenAI
    
    /// Default model to use when none is specified
    private let defaultModel: Model
    
    /// Provider configuration
    private let configuration: Configuration
    
    // MARK: - LLMProvider Protocol Properties
    
    var id: String {
        return "openai"
    }
    
    var displayName: String {
        return "OpenAI GPT"
    }
    
    // MARK: - Configuration
    
    struct Configuration {
        let apiKey: String
        let defaultModel: Model
        let organizationId: String?
        let timeout: TimeInterval
        
        init(
            apiKey: String,
            defaultModel: Model = .gpt4_o,
            organizationId: String? = nil,
            timeout: TimeInterval = 120.0
        ) {
            self.apiKey = apiKey
            self.defaultModel = defaultModel
            self.organizationId = organizationId
            self.timeout = timeout
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize the provider with configuration
    /// - Parameter configuration: Provider configuration including API key and settings
    init(configuration: Configuration) {
        self.configuration = configuration
        self.defaultModel = configuration.defaultModel
        
        // Initialize OpenAI client with configuration
        let openAIConfig = OpenAI.Configuration(
            token: configuration.apiKey,
            organizationIdentifier: configuration.organizationId,
            timeoutInterval: configuration.timeout
        )
        
        self.client = OpenAI(configuration: openAIConfig)
    }
    
    /// Convenience initializer with just API key
    /// - Parameter apiKey: OpenAI API key
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
        let startTime = Date()
        // Validate inputs
        guard !prompt.isEmpty else {
            throw LLMError.invalidResponse(provider: id, details: "Empty prompt provided")
        }
        
        // Determine model to use
        let selectedModel = resolveModel(from: model)
        let systemChars = systemPrompt?.count ?? 0
        AppLogger.shared.info("LLM request started provider=\(id) model=\(selectedModel)", category: "LLM")
        AppLogger.shared.debug("LLM request input lengths provider=\(id) model=\(selectedModel) systemPromptChars=\(systemChars) promptChars=\(prompt.count)", category: "LLM")
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            AppLogger.shared.debug("SystemPrompt: \(summarizeForLog(systemPrompt))", category: "LLM")
        }
        AppLogger.shared.debug("Prompt: \(summarizeForLog(prompt))", category: "LLM")
        
        // Build messages array
        var messages: [ChatQuery.ChatCompletionMessageParam] = []
        
        // Add system prompt if provided
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
          messages.append(.system(.init(content: .textContent(systemPrompt))))
        }
        
        // Add user prompt
        messages.append(.user(.init(content: .string(prompt))))
        
        // Create chat query
        let query = ChatQuery(
            messages: messages,
            model: selectedModel,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0,
            temperature: 0.7, // Balanced creativity vs consistency
            topP: 1.0
        )
        
        do {
            // Send request to OpenAI
            let result = try await client.chats(query: query)
            
            // Extract response text
            guard let choice = result.choices.first,
                  let content = choice.message.content else {
                throw LLMError.invalidResponse(
                    provider: id,
                    details: "No response content received"
                )
            }
            
            let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
            AppLogger.shared.info("LLM request success provider=\(id) model=\(selectedModel) durationMs=\(elapsedMs) responseChars=\(content.count)", category: "LLM")
            AppLogger.shared.debug("Response preview: \(summarizeForLog(content))", category: "LLM")
            return content
            
        } catch {
            // Map OpenAI errors to LLMError
            let mapped = mapError(error)
            let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
            let desc = mapped.errorDescription ?? String(describing: mapped)
            let retryable = mapped.isRetryable ? "true" : "false"
            AppLogger.shared.error("LLM request failed provider=\(id) model=\(selectedModel) durationMs=\(elapsedMs) retryable=\(retryable) error=\(desc)", category: "LLM")
            throw mapped
        }
    }
    
    func isConfigured() async -> Bool {
        // Check if API key is present and valid by making a lightweight request
        do {
            _ = try await client.models()
            return true
        } catch {
            return false
        }
    }
    
    func availableModels() -> [String] {
        return [
          Model.gpt4_1_mini,
          Model.gpt4_1_nano,
          Model.gpt4_o_mini,
        ]
    }
    
    // MARK: - Private Helper Methods
    
    /// Resolves the model to use based on the provided string
    /// - Parameter modelString: Optional model identifier string
    /// - Returns: Model enum value to use
    private func resolveModel(from modelString: String?) -> Model {
        guard let modelString = modelString else {
            return defaultModel
        }
        
        // Map common model strings to Model enum
        switch modelString.lowercased() {
        case "gpt4_1_mini":
            return Model.gpt4_1_mini
        case "gpt4_1_nano":
            return Model.gpt4_1_nano
        case "gpt4_o_mini":
            return Model.gpt4_o_mini
        default:
            // Return the string directly since Model is a String typealias
            return modelString
        }
    }
    
    /// Maps OpenAI SDK errors to our unified LLMError enum
    /// - Parameter error: The error from OpenAI SDK
    /// - Returns: Mapped LLMError instance
    private func mapError(_ error: Error) -> LLMError {
        // Handle URLErrors (network issues)
        if let urlError = error as? URLError {
            let mapped = LLMError.fromURLError(urlError, provider: id)
            AppLogger.shared.warn("URLError mapped to LLMError provider=\(id) code=\(urlError.code.rawValue) description=\(mapped.errorDescription ?? "")", category: "LLM")
            return mapped
        }
        
        // Handle OpenAI-specific errors
        if let openAIError = error as? OpenAIError {
            let mapped = mapOpenAIError(openAIError)
            AppLogger.shared.warn("OpenAIError mapped to LLMError provider=\(id) description=\(mapped.errorDescription ?? "")", category: "LLM")
            return mapped
        }
      
        
        // Handle HTTP response errors if available
        if let nsError = error as NSError? {
            let statusCode = nsError.code
            if statusCode >= 400 && statusCode < 600 {
                let mapped = LLMError.fromHTTPStatus(statusCode, provider: id, data: nil)
                AppLogger.shared.warn("HTTP status error mapped to LLMError provider=\(id) status=\(statusCode) description=\(mapped.errorDescription ?? "")", category: "LLM")
                return mapped
            }
        }
        
        // Default to unknown error
        let mapped = LLMError.unknown(provider: id, underlyingError: error)
        AppLogger.shared.warn("Unknown error mapped to LLMError provider=\(id) description=\(mapped.errorDescription ?? "")", category: "LLM")
        return mapped
    }
    
    /// Maps specific OpenAI SDK errors to LLMError cases
    /// - Parameter error: OpenAI SDK error
    /// - Returns: Mapped LLMError instance
    private func mapOpenAIError(_ error: OpenAIError) -> LLMError {
        // For now, map generic OpenAI errors to unknown until we can determine the exact error structure
        return LLMError.unknown(provider: id, underlyingError: error)
    }
}

// MARK: - Model Helper Functions

extension MacPawOpenAIProvider {
    /// Returns human-readable description for a model
    /// - Parameter model: The model string
    /// - Returns: Display name for the model
    static func displayName(for model: Model) -> String {
        switch model {
        case Model.gpt4_o:
            return "GPT-4o"
        case Model.gpt4_turbo:
            return "GPT-4 Turbo"
        case Model.gpt3_5Turbo:
            return "GPT-3.5 Turbo"
        case Model.gpt4:
            return "GPT-4"
        case Model.gpt4_1106_preview:
            return "GPT-4 Turbo (1106)"
        case Model.gpt4_0125_preview:
            return "GPT-4 Turbo (0125)"
        default:
            return model
        }
    }
    
    /// Returns whether a model supports function calling
    /// - Parameter model: The model string
    /// - Returns: true if the model supports function calling
    static func supportsFunctionCalling(model: Model) -> Bool {
        switch model {
        case Model.gpt4_o, Model.gpt4_turbo, Model.gpt4, Model.gpt4_1106_preview, Model.gpt4_0125_preview:
            return true
        case Model.gpt3_5Turbo:
            return true
        default:
            return false
        }
    }
    
    /// Returns maximum context length for a model
    /// - Parameter model: The model string
    /// - Returns: Maximum context length in tokens
    static func maxContextLength(for model: Model) -> Int {
        switch model {
        case Model.gpt4_o:
            return 128000
        case Model.gpt4_turbo, Model.gpt4_1106_preview, Model.gpt4_0125_preview:
            return 128000
        case Model.gpt4:
            return 8192
        case Model.gpt3_5Turbo:
            return 16385
        default:
            return 4096 // Safe default
        }
    }
}

// MARK: - Logging Helpers

private extension MacPawOpenAIProvider {
    func summarizeForLog(_ text: String, limit: Int = 400) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: "\\n")
        if singleLine.count <= limit { return singleLine }
        let idx = singleLine.index(singleLine.startIndex, offsetBy: limit)
        let prefix = String(singleLine[..<idx])
        return prefix + "…(+\(singleLine.count - limit) chars)"
    }
}
