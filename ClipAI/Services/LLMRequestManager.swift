//
//  LLMRequestManager.swift
//  ClipAI
//
//  Created by ClipAI on 2025-01-16.
//

import Foundation

extension Notification.Name {
    static let aiActivityDidStart = Notification.Name("aiActivityDidStart")
    static let aiActivityDidFinish = Notification.Name("aiActivityDidFinish")
}

/// Configuration for retry behavior
struct RetryConfiguration {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    
    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0
    )
}

/// Configuration for rate limiting per provider
struct RateLimitConfiguration {
    let requestsPerMinute: Int
    let burstLimit: Int
    
    static let `default` = RateLimitConfiguration(
        requestsPerMinute: 60,
        burstLimit: 10
    )
}

/// Represents an in-flight LLM request
private struct LLMRequest {
    let id: UUID
    let provider: LLMProvider
    let prompt: String
    let systemPrompt: String?
    let model: String?
    let startTime: Date
    let attempt: Int
    let retryConfiguration: RetryConfiguration
    
    init(provider: LLMProvider, prompt: String, systemPrompt: String?, model: String?, retryConfiguration: RetryConfiguration) {
        self.id = UUID()
        self.provider = provider
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.model = model
        self.startTime = Date()
        self.attempt = 1
        self.retryConfiguration = retryConfiguration
    }
    
    /// Create a retry attempt with incremented attempt count
    func withRetryAttempt(_ attemptNumber: Int) -> LLMRequest {
        return LLMRequest(
            id: self.id,
            provider: self.provider,
            prompt: self.prompt,
            systemPrompt: self.systemPrompt,
            model: self.model,
            startTime: self.startTime,
            attempt: attemptNumber,
            retryConfiguration: self.retryConfiguration
        )
    }
    
    private init(id: UUID, provider: LLMProvider, prompt: String, systemPrompt: String?, model: String?, startTime: Date, attempt: Int, retryConfiguration: RetryConfiguration) {
        self.id = id
        self.provider = provider
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.model = model
        self.startTime = startTime
        self.attempt = attempt
        self.retryConfiguration = retryConfiguration
    }
}

/// Rate limiting state for a provider
private struct RateLimitState {
    var requestTimes: [Date] = []
    var lastRequestTime: Date?
    var isThrottled: Bool = false
    var throttleEndTime: Date?
    
    mutating func recordRequest() {
        let now = Date()
        requestTimes.append(now)
        lastRequestTime = now
        
        // Clean up old request times (older than 1 minute)
        let cutoff = now.addingTimeInterval(-60)
        requestTimes.removeAll { $0 < cutoff }
    }
    
    func canMakeRequest(configuration: RateLimitConfiguration) -> Bool {
        let now = Date()
        
        // Check if we're still throttled
        if isThrottled, let throttleEndTime = throttleEndTime, now < throttleEndTime {
            return false
        }
        
        // Check burst limit
        if requestTimes.count >= configuration.burstLimit {
            return false
        }
        
        // Check requests per minute
        let recentRequests = requestTimes.filter { now.timeIntervalSince($0) <= 60 }
        return recentRequests.count < configuration.requestsPerMinute
    }
    
    mutating func setThrottled(until endTime: Date) {
        isThrottled = true
        throttleEndTime = endTime
    }
    
    mutating func clearThrottle() {
        isThrottled = false
        throttleEndTime = nil
    }
}

/// Thread-safe manager for LLM requests with rate limiting, throttling, and retry logic
actor LLMRequestManager {
    
    // MARK: - Properties
    
    private var inFlightRequests: [UUID: LLMRequest] = [:]
    private var rateLimitStates: [String: RateLimitState] = [:]
    private var pendingRequests: [(LLMRequest, CheckedContinuation<String, Error>)] = []
    
    private let defaultRetryConfiguration: RetryConfiguration
    private let defaultRateLimitConfiguration: RateLimitConfiguration
    private var providerRateLimitConfigurations: [String: RateLimitConfiguration] = [:]
    
    // MARK: - Initialization
    
    init(
        defaultRetryConfiguration: RetryConfiguration = .default,
        defaultRateLimitConfiguration: RateLimitConfiguration = .default
    ) {
        self.defaultRetryConfiguration = defaultRetryConfiguration
        self.defaultRateLimitConfiguration = defaultRateLimitConfiguration
    }
    
    // MARK: - Public Methods
    
    /// Send a request to an LLM provider with automatic retry and rate limiting
    /// - Parameters:
    ///   - provider: The LLM provider to use
    ///   - prompt: The user prompt
    ///   - systemPrompt: Optional system prompt
    ///   - model: Optional model specification
    ///   - retryConfiguration: Optional custom retry configuration
    /// - Returns: The LLM response
    /// - Throws: LLMError if the request fails after all retries
    func sendRequest(
        provider: LLMProvider,
        prompt: String,
        systemPrompt: String? = nil,
        model: String? = nil,
        retryConfiguration: RetryConfiguration? = nil
    ) async throws -> String {
        
        let config = retryConfiguration ?? defaultRetryConfiguration
        let request = LLMRequest(
            provider: provider,
            prompt: prompt,
            systemPrompt: systemPrompt,
            model: model,
            retryConfiguration: config
        )
        
        return try await executeRequest(request)
    }
    
    /// Configure rate limiting for a specific provider
    /// - Parameters:
    ///   - providerId: The provider identifier
    ///   - configuration: The rate limit configuration
    func configureRateLimit(for providerId: String, configuration: RateLimitConfiguration) {
        providerRateLimitConfigurations[providerId] = configuration
    }
    
    /// Get current statistics for monitoring
    /// - Returns: Dictionary with current request counts and rate limit status
    func getStatistics() -> [String: Any] {
        var stats: [String: Any] = [:]
        stats["inFlightRequests"] = inFlightRequests.count
        stats["pendingRequests"] = pendingRequests.count
        
        var providerStats: [String: [String: Any]] = [:]
        for (providerId, state) in rateLimitStates {
            providerStats[providerId] = [
                "recentRequests": state.requestTimes.count,
                "isThrottled": state.isThrottled,
                "lastRequestTime": state.lastRequestTime?.timeIntervalSince1970 ?? 0
            ]
        }
        stats["providers"] = providerStats
        
        return stats
    }
    
    /// Cancel all pending requests for a specific provider
    /// - Parameter providerId: The provider identifier
    func cancelRequests(for providerId: String) {
        // Remove in-flight requests for this provider
        let requestsToCancel = inFlightRequests.values.filter { $0.provider.id == providerId }
        for request in requestsToCancel {
            inFlightRequests.removeValue(forKey: request.id)
        }
        
        // Remove pending requests for this provider and fail their continuations
        var remainingPendingRequests: [(LLMRequest, CheckedContinuation<String, Error>)] = []
        for (request, continuation) in pendingRequests {
            if request.provider.id == providerId {
                continuation.resume(throwing: LLMError.serviceUnavailable(provider: providerId))
            } else {
                remainingPendingRequests.append((request, continuation))
            }
        }
        pendingRequests = remainingPendingRequests
    }
    
    // MARK: - Private Methods
    
    private func executeRequest(_ request: LLMRequest) async throws -> String {
        // Check rate limiting
        if !canMakeRequest(for: request.provider.id) {
            // Queue the request
            return try await withCheckedThrowingContinuation { continuation in
                pendingRequests.append((request, continuation))
                processPendingRequests()
            }
        }
        
        // Record the request start
        inFlightRequests[request.id] = request
        recordRequest(for: request.provider.id)
        NotificationCenter.default.post(name: .aiActivityDidStart, object: nil)
        
        defer {
            inFlightRequests.removeValue(forKey: request.id)
            NotificationCenter.default.post(name: .aiActivityDidFinish, object: nil)
        }
        
        do {
            let response = try await request.provider.send(
                prompt: request.prompt,
                systemPrompt: request.systemPrompt,
                model: request.model
            )
            
            // Process any pending requests now that we're done
            processPendingRequests()
            
            return response
            
        } catch let error as LLMError {
            
            // Handle rate limiting from the provider
            if case .rateLimited(_, let retryAfter) = error {
                handleRateLimit(for: request.provider.id, retryAfter: retryAfter)
            }
            
            // Retry logic for retryable errors
            if error.isRetryable && request.attempt < request.retryConfiguration.maxAttempts {
                let delay = calculateBackoffDelay(
                    attempt: request.attempt,
                    configuration: request.retryConfiguration
                )
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                let retryRequest = request.withRetryAttempt(request.attempt + 1)
                return try await executeRequest(retryRequest)
            }
            
            throw error
            
        } catch {
            // Wrap unexpected errors
            let llmError = LLMError.unknown(provider: request.provider.id, underlyingError: error)
            
            // Retry for unknown errors
            if request.attempt < request.retryConfiguration.maxAttempts {
                let delay = calculateBackoffDelay(
                    attempt: request.attempt,
                    configuration: request.retryConfiguration
                )
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                let retryRequest = request.withRetryAttempt(request.attempt + 1)
                return try await executeRequest(retryRequest)
            }
            
            throw llmError
        }
    }
    
    private func canMakeRequest(for providerId: String) -> Bool {
        let configuration = providerRateLimitConfigurations[providerId] ?? defaultRateLimitConfiguration
        
        if var state = rateLimitStates[providerId] {
            let canMake = state.canMakeRequest(configuration: configuration)
            
            // Clear throttle if it has expired
            let now = Date()
            if state.isThrottled, let throttleEndTime = state.throttleEndTime, now >= throttleEndTime {
                state.clearThrottle()
                rateLimitStates[providerId] = state
            }
            
            return canMake
        }
        
        // No existing state means we can make the request
        return true
    }
    
    private func recordRequest(for providerId: String) {
        if rateLimitStates[providerId] == nil {
            rateLimitStates[providerId] = RateLimitState()
        }
        rateLimitStates[providerId]?.recordRequest()
    }
    
    private func handleRateLimit(for providerId: String, retryAfter: TimeInterval?) {
        if rateLimitStates[providerId] == nil {
            rateLimitStates[providerId] = RateLimitState()
        }
        
        let throttleEndTime = Date().addingTimeInterval(retryAfter ?? 60)
        rateLimitStates[providerId]?.setThrottled(until: throttleEndTime)
    }
    
    private func processPendingRequests() {
        var remainingPendingRequests: [(LLMRequest, CheckedContinuation<String, Error>)] = []
        
        for (request, continuation) in pendingRequests {
            if canMakeRequest(for: request.provider.id) {
                Task {
                    do {
                        let response = try await executeRequest(request)
                        continuation.resume(returning: response)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            } else {
                remainingPendingRequests.append((request, continuation))
            }
        }
        
        pendingRequests = remainingPendingRequests
    }
    
    private func calculateBackoffDelay(attempt: Int, configuration: RetryConfiguration) -> TimeInterval {
        let delay = configuration.baseDelay * pow(configuration.backoffMultiplier, Double(attempt - 1))
        return min(delay, configuration.maxDelay)
    }
}