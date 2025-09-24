import Foundation

/// Represents a message in the chat improvement conversation
struct ChatMessage: Identifiable, Codable {
    /// Unique identifier for the message
    let id: UUID

    /// The content of the message
    let content: String

    /// Whether this message is from the user (true) or AI (false)
    let isUser: Bool

    /// When the message was created
    let timestamp: Date

    /// Initialize a new chat message
    /// - Parameters:
    ///   - content: The message content
    ///   - isUser: Whether this is a user message
    init(content: String, isUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }

    /// Initialize with all parameters (for decoding/testing)
    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// MARK: - Convenience Extensions

extension ChatMessage {
    /// Create a user message
    static func userMessage(_ content: String) -> ChatMessage {
        return ChatMessage(content: content, isUser: true)
    }

    /// Create an AI response message
    static func aiMessage(_ content: String) -> ChatMessage {
        return ChatMessage(content: content, isUser: false)
    }

    /// Get a formatted timestamp for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }
}