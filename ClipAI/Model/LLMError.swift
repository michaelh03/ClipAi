//
//  LLMError.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import Foundation

/// Unified error handling enum for all LLM provider-specific errors
enum LLMError: Error, LocalizedError, Equatable {
    case quotaExceeded(provider: String, resetDate: Date? = nil)
    case invalidKey(provider: String)
    case network(underlyingError: Error?)
    case rateLimited(provider: String, retryAfter: TimeInterval? = nil)
    case invalidResponse(provider: String, details: String? = nil)
    case serviceUnavailable(provider: String)
    case contentFiltered(provider: String, reason: String? = nil)
    case tokenLimitExceeded(provider: String, maxTokens: Int? = nil)
    case unknown(provider: String, underlyingError: Error? = nil)
    
    /// User-friendly error descriptions
    var errorDescription: String? {
        switch self {
        case .quotaExceeded(let provider, let resetDate):
            if let resetDate = resetDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "Quota exceeded for \(provider). Resets on \(formatter.string(from: resetDate))."
            } else {
                return "Quota exceeded for \(provider). Please check your usage limits."
            }
            
        case .invalidKey(let provider):
            return "Invalid API key for \(provider). Please check your API key in settings."
            
        case .network(let underlyingError):
            if let underlyingError = underlyingError {
                return "Network error: \(underlyingError.localizedDescription)"
            } else {
                return "Network connection failed. Please check your internet connection."
            }
            
        case .rateLimited(let provider, let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited by \(provider). Please try again in \(Int(retryAfter)) seconds."
            } else {
                return "Rate limited by \(provider). Please try again later."
            }
            
        case .invalidResponse(let provider, let details):
            if let details = details {
                return "Invalid response from \(provider): \(details)"
            } else {
                return "Invalid response from \(provider). Please try again."
            }
            
        case .serviceUnavailable(let provider):
            return "\(provider) service is currently unavailable. Please try again later."
            
        case .contentFiltered(let provider, let reason):
            if let reason = reason {
                return "Content filtered by \(provider): \(reason)"
            } else {
                return "Content was filtered by \(provider). Please modify your request."
            }
            
        case .tokenLimitExceeded(let provider, let maxTokens):
            if let maxTokens = maxTokens {
                return "Token limit exceeded for \(provider). Maximum tokens: \(maxTokens)."
            } else {
                return "Token limit exceeded for \(provider). Please shorten your input."
            }
            
        case .unknown(let provider, let underlyingError):
            if let underlyingError = underlyingError {
                return "Unknown error from \(provider): \(underlyingError.localizedDescription)"
            } else {
                return "Unknown error from \(provider). Please try again."
            }
        }
    }
    
    /// Failure reason for debugging
    var failureReason: String? {
        switch self {
        case .quotaExceeded(let provider, _):
            return "API quota exceeded for \(provider)"
        case .invalidKey(let provider):
            return "Invalid API key for \(provider)"
        case .network(_):
            return "Network connectivity issue"
        case .rateLimited(let provider, _):
            return "Rate limit hit for \(provider)"
        case .invalidResponse(let provider, _):
            return "Invalid API response from \(provider)"
        case .serviceUnavailable(let provider):
            return "\(provider) service unavailable"
        case .contentFiltered(let provider, _):
            return "Content filtered by \(provider)"
        case .tokenLimitExceeded(let provider, _):
            return "Token limit exceeded for \(provider)"
        case .unknown(let provider, _):
            return "Unknown error from \(provider)"
        }
    }
    
    /// Recovery suggestion for users
    var recoverySuggestion: String? {
        switch self {
        case .quotaExceeded(_, let resetDate):
            if resetDate != nil {
                return "Wait for your quota to reset or upgrade your plan."
            } else {
                return "Check your usage limits and consider upgrading your plan."
            }
            
        case .invalidKey(_):
            return "Verify your API key in Settings > LLM Providers and ensure it's correctly entered."
            
        case .network(_):
            return "Check your internet connection and try again."
            
        case .rateLimited(_, let retryAfter):
            if let retryAfter = retryAfter {
                return "Wait \(Int(retryAfter)) seconds before making another request."
            } else {
                return "Wait a moment before making another request."
            }
            
        case .invalidResponse(_, _):
            return "Try again or contact support if the issue persists."
            
        case .serviceUnavailable(_):
            return "The service is temporarily unavailable. Try again later."
            
        case .contentFiltered(_, _):
            return "Modify your input to comply with the provider's content policy."
            
        case .tokenLimitExceeded(_, _):
            return "Reduce the length of your input text or split it into smaller parts."
            
        case .unknown(_, _):
            return "Try again or contact support if the issue persists."
        }
    }
    
    /// Whether this error suggests the user should retry the request
    var isRetryable: Bool {
        switch self {
        case .network(_), .serviceUnavailable(_), .rateLimited(_, _), .unknown(_, _):
            return true
        case .quotaExceeded(_, _), .invalidKey(_), .invalidResponse(_, _), .contentFiltered(_, _), .tokenLimitExceeded(_, _):
            return false
        }
    }
    
    /// Provider name associated with this error
    var provider: String {
        switch self {
        case .quotaExceeded(let provider, _),
             .invalidKey(let provider),
             .rateLimited(let provider, _),
             .invalidResponse(let provider, _),
             .serviceUnavailable(let provider),
             .contentFiltered(let provider, _),
             .tokenLimitExceeded(let provider, _),
             .unknown(let provider, _):
            return provider
        case .network(_):
            return "Network"
        }
    }
}

// MARK: - Error Mapping Extensions

extension LLMError {
    /// Maps common HTTP status codes to LLMError cases
    static func fromHTTPStatus(_ statusCode: Int, provider: String, data: Data? = nil) -> LLMError {
        AppLogger.shared.debug("Map HTTP status to LLMError provider=\(provider) status=\(statusCode)", category: "LLM")
        switch statusCode {
        case 401:
            return .invalidKey(provider: provider)
        case 429:
            // Try to extract retry-after header value if available
            return .rateLimited(provider: provider, retryAfter: nil)
        case 402:
            return .quotaExceeded(provider: provider)
        case 503, 502, 504:
            return .serviceUnavailable(provider: provider)
        case 400:
            // Could be content filtering or token limit
            if let data = data,
               let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = response["error"] as? [String: Any],
               let code = error["code"] as? String {
                
                if code.contains("content") || code.contains("filter") {
                    return .contentFiltered(provider: provider, reason: error["message"] as? String)
                } else if code.contains("token") || code.contains("length") {
                    return .tokenLimitExceeded(provider: provider)
                }
            }
            return .invalidResponse(provider: provider, details: "Bad Request")
        default:
            return .unknown(provider: provider, underlyingError: nil)
        }
    }
    
    /// Maps URLError to LLMError
    static func fromURLError(_ error: URLError, provider: String = "Network") -> LLMError {
        AppLogger.shared.debug("Map URLError to LLMError provider=\(provider) code=\(error.code.rawValue)", category: "LLM")
        return .network(underlyingError: error)
    }
}

// MARK: - Equatable Implementation

extension LLMError {
    static func == (lhs: LLMError, rhs: LLMError) -> Bool {
        switch (lhs, rhs) {
        case (.quotaExceeded(let lProvider, let lDate), .quotaExceeded(let rProvider, let rDate)):
            return lProvider == rProvider && lDate == rDate
        case (.invalidKey(let lProvider), .invalidKey(let rProvider)):
            return lProvider == rProvider
        case (.network(_), .network(_)):
            return true // We don't compare underlying errors
        case (.rateLimited(let lProvider, let lRetry), .rateLimited(let rProvider, let rRetry)):
            return lProvider == rProvider && lRetry == rRetry
        case (.invalidResponse(let lProvider, let lDetails), .invalidResponse(let rProvider, let rDetails)):
            return lProvider == rProvider && lDetails == rDetails
        case (.serviceUnavailable(let lProvider), .serviceUnavailable(let rProvider)):
            return lProvider == rProvider
        case (.contentFiltered(let lProvider, let lReason), .contentFiltered(let rProvider, let rReason)):
            return lProvider == rProvider && lReason == rReason
        case (.tokenLimitExceeded(let lProvider, let lTokens), .tokenLimitExceeded(let rProvider, let rTokens)):
            return lProvider == rProvider && lTokens == rTokens
        case (.unknown(let lProvider, _), .unknown(let rProvider, _)):
            return lProvider == rProvider // We don't compare underlying errors
        default:
            return false
        }
    }
}