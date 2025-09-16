import Foundation

/// Main content type detector that orchestrates all detection rules
class ContentTypeDetector {
    
    // MARK: - Singleton
    
    static let shared = ContentTypeDetector()
    
    // MARK: - Properties
    
    private let codeDetector = CodeDetector()
    private let jsonDetector = JSONDetector()
    
    private lazy var detectionRules: [ClipContentType: [ContentDetectionRule]] = {
        return [
            .color: [
                .hexColor,
                .rgbColor,
                .hslColor
            ],
            .json: [
                .jsonStructure,
                .jsonKeyValue
            ],
            .code: [
                .codeFileExtensions,
                .codeKeywords,
                .codeBraces
            ],
            .plainText: [
                .plainText
            ]
        ]
    }()
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton
    }
    
    // MARK: - Public Methods
    
    /// Detects the content type of the given clipboard text
    /// - Parameter text: The clipboard text to analyze
    /// - Returns: The detected content type
    func detectContentType(for text: String) -> ClipContentType {
        // Early return for empty or whitespace-only text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return .plainText
        }
        
        // Detect in order of specificity (most specific first)
        if detectColor(trimmedText) {
            return .color
        }
        
        if detectJSON(trimmedText) {
            return .json
        }
        
        if detectCode(trimmedText) {
            return .code
        }
        
        // Default to plain text
        return .plainText
    }
    
    /// Gets all applicable content types for the given text, sorted by confidence
    /// - Parameter text: The clipboard text to analyze
    /// - Returns: Array of content types sorted by detection confidence (highest first)
    func getAllApplicableTypes(for text: String) -> [(type: ClipContentType, confidence: Double)] {
        var results: [(type: ClipContentType, confidence: Double)] = []
        
        for (contentType, rules) in detectionRules {
            let confidence = calculateConfidence(for: text, using: rules)
            if confidence > 0 {
                results.append((type: contentType, confidence: confidence))
            }
        }
        
        // Sort by confidence (highest first), then by type priority
        return results.sorted { first, second in
            if first.confidence == second.confidence {
                return first.type.detectionPriority > second.type.detectionPriority
            }
            return first.confidence > second.confidence
        }
    }
    
    // MARK: - Private Detection Methods
    
    private func detectColor(_ text: String) -> Bool {
        let rules = detectionRules[.color] ?? []
        return rules.contains { $0.matches(text) }
    }
    
    private func detectJSON(_ text: String) -> Bool {
        // Use specialized JSON detector for more accurate detection
        return jsonDetector.isValidJSON(text)
    }
    
    private func detectCode(_ text: String) -> Bool {
        // Use specialized code detector for more sophisticated analysis
        return codeDetector.isCode(text)
    }
    
    private func calculateConfidence(for text: String, using rules: [ContentDetectionRule]) -> Double {
        let matchingRules = rules.filter { $0.matches(text) }
        
        if matchingRules.isEmpty {
            return 0.0
        }
        
        // Calculate weighted confidence based on rule priorities
        let totalPriority = rules.reduce(0) { $0 + $1.priority }
        let matchingPriority = matchingRules.reduce(0) { $0 + $1.priority }
        
        guard totalPriority > 0 else {
            // If no priorities set, use simple match ratio
            return Double(matchingRules.count) / Double(rules.count)
        }
        
        // Normalize to 0-1 range
        let baseConfidence = Double(matchingPriority) / Double(totalPriority)
        
        // Apply bonus for multiple matching rules
        let matchRatio = Double(matchingRules.count) / Double(rules.count)
        let bonusMultiplier = 1.0 + (matchRatio * 0.2) // Up to 20% bonus
        
        return min(baseConfidence * bonusMultiplier, 1.0)
    }
}

// MARK: - ClipContentType Extension (detectionPriority already defined in ClipContentType.swift)

// MARK: - Detection Statistics

struct ContentDetectionStatistics {
    let contentType: ClipContentType
    let confidence: Double
    let matchingRules: [String]
    let processingTime: TimeInterval
    let textLength: Int
    let lineCount: Int
    
    init(contentType: ClipContentType, confidence: Double, matchingRules: [String], processingTime: TimeInterval, text: String) {
        self.contentType = contentType
        self.confidence = confidence
        self.matchingRules = matchingRules
        self.processingTime = processingTime
        self.textLength = text.count
        self.lineCount = text.components(separatedBy: .newlines).count
    }
}

// MARK: - Debug Extension

extension ContentTypeDetector {
    
    /// Provides detailed detection statistics for debugging
    /// - Parameter text: The text to analyze
    /// - Returns: Detailed statistics about the detection process
    func getDetectionStatistics(for text: String) -> ContentDetectionStatistics {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let detectedType = detectContentType(for: text)
        let allTypes = getAllApplicableTypes(for: text)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTime = endTime - startTime
        
        // Find matching rules for the detected type
        let rules = detectionRules[detectedType] ?? []
        let matchingRuleNames = rules.filter { $0.matches(text) }.map { $0.name }
        
        let confidence = allTypes.first { $0.type == detectedType }?.confidence ?? 0.0
        
        return ContentDetectionStatistics(
            contentType: detectedType,
            confidence: confidence,
            matchingRules: matchingRuleNames,
            processingTime: processingTime,
            text: text
        )
    }
}
