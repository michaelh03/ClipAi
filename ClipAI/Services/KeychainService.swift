//
//  KeychainService.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import Foundation
import KeychainSwift

/// Service for secure storage and retrieval of API keys using Keychain
/// Provides provider-specific key management with validation and error handling
class KeychainService {
    
    // MARK: - Properties
    
    /// KeychainSwift instance for secure storage
    private let keychain: KeychainSwift
    
    /// Prefix for all keychain keys to avoid conflicts
    private let servicePrefix: String = "com.clipai.llm.apikey"
    
    // MARK: - Initialization
    
    /// Initialize the keychain service
    init() {
        self.keychain = KeychainSwift()
        
        // Configure keychain for optimal security
        keychain.synchronizable = false // Don't sync across devices for API keys
        keychain.accessGroup = nil // Use default access group
    }
    
    // MARK: - Public Methods
    
    /// Store an API key for a specific provider
    /// - Parameters:
    ///   - apiKey: The API key to store
    ///   - providerId: Unique identifier for the provider (e.g., "openai", "gemini")
    /// - Throws: LLMError for validation or storage failures
    func storeAPIKey(_ apiKey: String, for providerId: String) throws {
        // Validate inputs
        try validateProviderId(providerId)
        try validateAPIKey(apiKey, for: providerId)
        
        let keychainKey = makeKeychainKey(for: providerId)
        
        // Store in keychain
        let success = keychain.set(apiKey, forKey: keychainKey)
        
        if !success {
            throw LLMError.unknown(
                provider: providerId,
                underlyingError: KeychainError.storageFailure
            )
        }
    }
    
    /// Retrieve an API key for a specific provider
    /// - Parameter providerId: Unique identifier for the provider
    /// - Returns: The stored API key, or nil if not found
    /// - Throws: LLMError for validation failures
    func retrieveAPIKey(for providerId: String) throws -> String? {
        try validateProviderId(providerId)
        
        let keychainKey = makeKeychainKey(for: providerId)
        return keychain.get(keychainKey)
    }
    
    /// Remove an API key for a specific provider
    /// - Parameter providerId: Unique identifier for the provider
    /// - Throws: LLMError for validation failures
    func removeAPIKey(for providerId: String) throws {
        try validateProviderId(providerId)
        
        let keychainKey = makeKeychainKey(for: providerId)
        
        let success = keychain.delete(keychainKey)
        
        if !success {
            throw LLMError.unknown(
                provider: providerId,
                underlyingError: KeychainError.deletionFailure
            )
        }
    }
    
    /// Check if an API key exists for a specific provider
    /// - Parameter providerId: Unique identifier for the provider
    /// - Returns: true if an API key is stored for the provider
    /// - Throws: LLMError for validation failures
    func hasAPIKey(for providerId: String) throws -> Bool {
        let apiKey = try retrieveAPIKey(for: providerId)
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    /// Get all provider IDs that have stored API keys
    /// - Returns: Array of provider IDs that have API keys stored
    func getProvidersWithAPIKeys() -> [String] {
        let allKeys = keychain.allKeys
        let prefixWithDot = servicePrefix + "."
        
        return allKeys.compactMap { key in
            if key.hasPrefix(prefixWithDot) {
                return String(key.dropFirst(prefixWithDot.count))
            }
            return nil
        }
    }
    
    /// Validate that a stored API key is still valid format-wise
    /// - Parameter providerId: Unique identifier for the provider
    /// - Returns: true if the stored key appears to be valid
    /// - Throws: LLMError for validation or retrieval failures
    func validateStoredAPIKey(for providerId: String) throws -> Bool {
        guard let apiKey = try retrieveAPIKey(for: providerId) else {
            return false
        }
        
        do {
            try validateAPIKey(apiKey, for: providerId)
            return true
        } catch {
            return false
        }
    }

    /// Validate API key format without storing it.
    /// - Parameters:
    ///   - apiKey: API key to validate.
    ///   - providerId: Provider identifier for context.
    /// - Throws: LLMError.invalidKey or other validation errors.
    func validateAPIKeyFormat(_ apiKey: String, for providerId: String) throws {
        // We only need to run the internal validation helpers; this will not persist the key.
        try validateProviderId(providerId)
        try validateAPIKey(apiKey, for: providerId)
    }
    
    /// Clear all stored API keys (use with caution)
    /// - Throws: LLMError if clearing fails
    func clearAllAPIKeys() throws {
        let providersWithKeys = getProvidersWithAPIKeys()
        
        for providerId in providersWithKeys {
            try removeAPIKey(for: providerId)
        }
    }
    
    // MARK: - Private Methods
    
    /// Create a keychain key for a specific provider
    /// - Parameter providerId: Provider identifier
    /// - Returns: Formatted keychain key
    private func makeKeychainKey(for providerId: String) -> String {
        return "\(servicePrefix).\(providerId)"
    }
    
    /// Validate provider ID format
    /// - Parameter providerId: Provider identifier to validate
    /// - Throws: LLMError.invalidResponse for invalid provider IDs
    private func validateProviderId(_ providerId: String) throws {
        guard !providerId.isEmpty else {
            throw LLMError.invalidResponse(
                provider: "keychain",
                details: "Provider ID cannot be empty"
            )
        }
        
        // Provider ID should be alphanumeric and may contain dashes/underscores
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard providerId.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            throw LLMError.invalidResponse(
                provider: "keychain",
                details: "Provider ID contains invalid characters: \(providerId)"
            )
        }
        
        // Reasonable length limits
        guard providerId.count <= 50 else {
            throw LLMError.invalidResponse(
                provider: "keychain",
                details: "Provider ID too long: \(providerId)"
            )
        }
    }
    
    /// Validate API key format based on provider
    /// - Parameters:
    ///   - apiKey: API key to validate
    ///   - providerId: Provider identifier for context
    /// - Throws: LLMError.invalidKey for invalid API keys
    private func validateAPIKey(_ apiKey: String, for providerId: String) throws {
        guard !apiKey.isEmpty else {
            throw LLMError.invalidKey(provider: providerId)
        }
        
        // Remove whitespace for validation
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw LLMError.invalidKey(provider: providerId)
        }
        
        // Provider-specific validation
        switch providerId.lowercased() {
        case "openai":
            try validateOpenAIKey(trimmedKey, providerId: providerId)
        case "gemini", "google":
            try validateGeminiKey(trimmedKey, providerId: providerId)
        case "claude", "anthropic":
            try validateClaudeKey(trimmedKey, providerId: providerId)
        default:
            // Generic validation for unknown providers
            try validateGenericKey(trimmedKey, providerId: providerId)
        }
    }
    
    /// Validate OpenAI API key format
    private func validateOpenAIKey(_ apiKey: String, providerId: String) throws {
        // OpenAI keys typically start with "sk-" and are about 51 characters
        guard apiKey.hasPrefix("sk-") else {
            throw LLMError.invalidKey(provider: providerId)
        }
    }
    
    /// Validate Google Gemini API key format
    private func validateGeminiKey(_ apiKey: String, providerId: String) throws {
        // Gemini keys are typically 39 characters of alphanumeric + hyphens/underscores
        guard apiKey.count >= 20 && apiKey.count <= 100 else {
            throw LLMError.invalidKey(provider: providerId)
        }
        
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard apiKey.rangeOfCharacter(from: allowedChars.inverted) == nil else {
            throw LLMError.invalidKey(provider: providerId)
        }
    }
    
    /// Validate Anthropic Claude API key format
    private func validateClaudeKey(_ apiKey: String, providerId: String) throws {
        // Claude keys typically start with "sk-ant-" 
        guard apiKey.hasPrefix("sk-ant-") else {
            throw LLMError.invalidKey(provider: providerId)
        }
        
        guard apiKey.count >= 20 && apiKey.count <= 150 else {
            throw LLMError.invalidKey(provider: providerId)
        }
        
        let keyPart = String(apiKey.dropFirst(7)) // Remove "sk-ant-"
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard keyPart.rangeOfCharacter(from: allowedChars.inverted) == nil else {
            throw LLMError.invalidKey(provider: providerId)
        }
    }
    
    /// Generic API key validation for unknown providers
    private func validateGenericKey(_ apiKey: String, providerId: String) throws {
        // Generic validation: reasonable length and printable characters
        guard apiKey.count >= 10 && apiKey.count <= 200 else {
            throw LLMError.invalidKey(provider: providerId)
        }
        
        // Should contain only printable ASCII characters
        guard apiKey.allSatisfy({ $0.isASCII && !$0.isWhitespace }) else {
            throw LLMError.invalidKey(provider: providerId)
        }
    }
}

// MARK: - KeychainError

/// Internal errors for keychain operations
private enum KeychainError: Error, LocalizedError {
    case storageFailure
    case deletionFailure
    
    var errorDescription: String? {
        switch self {
        case .storageFailure:
            return "Failed to store API key in keychain"
        case .deletionFailure:
            return "Failed to delete API key from keychain"
        }
    }
}
