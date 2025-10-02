import Foundation

/// A system prompt template for LLM interactions
struct SystemPrompt: Codable, Identifiable, Equatable {
    /// Unique identifier for the prompt
    let id: UUID
    
    /// Human-readable title for the prompt
    let title: String
    
    /// Template string with placeholder support (e.g., {input})
    let template: String

    /// Optional file path for template loaded from external file
    let templateFilePath: String?

    /// Whether this is a built-in system prompt (cannot be deleted)
    let isSystemPrompt: Bool
    
    /// Creation timestamp
    let createdAt: Date
    
    /// Last modified timestamp
    var modifiedAt: Date
    
    // MARK: - Initializers
    
    /// Initialize a new SystemPrompt
    /// - Parameters:
    ///   - id: Unique identifier (generates new UUID if nil)
    ///   - title: Human-readable title
    ///   - template: Template string with placeholder support
    ///   - templateFilePath: Optional file path for external template
    ///   - isSystemPrompt: Whether this is a built-in prompt
    init(id: UUID? = nil, title: String, template: String, templateFilePath: String? = nil, isSystemPrompt: Bool = false) {
        self.id = id ?? UUID()
        self.title = title
        self.template = template
        self.templateFilePath = templateFilePath
        self.isSystemPrompt = isSystemPrompt
        let now = Date()
        self.createdAt = now
        self.modifiedAt = now
    }
    
    /// Initialize a SystemPrompt with explicit timestamps (for loading from storage)
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - title: Human-readable title
    ///   - template: Template string with placeholder support
    ///   - templateFilePath: Optional file path for external template
    ///   - isSystemPrompt: Whether this is a built-in prompt
    ///   - createdAt: Creation timestamp
    ///   - modifiedAt: Last modified timestamp
    init(id: UUID, title: String, template: String, templateFilePath: String? = nil, isSystemPrompt: Bool, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.title = title
        self.template = template
        self.templateFilePath = templateFilePath
        self.isSystemPrompt = isSystemPrompt
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    // MARK: - Template Processing
    
    /// Process the template by substituting placeholders with provided values
    /// - Parameter input: The input text to substitute for {input} placeholder
    /// - Returns: Processed template string with substitutions
    func processTemplate(with input: String) -> String {
        return template.replacingOccurrences(of: "{input}", with: input)
    }
    
    /// Process the template with multiple variable substitutions
    /// - Parameter variables: Dictionary of variable names to values
    /// - Returns: Processed template string with all substitutions
    func processTemplate(with variables: [String: String]) -> String {
        var processedTemplate = template
        
        for (key, value) in variables {
            let placeholder = "{\(key)}"
            processedTemplate = processedTemplate.replacingOccurrences(of: placeholder, with: value)
        }
        
        return processedTemplate
    }
    
    /// Check if the template contains the specified placeholder
    /// - Parameter placeholder: The placeholder to check for (without braces)
    /// - Returns: True if the placeholder exists in the template
    func containsPlaceholder(_ placeholder: String) -> Bool {
        return template.contains("{\(placeholder)}")
    }
    
    /// Get all placeholders in the template
    /// - Returns: Array of placeholder names (without braces)
    func getPlaceholders() -> [String] {
        let pattern = "\\{([^}]+)\\}"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(template.startIndex..<template.endIndex, in: template)
        
        guard let regex = regex else { return [] }
        
        let matches = regex.matches(in: template, range: range)
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: template) {
                return String(template[range])
            }
            return nil
        }
    }
    
    // MARK: - Validation
    
    /// Validate the prompt template
    /// - Returns: True if the template is valid
    func isValid() -> Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Mutating Methods
    
    /// Update the prompt title and template
    /// - Parameters:
    ///   - title: New title
    ///   - template: New template
    ///   - templateFilePath: Optional file path for external template
    mutating func update(title: String, template: String, templateFilePath: String? = nil) {
        self = SystemPrompt(
            id: self.id,
            title: title,
            template: template,
            templateFilePath: templateFilePath,
            isSystemPrompt: self.isSystemPrompt
        )
        self.modifiedAt = Date()
    }

    // MARK: - File Loading

    /// Load template from external file
    /// - Parameter filePath: Path to the template file
    /// - Returns: SystemPrompt with template loaded from file
    /// - Throws: Error if file cannot be read
    static func fromFile(id: UUID? = nil, title: String, filePath: String, isSystemPrompt: Bool = false) throws -> SystemPrompt {
        let templateContent = try String(contentsOfFile: filePath, encoding: .utf8)
        return SystemPrompt(
            id: id,
            title: title,
            template: templateContent,
            templateFilePath: filePath,
            isSystemPrompt: isSystemPrompt
        )
    }

    /// Get the effective template (from file if available, otherwise use stored template)
    /// - Returns: Template content, loaded from file if path is set
    /// - Throws: Error if file path is set but file cannot be read
    func getEffectiveTemplate() throws -> String {
        if let filePath = templateFilePath {
            return try String(contentsOfFile: filePath, encoding: .utf8)
        }
        return template
    }
}

// MARK: - Default Prompts

extension SystemPrompt {
    /// Default system prompts that come built-in with the app
    static var defaultPrompts: [SystemPrompt] {
        let baseDate = ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!

        let promptConfigs: [(id: String, title: String, fileName: String)] = [
            ("00000000-0000-0000-0000-000000000001", "Grammar & Spelling", "grammar_spelling"),
            ("00000000-0000-0000-0000-000000000002", "Code Review", "code_review"),
            ("00000000-0000-0000-0000-000000000003", "Email Polish", "email_polish")
        ]

        return promptConfigs.compactMap { config -> SystemPrompt? in
            guard let filePath = Bundle.main.path(forResource: config.fileName, ofType: "txt") else {
                AppLogger.shared.error("Failed to find prompt file: \(config.fileName)")
                return nil
            }

            do {
                let template = try String(contentsOfFile: filePath, encoding: .utf8)
                return SystemPrompt(
                    id: UUID(uuidString: config.id)!,
                    title: config.title,
                    template: template,
                    templateFilePath: filePath,
                    isSystemPrompt: true,
                    createdAt: baseDate,
                    modifiedAt: baseDate
                )
            } catch {
              AppLogger.shared.error("Failed to load prompt from file: \(filePath), error: \(error.localizedDescription)")
                return nil
            }
        }
    }
}
