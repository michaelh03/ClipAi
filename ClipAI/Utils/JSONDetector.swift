import Foundation

/// JSON validation and detection utility with proper error handling
class JSONDetector {
    
    // MARK: - JSON Validation Types
    
    enum JSONValidationError: Error, LocalizedError {
        case invalidFormat
        case missingBraces
        case invalidSyntax(String)
        case emptyContent
        case notJSONLike
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid JSON format"
            case .missingBraces:
                return "Missing opening or closing braces/brackets"
            case .invalidSyntax(let details):
                return "Invalid JSON syntax: \(details)"
            case .emptyContent:
                return "Empty or whitespace-only content"
            case .notJSONLike:
                return "Content does not appear to be JSON-like"
            }
        }
    }
    
    struct JSONValidationResult {
        let isValid: Bool
        let confidence: Double
        let error: JSONValidationError?
        let detectedType: JSONType
        let statistics: JSONStatistics
        
        init(isValid: Bool, confidence: Double, error: JSONValidationError? = nil, detectedType: JSONType = .unknown, statistics: JSONStatistics) {
            self.isValid = isValid
            self.confidence = confidence
            self.error = error
            self.detectedType = detectedType
            self.statistics = statistics
        }
    }
    
    enum JSONType {
        case object
        case array
        case string
        case number
        case boolean
        case null
        case unknown
        
        var description: String {
            switch self {
            case .object: return "JSON Object"
            case .array: return "JSON Array"
            case .string: return "JSON String"
            case .number: return "JSON Number"
            case .boolean: return "JSON Boolean"
            case .null: return "JSON Null"
            case .unknown: return "Unknown"
            }
        }
    }
    
    struct JSONStatistics {
        let characterCount: Int
        let lineCount: Int
        let objectCount: Int
        let arrayCount: Int
        let stringCount: Int
        let numberCount: Int
        let booleanCount: Int
        let nullCount: Int
        let maxDepth: Int
        let keyCount: Int
        
        var complexity: JSONComplexity {
            let totalElements = objectCount + arrayCount + stringCount + numberCount + booleanCount + nullCount
            
            if totalElements <= 5 && maxDepth <= 2 {
                return .simple
            } else if totalElements <= 20 && maxDepth <= 4 {
                return .moderate
            } else {
                return .complex
            }
        }
    }
    
    enum JSONComplexity {
        case simple
        case moderate
        case complex
        
        var description: String {
            switch self {
            case .simple: return "Simple"
            case .moderate: return "Moderate"
            case .complex: return "Complex"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Validates if the given text is valid JSON
    /// - Parameter text: The text to validate
    /// - Returns: True if the text is valid JSON
    func isValidJSON(_ text: String) -> Bool {
        return validateJSON(text).isValid
    }
    
    /// Performs comprehensive JSON validation with detailed results
    /// - Parameter text: The text to validate
    /// - Returns: Detailed validation result
    func validateJSON(_ text: String) -> JSONValidationResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Early validation checks
        guard !trimmedText.isEmpty else {
            return JSONValidationResult(
                isValid: false,
                confidence: 0.0,
                error: .emptyContent,
                statistics: JSONStatistics.empty
            )
        }
        
        // Quick structural check
        guard isJSONLike(trimmedText) else {
            return JSONValidationResult(
                isValid: false,
                confidence: 0.0,
                error: .notJSONLike,
                statistics: calculateStatistics(for: trimmedText)
            )
        }
        
        // Attempt to parse as JSON
        do {
            let jsonData = trimmedText.data(using: .utf8) ?? Data()
            let parsedObject = try JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments])
            
            let detectedType = determineJSONType(parsedObject)
            let statistics = calculateStatistics(for: trimmedText)
            let confidence = calculateConfidence(for: trimmedText, statistics: statistics)
            
            return JSONValidationResult(
                isValid: true,
                confidence: confidence,
                detectedType: detectedType,
                statistics: statistics
            )
            
        } catch let error as NSError {
            let jsonError = mapParsingError(error)
            let statistics = calculateStatistics(for: trimmedText)
            let confidence = calculateHeuristicConfidence(for: trimmedText, statistics: statistics)
            
            return JSONValidationResult(
                isValid: false,
                confidence: confidence,
                error: jsonError,
                statistics: statistics
            )
        }
    }
    
    /// Attempts to fix common JSON formatting issues
    /// - Parameter text: The malformed JSON text
    /// - Returns: Fixed JSON text if possible, nil otherwise
    func attemptJSONFix(_ text: String) -> String? {
        var fixedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fix common issues
        fixedText = fixUnquotedKeys(fixedText)
        fixedText = fixSingleQuotes(fixedText)
        fixedText = fixTrailingCommas(fixedText)
        fixedText = fixMissingCommas(fixedText)
        
        // Validate the fixed version
        if isValidJSON(fixedText) {
            return fixedText
        }
        
        return nil
    }
    
    /// Extracts JSON objects from mixed content
    /// - Parameter text: Text that may contain JSON embedded within
    /// - Returns: Array of detected JSON strings
    func extractJSONFromText(_ text: String) -> [String] {
        var jsonObjects: [String] = []
        
        // Look for JSON object patterns
        let objectPattern = "\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}"
        let arrayPattern = "\\[[^\\[\\]]*(?:\\[[^\\[\\]]*\\][^\\[\\]]*)*\\]"
        
        let patterns = [objectPattern, arrayPattern]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
                let range = NSRange(location: 0, length: text.utf16.count)
                let matches = regex.matches(in: text, options: [], range: range)
                
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        let candidate = String(text[range])
                        if isValidJSON(candidate) {
                            jsonObjects.append(candidate)
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return jsonObjects
    }
    
    // MARK: - Private Helper Methods
    
    private func isJSONLike(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for basic JSON structure
        let startsWithBrace = trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
        let startsWithBracket = trimmed.hasPrefix("[") && trimmed.hasSuffix("]")
        let isQuotedString = trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")
        let isNumber = Double(trimmed) != nil
        let isBoolean = ["true", "false"].contains(trimmed.lowercased())
        let isNull = trimmed.lowercased() == "null"
        
        return startsWithBrace || startsWithBracket || isQuotedString || isNumber || isBoolean || isNull
    }
    
    private func determineJSONType(_ object: Any) -> JSONType {
        switch object {
        case is [String: Any]:
            return .object
        case is [Any]:
            return .array
        case is String:
            return .string
        case is NSNumber:
            return .number
        case is Bool:
            return .boolean
        case is NSNull:
            return .null
        default:
            return .unknown
        }
    }
    
    private func calculateStatistics(for text: String) -> JSONStatistics {
        let lines = text.components(separatedBy: .newlines)
        
        let objectCount = countOccurrences(of: "\\{", in: text)
        let arrayCount = countOccurrences(of: "\\[", in: text)
        let stringCount = countOccurrences(of: "\"[^\"]*\"", in: text)
        let numberCount = countOccurrences(of: "\\b\\d+(\\.\\d+)?\\b", in: text)
        let booleanCount = countOccurrences(of: "\\b(true|false)\\b", in: text)
        let nullCount = countOccurrences(of: "\\bnull\\b", in: text)
        let keyCount = countOccurrences(of: "\"[^\"]*\"\\s*:", in: text)
        let maxDepth = calculateMaxDepth(text)
        
        return JSONStatistics(
            characterCount: text.count,
            lineCount: lines.count,
            objectCount: objectCount,
            arrayCount: arrayCount,
            stringCount: stringCount,
            numberCount: numberCount,
            booleanCount: booleanCount,
            nullCount: nullCount,
            maxDepth: maxDepth,
            keyCount: keyCount
        )
    }
    
    private func calculateConfidence(for text: String, statistics: JSONStatistics) -> Double {
        var confidence: Double = 0.8 // Base confidence for valid JSON
        
        // Adjust based on complexity
        switch statistics.complexity {
        case .simple:
            confidence += 0.1
        case .moderate:
            confidence += 0.05
        case .complex:
            confidence -= 0.05
        }
        
        // Adjust based on formatting quality
        let hasConsistentIndentation = hasConsistentIndentation(text)
        if hasConsistentIndentation {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    private func calculateHeuristicConfidence(for text: String, statistics: JSONStatistics) -> Double {
        var confidence: Double = 0.0
        
        // Check for JSON-like patterns even if not valid
        if text.contains("{") && text.contains("}") {
            confidence += 0.3
        }
        
        if text.contains("[") && text.contains("]") {
            confidence += 0.2
        }
        
        if statistics.keyCount > 0 {
            confidence += 0.3
        }
        
        if statistics.stringCount > 0 {
            confidence += 0.1
        }
        
        if text.contains(":") {
            confidence += 0.1
        }
        
        return min(confidence, 0.7) // Max 0.7 for invalid JSON
    }
    
    private func countOccurrences(of pattern: String, in text: String) -> Int {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.matches(in: text, options: [], range: range).count
        } catch {
            return 0
        }
    }
    
    private func calculateMaxDepth(_ text: String) -> Int {
        var currentDepth = 0
        var maxDepth = 0
        
        for char in text {
            switch char {
            case "{", "[":
                currentDepth += 1
                maxDepth = max(maxDepth, currentDepth)
            case "}", "]":
                currentDepth = max(0, currentDepth - 1)
            default:
                break
            }
        }
        
        return maxDepth
    }
    
    private func hasConsistentIndentation(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let indentedLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && line.count > trimmed.count
        }
        
        // Check if at least 60% of non-empty lines have consistent indentation
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard nonEmptyLines.count > 0 else { return false }
        
        let indentationRatio = Double(indentedLines.count) / Double(nonEmptyLines.count)
        return indentationRatio > 0.6
    }
    
    private func mapParsingError(_ error: NSError) -> JSONValidationError {
        let errorMessage = error.localizedDescription
        
        if errorMessage.contains("bracket") || errorMessage.contains("brace") {
            return .missingBraces
        } else if errorMessage.contains("syntax") {
            return .invalidSyntax(errorMessage)
        } else {
            return .invalidFormat
        }
    }
    
    // MARK: - JSON Fixing Methods
    
    private func fixUnquotedKeys(_ text: String) -> String {
        let pattern = "(\\w+)\\s*:"
        let replacement = "\"$1\":"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
        } catch {
            return text
        }
    }
    
    private func fixSingleQuotes(_ text: String) -> String {
        return text.replacingOccurrences(of: "'", with: "\"")
    }
    
    private func fixTrailingCommas(_ text: String) -> String {
        let patterns = [
            ",\\s*}",  // Trailing comma before closing brace
            ",\\s*]"   // Trailing comma before closing bracket
        ]
        
        var fixedText = text
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: fixedText.utf16.count)
                let replacement = pattern.hasSuffix("}") ? "}" : "]"
                fixedText = regex.stringByReplacingMatches(in: fixedText, options: [], range: range, withTemplate: replacement)
            } catch {
                continue
            }
        }
        
        return fixedText
    }
    
    private func fixMissingCommas(_ text: String) -> String {
        // This is a complex fix that would require proper parsing
        // For now, return the original text
        return text
    }
}

// MARK: - Extensions

extension JSONDetector.JSONStatistics {
    static let empty = JSONDetector.JSONStatistics(
        characterCount: 0,
        lineCount: 0,
        objectCount: 0,
        arrayCount: 0,
        stringCount: 0,
        numberCount: 0,
        booleanCount: 0,
        nullCount: 0,
        maxDepth: 0,
        keyCount: 0
    )
}