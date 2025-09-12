import Foundation

/// Enum representing different types of content detection rules
enum ContentDetectionRuleType {
    case regex(pattern: String, options: NSRegularExpression.Options = [])
    case fileExtension(extensions: Set<String>)
    case prefix(prefixes: Set<String>)
    case suffix(suffixes: Set<String>)
    case custom(detector: (String) -> Bool)
    case composite(rules: [ContentDetectionRule], operator: CompositeOperator)
}

/// Operators for combining multiple rules
enum CompositeOperator {
    case and
    case or
}

/// A rule for detecting specific content types
struct ContentDetectionRule {
    let name: String
    let type: ContentDetectionRuleType
    let priority: Int
    let description: String
    
    init(name: String, type: ContentDetectionRuleType, priority: Int = 0, description: String = "") {
        self.name = name
        self.type = type
        self.priority = priority
        self.description = description
    }
    
    /// Evaluates whether the given text matches this rule
    func matches(_ text: String) -> Bool {
        switch type {
        case .regex(let pattern, let options):
            return matchesRegex(text, pattern: pattern, options: options)
            
        case .fileExtension(let extensions):
            return matchesFileExtension(text, extensions: extensions)
            
        case .prefix(let prefixes):
            return matchesPrefix(text, prefixes: prefixes)
            
        case .suffix(let suffixes):
            return matchesSuffix(text, suffixes: suffixes)
            
        case .custom(let detector):
            return detector(text)
            
        case .composite(let rules, let op):
            return matchesComposite(text, rules: rules, operator: op)
        }
    }
    
    // MARK: - Private Matching Methods
    
    private func matchesRegex(_ text: String, pattern: String, options: NSRegularExpression.Options) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    private func matchesFileExtension(_ text: String, extensions: Set<String>) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if text starts with a file path or filename
        let lines = trimmedText.components(separatedBy: .newlines)
        guard let firstLine = lines.first, !firstLine.isEmpty else { return false }
        
        // Extract potential filename from first line
        let potentialFilename = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for file extension
        if let lastDot = potentialFilename.lastIndex(of: ".") {
            let extensionStart = potentialFilename.index(after: lastDot)
            let fileExtension = String(potentialFilename[extensionStart...]).lowercased()
            return extensions.contains(fileExtension)
        }
        
        return false
    }
    
    private func matchesPrefix(_ text: String, prefixes: Set<String>) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return prefixes.contains { prefix in
            trimmedText.lowercased().hasPrefix(prefix.lowercased())
        }
    }
    
    private func matchesSuffix(_ text: String, suffixes: Set<String>) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return suffixes.contains { suffix in
            trimmedText.lowercased().hasSuffix(suffix.lowercased())
        }
    }
    
    private func matchesComposite(_ text: String, rules: [ContentDetectionRule], operator op: CompositeOperator) -> Bool {
        switch op {
        case .and:
            return rules.allSatisfy { $0.matches(text) }
        case .or:
            return rules.contains { $0.matches(text) }
        }
    }
}

// MARK: - Predefined Rules

extension ContentDetectionRule {
    
    // MARK: - Code Detection Rules
    
    static let codeFileExtensions = ContentDetectionRule(
        name: "Code File Extensions",
        type: .fileExtension(extensions: [
            "swift", "js", "ts", "jsx", "tsx", "py", "java", "cpp", "c", "h", "hpp",
            "cs", "php", "rb", "go", "rs", "kt", "scala", "m", "mm", "sh", "bash",
            "zsh", "fish", "ps1", "bat", "cmd", "sql", "r", "matlab", "pl", "lua",
            "dart", "elm", "clj", "cljs", "hs", "ml", "fs", "vb", "pas", "asm",
            "html", "css", "scss", "sass", "less", "xml", "yaml", "yml", "toml",
            "ini", "cfg", "conf", "properties", "gradle", "maven", "cmake"
        ]),
        priority: 80,
        description: "Detects code based on common file extensions"
    )
    
    static let codeKeywords = ContentDetectionRule(
        name: "Code Keywords",
        type: .regex(
            pattern: """
            (?i)\\b(function|class|import|export|const|let|var|if|else|for|while|return|def|public|private|protected|static|final|abstract|interface|enum|struct|union|typedef|namespace|using|include|#include|#import|#define|#ifdef|#ifndef|#endif|package|module|library|procedure|begin|end|program|unit|uses|type|record|array|set|file|text|integer|real|boolean|char|string|pointer|reference|template|generic|virtual|override|sealed|partial|async|await|yield|lambda|arrow|=>|->|::|\\.\\.|\\?\\.|\\|>|<\\||>>|<<|&&|\\|\\||\\+\\+|--|\\+=|-=|\\*=|/=|%=|&=|\\|=|\\^=|<<=|>>=|==|!=|<=|>=|<>|\\?\\?|\\?\\.|\\?:|\\?\\[)\\b
            """,
            options: [.caseInsensitive]
        ),
        priority: 70,
        description: "Detects code based on common programming keywords and operators"
    )
    
    static let codeBraces = ContentDetectionRule(
        name: "Code Braces Pattern",
        type: .regex(
            pattern: ".*\\{[^{}]*\\}.*|.*\\([^()]*\\).*\\{.*\\}|.*;\\s*$",
            options: [.anchorsMatchLines]
        ),
        priority: 60,
        description: "Detects code based on brace patterns and semicolons"
    )
    
    // MARK: - JSON Detection Rules
    
    static let jsonStructure = ContentDetectionRule(
        name: "JSON Structure",
        type: .regex(
            pattern: "^\\s*[\\[\\{].*[\\]\\}]\\s*$",
            options: [.dotMatchesLineSeparators]
        ),
        priority: 90,
        description: "Detects JSON based on opening and closing brackets/braces"
    )
    
    static let jsonKeyValue = ContentDetectionRule(
        name: "JSON Key-Value Pattern",
        type: .regex(
            pattern: "\"[^\"]*\"\\s*:\\s*([\"\\d\\[\\{]|true|false|null)",
            options: []
        ),
        priority: 85,
        description: "Detects JSON based on key-value pair patterns"
    )
    
    // MARK: - Color Detection Rules
    
    static let hexColor = ContentDetectionRule(
        name: "Hex Color",
        type: .regex(
            pattern: "^\\s*#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3}|[A-Fa-f0-9]{8})\\s*$",
            options: []
        ),
        priority: 95,
        description: "Detects hexadecimal color values"
    )
    
    static let rgbColor = ContentDetectionRule(
        name: "RGB Color",
        type: .regex(
            pattern: "^\\s*rgba?\\s*\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+(\\s*,\\s*[0-9.]+)?\\s*\\)\\s*$",
            options: [.caseInsensitive]
        ),
        priority: 95,
        description: "Detects RGB/RGBA color values"
    )
    
    static let hslColor = ContentDetectionRule(
        name: "HSL Color",
        type: .regex(
            pattern: "^\\s*hsla?\\s*\\(\\s*\\d+\\s*,\\s*\\d+%\\s*,\\s*\\d+%(\\s*,\\s*[0-9.]+)?\\s*\\)\\s*$",
            options: [.caseInsensitive]
        ),
        priority: 95,
        description: "Detects HSL/HSLA color values"
    )
    
    // MARK: - URL Detection Rules
    
    static let httpUrl = ContentDetectionRule(
        name: "HTTP URL",
        type: .regex(
            pattern: "^\\s*https?://[^\\s]+\\s*$",
            options: [.caseInsensitive]
        ),
        priority: 90,
        description: "Detects HTTP/HTTPS URLs"
    )
    
    // MARK: - Plain Text Rules
    
    static let plainText = ContentDetectionRule(
        name: "Plain Text",
        type: .custom { text in
            // Plain text is the fallback - always matches but with lowest priority
            return true
        },
        priority: 1,
        description: "Fallback rule for plain text content"
    )
}