import Foundation

/// Represents a single clipboard item in the clipboard history
struct ClipItem: Identifiable, Codable, Equatable {
    /// Unique identifier for the clipboard item
    let id: String

    /// The actual clipboard content (text)
    let content: String

    /// When this item was added to the clipboard
    let timestamp: Date

    /// Metadata dictionary for storing additional information about the clip item
    let metadata: [String: String]

    /// Preview text (first 100 characters) for UI display and content type detection
    /// This is computed once at initialization to avoid performance issues with large content
    let preview: String

    /// Content type detected from preview text (computed once at initialization)
    /// Uses preview instead of full content for performance
    let contentType: ClipContentType

    /// Initialize a new clipboard item with the given content
    /// - Parameters:
    ///   - content: The clipboard text content
    ///   - metadata: Optional metadata dictionary (defaults to empty)
    init(content: String, metadata: [String: String] = [:]) {
        self.id = UUID.uuidV7String()
        self.content = content
        self.timestamp = Date()
        self.metadata = metadata

        // Compute preview once at initialization (first 100 chars)
        let maxLength = 100
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.count <= maxLength {
            self.preview = trimmedContent
        } else {
            self.preview = String(trimmedContent.prefix(maxLength)) + "..."
        }

        // Detect content type from preview for performance (not full content)
        self.contentType = ClipContentType.detect(from: self.preview)
    }
    
    /// Initialize a clipboard item with all properties (used for decoding)
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - content: Clipboard text content
    ///   - timestamp: When the item was created
    ///   - metadata: Metadata dictionary
    init(id: String, content: String, timestamp: Date, metadata: [String: String] = [:]) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata

        // Compute preview once at initialization (first 100 chars)
        let maxLength = 100
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.count <= maxLength {
            self.preview = trimmedContent
        } else {
            self.preview = String(trimmedContent.prefix(maxLength)) + "..."
        }

        // Detect content type from preview for performance (not full content)
        self.contentType = ClipContentType.detect(from: self.preview)
    }
}

// MARK: - Computed Properties
extension ClipItem {
    /// Formatted timestamp string for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }
    
    // New: Relative date description (nil if copied today)
    var relativeDateDescription: String? {
        let calendar = Calendar.current
        let now = Date()
        // Hide label for items copied today
        if calendar.isDateInToday(timestamp) {
            return nil
        }

        // High-precision buckets
        if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        }

        // Days-ago calculation for broader ranges
        let daysAgo = calendar.dateComponents([.day], from: timestamp, to: now).day ?? 0

        if daysAgo < 7 {
            return "This week"      // Within the last 7 days (excluding Yesterday)
        } else if daysAgo < 30 {
            return "This month"     // Within the last 30 days
        } else if calendar.isDate(timestamp, equalTo: now, toGranularity: .year) {
            return "Earlier this year"
        } else {
            return formattedTimestamp // Fallback: short date (mm/dd/yy)
        }
    }

    /// The preview provider that should handle this clip item
    /// This is a computed property that uses the registry to find the best provider
    var previewProvider: (any ClipItemPreviewProvider)? {
        // This will be populated by the PreviewProviderRegistry
        // For now, return nil - the registry will be used by the UI layer
        return nil
    }
    
    /// The name of the source application that created this clipboard item
    var sourceAppName: String? {
        return metadata["sourceAppName"]?.isEmpty == false ? metadata["sourceAppName"] : nil
    }
    
    /// The bundle identifier of the source application
    var sourceAppBundleID: String? {
        return metadata["sourceAppBundleID"]?.isEmpty == false ? metadata["sourceAppBundleID"] : nil
    }
    
    /// The bundle path of the source application (for getting app icon)
    var sourceAppBundlePath: String? {
        return metadata["sourceAppBundlePath"]?.isEmpty == false ? metadata["sourceAppBundlePath"] : nil
    }
} 
