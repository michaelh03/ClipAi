import Foundation

/// LLM provider for custom OpenAI-compatible endpoints using direct HTTP requests.
final class CustomAPIProvider: LLMProvider {

    struct Configuration {
        let apiKey: String
        let modelId: String
        let endpointURL: String
        let timeout: TimeInterval
        let additionalConfigJSON: String?

        init(
            apiKey: String,
            modelId: String,
            endpointURL: String,
            timeout: TimeInterval = 120.0,
            additionalConfigJSON: String? = nil
        ) {
            self.apiKey = apiKey
            self.modelId = modelId
            self.endpointURL = endpointURL
            self.timeout = timeout
            self.additionalConfigJSON = additionalConfigJSON
        }
    }

    private let configuration: Configuration
    private let session: URLSession

    var id: String {
        return "custom"
    }

    var displayName: String {
        return "Custom"
    }

    init(configuration: Configuration) {
        self.configuration = configuration
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout
        self.session = URLSession(configuration: sessionConfig)
    }

    func send(
        prompt: String,
        systemPrompt: String? = nil,
        model: String? = nil
    ) async throws -> String {
        let startTime = Date()

        guard !prompt.isEmpty else {
            throw LLMError.invalidResponse(provider: id, details: "Empty prompt provided")
        }

        let selectedModel = model ?? configuration.modelId
        guard let url = CustomModelStore.chatCompletionsURL(from: configuration.endpointURL) else {
            throw LLMError.invalidResponse(provider: id, details: "Invalid endpoint URL")
        }

        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": prompt])

        var requestBody: [String: Any] = [
            "model": selectedModel,
            "messages": messages
        ]
        if let extraConfig = configuration.additionalConfigJSON,
           let extraDict = try parseAdditionalConfig(extraConfig) {
            let reserved = Set(["model", "messages"])
            for (key, value) in extraDict where !reserved.contains(key) {
                requestBody[key] = value
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !configuration.apiKey.isEmpty {
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        AppLogger.shared.info("LLM request started provider=\(id) model=\(selectedModel) url=\(url.host ?? "unknown")", category: "LLM")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse(provider: id, details: "Missing HTTP response")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let mapped = LLMError.fromHTTPStatus(httpResponse.statusCode, provider: id, data: data)
                let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
                AppLogger.shared.error("LLM request failed provider=\(id) model=\(selectedModel) durationMs=\(elapsedMs) status=\(httpResponse.statusCode)", category: "LLM")
                throw mapped
            }

            guard let content = extractContent(from: data) else {
                throw LLMError.invalidResponse(provider: id, details: "No response content received")
            }

            let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
            AppLogger.shared.info("LLM request success provider=\(id) model=\(selectedModel) durationMs=\(elapsedMs) responseChars=\(content.count)", category: "LLM")
            return content
        } catch let error as LLMError {
            throw error
        } catch let urlError as URLError {
            throw LLMError.fromURLError(urlError, provider: id)
        } catch {
            throw LLMError.unknown(provider: id, underlyingError: error)
        }
    }

    func isConfigured() async -> Bool {
        do {
            _ = try await send(prompt: "ping", systemPrompt: nil, model: configuration.modelId)
            return true
        } catch {
            return false
        }
    }

    func availableModels() -> [String] {
        return [configuration.modelId]
    }
}

private extension CustomAPIProvider {
    func parseAdditionalConfig(_ jsonString: String) throws -> [String: Any]? {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let dict = json as? [String: Any] else {
            throw LLMError.invalidResponse(provider: id, details: "Additional config must be a JSON object")
        }
        return dict
    }

    func extractContent(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let choices = json["choices"] as? [[String: Any]],
           let first = choices.first {
            if let message = first["message"] as? [String: Any] {
                if let content = message["content"] as? String {
                    return content
                }
                if let contentArray = message["content"] as? [[String: Any]] {
                    let parts = contentArray.compactMap { item -> String? in
                        if let text = item["text"] as? String {
                            return text
                        }
                        if let content = item["content"] as? String {
                            return content
                        }
                        return nil
                    }
                    if !parts.isEmpty {
                        return parts.joined()
                    }
                }
            }
            if let text = first["text"] as? String {
                return text
            }
        }

        return nil
    }
}
