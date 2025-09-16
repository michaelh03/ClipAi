import Foundation

/// Enumeration representing different types of clipboard content
/// 
/// This enum categorizes clipboard content into distinct types that can be
/// handled by specialized preview providers. Each content type has associated
/// detection capabilities and metadata.
enum ClipContentType: String, CaseIterable, Codable {
    case plainText = "plainText"
    case code = "code"
    case json = "json"
    case color = "color"
    
    /// Human-readable display name for the content type
    var displayName: String {
        switch self {
        case .plainText:
            return "Plain Text"
        case .code:
            return "Code"
        case .json:
            return "JSON"
        case .color:
            return "Color"
        }
    }
    
    /// Icon name for the content type (SF Symbol)
    var iconName: String {
        switch self {
        case .plainText:
            return "doc.text"
        case .code:
            return "curlybraces"
        case .json:
            return "curlybraces.square"
        case .color:
            return "paintpalette"
        }
    }
    
    /// Basic detection method for quick content type identification
    /// - Parameter content: The clipboard content to analyze
    /// - Returns: True if the content likely matches this type
    func matches(_ content: String) -> Bool {
        switch self {
        case .plainText:
            // Plain text is the fallback - it matches everything
            return true
            
        case .code:
            // Basic heuristics for code detection
            return hasCodePatterns(content)
            
        case .json:
            // Try to parse as JSON
            return isValidJSON(content)
            
        case .color:
            // Check for color format patterns
            return hasColorPatterns(content)
        }
    }
    
    /// Priority order for detection (higher numbers checked first)
    var detectionPriority: Int {
        switch self {
        case .json:
            return 90  // Highest priority - very specific format
        case .color:
            return 80  // High priority - specific patterns
        case .code:
            return 70  // Medium-high priority - has distinctive patterns
        case .plainText:
            return 10  // Lowest priority - fallback for everything
        }
    }
}

// MARK: - Detection Helpers
extension ClipContentType {
    
    /// Check if content has typical code patterns
    func hasCodePatterns(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip if too short or looks like plain text
        guard trimmed.count > 10 else { return false }
        
        // Code indicators
        let codePatterns = [
            // Function definitions
            #"(function|def|func|fn)\s+\w+"#,
            // Variable declarations
            #"(var|let|const|int|string|bool)\s+\w+"#,
            // Control structures
            #"(if|for|while|switch|case)\s*\("#,
            // Class/struct definitions
            #"(class|struct|interface|protocol)\s+\w+"#,
            // Import/include statements
            #"(import|include|require|using)\s+"#,
            // Common operators and syntax
            #"(==|!=|<=|>=|\&\&|\|\|)"#,
            // Brackets and braces with specific patterns
            #"\{\s*\n.*\n\s*\}"#
        ]
        
        let hasCodeKeywords = codePatterns.contains { pattern in
            content.range(of: pattern, options: .regularExpression) != nil
        }
        
        // Check for typical code structure
        let hasBraces = content.contains("{") && content.contains("}")
        let hasParentheses = content.contains("(") && content.contains(")")
        let hasSemicolons = content.contains(";")
        let hasIndentation = content.contains("\n    ") || content.contains("\n\t")
        
        // Combine heuristics
        let structureScore = [hasBraces, hasParentheses, hasSemicolons, hasIndentation].filter { $0 }.count
        
        return hasCodeKeywords || structureScore >= 2
    }
    
    /// Check if content is valid JSON
    func isValidJSON(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must start and end with proper JSON delimiters
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
              (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) else {
            return false
        }
        
        // Try to parse as JSON
        guard let data = trimmed.data(using: .utf8) else { return false }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return true
        } catch {
            return false
        }
    }
    
    /// Check if content matches color format patterns
    func hasColorPatterns(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip if too long to be a simple color value
        guard trimmed.count <= 50 else { return false }
        
        let colorPatterns = [
            // Hex colors: #RGB, #RRGGBB, #RRGGBBAA
            #"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#,
            // RGB/RGBA: rgb(255,255,255), rgba(255,255,255,1.0)
            #"^rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*(,\s*[0-9.]+)?\s*\)$"#,
            // HSL/HSLA: hsl(360,100%,50%), hsla(360,100%,50%,1.0)
            #"^hsla?\(\s*\d{1,3}\s*,\s*\d{1,3}%\s*,\s*\d{1,3}%\s*(,\s*[0-9.]+)?\s*\)$"#,
            // CSS color names (common ones)
            #"^(red|blue|green|yellow|orange|purple|pink|brown|black|white|gray|grey)$"#
        ]
        
        return colorPatterns.contains { pattern in
            trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}

// MARK: - Content Type Detection
extension ClipContentType {
    
    /// Detect the most likely content type for the given content
    /// - Parameter content: The clipboard content to analyze
    /// - Returns: The detected content type, defaults to plainText if no specific type matches
    static func detect(from content: String) -> ClipContentType {
        // Use the sophisticated ContentTypeDetector for accurate detection
        let previewText = String(content.prefix(PreviewConfig.maxPreviewCharacters))
        return ContentTypeDetector.shared.detectContentType(for: previewText)
    }
    
    /// Get all applicable content types with confidence scores
    /// - Parameter content: The clipboard content to analyze
    /// - Returns: Array of content types with confidence scores, sorted by confidence
    static func detectAll(from content: String) -> [(type: ClipContentType, confidence: Double)] {
        return ContentTypeDetector.shared.getAllApplicableTypes(for: content)
    }
    
    /// Legacy detection method using basic heuristics (kept for fallback)
    /// - Parameter content: The clipboard content to analyze
    /// - Returns: The detected content type using basic heuristics
    static func detectLegacy(from content: String) -> ClipContentType {
        // Sort by detection priority and find the first match
        let sortedTypes = ClipContentType.allCases.sorted { $0.detectionPriority > $1.detectionPriority }
        
        for contentType in sortedTypes {
            if contentType.matches(content) && contentType != .plainText {
                return contentType
            }
        }
        
        // Default to plain text if no specific type matches
        return .plainText
    }
}
