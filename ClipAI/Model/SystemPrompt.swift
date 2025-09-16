import Foundation

/// A system prompt template for LLM interactions
struct SystemPrompt: Codable, Identifiable, Equatable {
    /// Unique identifier for the prompt
    let id: UUID
    
    /// Human-readable title for the prompt
    let title: String
    
    /// Template string with placeholder support (e.g., {input})
    let template: String
    
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
    ///   - isSystemPrompt: Whether this is a built-in prompt
    init(id: UUID? = nil, title: String, template: String, isSystemPrompt: Bool = false) {
        self.id = id ?? UUID()
        self.title = title
        self.template = template
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
    ///   - isSystemPrompt: Whether this is a built-in prompt
    ///   - createdAt: Creation timestamp
    ///   - modifiedAt: Last modified timestamp
    init(id: UUID, title: String, template: String, isSystemPrompt: Bool, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.title = title
        self.template = template
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
    mutating func update(title: String, template: String) {
        self = SystemPrompt(
            id: self.id,
            title: title,
            template: template,
            isSystemPrompt: self.isSystemPrompt
        )
        self.modifiedAt = Date()
    }
}

// MARK: - Default Prompts

extension SystemPrompt {
    /// Default system prompts that come built-in with the app
    static let defaultPrompts: [SystemPrompt] = [
        SystemPrompt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Tech Rewrite",
            template: "<task>\nRewrite the text for concise, friendly professional communication suitable for Slack, JIRA, or other technical tools.\n</task>\n\n<guidelines>\n- Correct all spelling and grammar\n- Preserve key meaning and details; remove filler\n- Use a friendly, cooperative tone; not overly formal\n- Keep it short (1–3 sentences)\n- Avoid emojis unless already present in input\n</guidelines>\n\n<input>\n{input}\n</input>\n\n<format>\nOutput only the rewritten text.\n</format>",
            isSystemPrompt: true,
            createdAt: ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!,
            modifiedAt: ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!
        ),
        SystemPrompt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Code Review",
            template: "<task>\nAnalyze the following code and list concrete issues.\n</task>\n\n<guidelines>\n- Include bugs, errors, security risks, performance problems, readability and maintainability concerns\n- Be specific and actionable\n- One issue per bullet; keep each to one sentence\n- Optionally include a severity tag prefix: [Bug], [Security], [Perf], [Style], [Maintainability], [Test]\n- If no issues are found, output \"No issues found.\"\n</guidelines>\n\n<code>\n{input}\n</code>\n\n<format>\n- [Severity] Issue description\n</format>",
            isSystemPrompt: true,
            createdAt: ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!,
            modifiedAt: ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!
        ),
        SystemPrompt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            title: "Formal Email",
            template: "<task>\nTransform the following notes into a formal, professional email.\n</task>\n\n<guidelines>\n- Create a clear subject line\n- Include greeting, concise body, and courteous closing\n- Use a professional tone\n- Organize with short paragraphs\n- Include call-to-action or next steps if present in input\n</guidelines>\n\n<input>\n{input}\n</input>\n\n<format>\nSubject: [Generated subject]\n\n[Email body]\n</format>",
            isSystemPrompt: true,
            createdAt: ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!,
            modifiedAt: ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!
        )
    ]
}