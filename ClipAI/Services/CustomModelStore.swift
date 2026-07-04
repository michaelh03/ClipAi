import Foundation

struct CustomModelDefinition: Codable, Hashable {
    let providerId: String
    let modelId: String
    let endpointURL: String
    let additionalConfigJSON: String?
    let createdAt: Date
}

enum CustomModelStore {
    struct EndpointConfiguration: Hashable {
        let scheme: String
        let host: String
        let basePath: String
    }

    private static let storageKey = "customModelEndpoints"

    static func loadAll() -> [CustomModelDefinition] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([CustomModelDefinition].self, from: data)) ?? []
    }

    static func models(for providerId: String) -> [CustomModelDefinition] {
        loadAll().filter { $0.providerId == providerId }
    }

    static func find(providerId: String, modelId: String) -> CustomModelDefinition? {
        loadAll().first {
            $0.providerId == providerId &&
            $0.modelId.caseInsensitiveCompare(modelId) == .orderedSame
        }
    }

    static func upsert(_ model: CustomModelDefinition) {
        var models = loadAll()
        models.removeAll {
            $0.providerId == model.providerId &&
            $0.modelId.caseInsensitiveCompare(model.modelId) == .orderedSame
        }
        models.append(model)
        saveAll(models)
    }

    static func remove(providerId: String, modelId: String) {
        var models = loadAll()
        models.removeAll {
            $0.providerId == providerId &&
            $0.modelId.caseInsensitiveCompare(modelId) == .orderedSame
        }
        saveAll(models)
    }

    static func parseEndpointURL(_ urlString: String) -> EndpointConfiguration? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme,
              let host = components.host else {
            return nil
        }

        var basePath = components.path
        if basePath.isEmpty || basePath == "/" {
            basePath = "/v1"
        }
        if basePath.count > 1, basePath.hasSuffix("/") {
            basePath.removeLast()
        }

        return EndpointConfiguration(scheme: scheme, host: host, basePath: basePath)
    }

    static func chatCompletionsURL(from endpointURL: String) -> URL? {
        let trimmed = endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            return nil
        }
        if url.path.contains("/chat/completions") {
            return url
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var path = components?.path ?? ""
        if path.hasSuffix("/") {
            path.removeLast()
        }
        path += "/chat/completions"
        components?.path = path
        components?.query = nil
        return components?.url
    }

    private static func saveAll(_ models: [CustomModelDefinition]) {
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
