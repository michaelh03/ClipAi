import Foundation
import SQLite

/// Protocol defining the interface for clipboard data storage
protocol ClipboardStorageProtocol {
    /// Load clipboard items from storage
    /// - Returns: Array of ClipItem objects
    /// - Throws: Storage-related errors
    func loadItems() async throws -> [ClipItem]
    
    /// Save clipboard items to storage
    /// - Parameter items: Array of ClipItem objects to save
    /// - Throws: Storage-related errors
    func saveItems(_ items: [ClipItem]) async throws
    
    /// Clear all stored items
    /// - Throws: Storage-related errors
    func clearStorage() async throws
}

/// JSON-based implementation of clipboard storage
class JSONClipboardStorage: ClipboardStorageProtocol {
    private let fileURL: URL
    private let fileManager = FileManager.default
    
    /// Initialize with custom file URL (primarily for testing)
    /// - Parameter fileURL: The URL where the JSON file should be stored
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    /// Initialize with default location in Application Support
    convenience init() throws {
        guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                                   in: .userDomainMask).first else {
            throw ClipboardStorageError.applicationSupportDirectoryNotFound
        }
        
        let clipAIDirectory = applicationSupportURL.appendingPathComponent("ClipAI")
        let fileURL = clipAIDirectory.appendingPathComponent("clipboard_history.json")
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: clipAIDirectory, 
                                              withIntermediateDirectories: true, 
                                              attributes: nil)
        
        self.init(fileURL: fileURL)
    }
    
    /// Load clipboard items from JSON file
    func loadItems() async throws -> [ClipItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            // Return empty array if file doesn't exist yet
            return []
        }
        
        let data = try Data(contentsOf: fileURL)
        
        // Handle empty file
        guard !data.isEmpty else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let items = try decoder.decode([ClipItem].self, from: data)
            return items
        } catch {
            throw ClipboardStorageError.decodingFailed(error)
        }
    }
    
    /// Save clipboard items to JSON file
    func saveItems(_ items: [ClipItem]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw ClipboardStorageError.encodingFailed(error)
        }
    }
    
    /// Clear all stored items by removing the storage file
    func clearStorage() async throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return // Nothing to clear
        }
        
        try fileManager.removeItem(at: fileURL)
    }
}

/// In-memory implementation of clipboard storage (fallback/testing)
class InMemoryClipboardStorage: ClipboardStorageProtocol {
    private var items: [ClipItem] = []
    
    func loadItems() async throws -> [ClipItem] {
        return items
    }
    
    func saveItems(_ items: [ClipItem]) async throws {
        self.items = items
    }
    
    func clearStorage() async throws {
        items.removeAll()
    }
}

/// SQLite-based implementation of clipboard storage
class SQLiteClipboardStorage: ClipboardStorageProtocol {
    private let db: Connection
    
    // Table and column definitions
    private let clipItems = Table("clip_items")
    private let id = SQLite.Expression<String>("id")
    private let content = SQLite.Expression<String>("content")
    private let timestamp = SQLite.Expression<Date>("timestamp")
    
    /// Initialize with custom database URL (primarily for testing)
    /// - Parameter databaseURL: The URL where the SQLite database should be stored
    init(databaseURL: URL) throws {
        self.db = try Connection(databaseURL.path)
        try createTableIfNeeded()
    }
    
    /// Initialize with default location in Application Support
    convenience init() throws {
        guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                                   in: .userDomainMask).first else {
            throw ClipboardStorageError.applicationSupportDirectoryNotFound
        }
        
        let clipAIDirectory = applicationSupportURL.appendingPathComponent("ClipAI")
        let databaseURL = clipAIDirectory.appendingPathComponent("clipboard_history_1.sqlite")
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: clipAIDirectory, 
                                              withIntermediateDirectories: true, 
                                              attributes: nil)
        
        try self.init(databaseURL: databaseURL)
    }
    
    /// Create the clip_items table if it doesn't exist
    private func createTableIfNeeded() throws {
        do {
            try db.run(clipItems.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(content)
                t.column(timestamp)
            })
        } catch {
            throw ClipboardStorageError.databaseError(error)
        }
    }
    
    /// Load clipboard items from SQLite database
    func loadItems() async throws -> [ClipItem] {
        return try await Task {
            do {
                let query = clipItems.order(timestamp.desc)
                var items: [ClipItem] = []
                
                for row in try db.prepare(query) {
                    let uuidString = row[id]
                    let item = ClipItem(
                        id: uuidString,
                        content: row[content],
                        timestamp: row[timestamp]
                    )
                    items.append(item)
                }
                
                return items
            } catch {
                throw ClipboardStorageError.databaseError(error)
            }
        }.value
    }
    
    /// Save clipboard items to SQLite database
    func saveItems(_ items: [ClipItem]) async throws {
        try await Task {
            do {
                // Start a transaction for better performance
                try db.transaction {
                    // Clear existing items
                    try db.run(clipItems.delete())
                    
                    // Insert all items
                    for item in items {
                        let insert = clipItems.insert(
                            id <- item.id,
                            content <- item.content,
                            timestamp <- item.timestamp
                        )
                        try db.run(insert)
                    }
                }
            } catch {
                throw ClipboardStorageError.databaseError(error)
            }
        }.value
    }
    
    /// Clear all stored items by deleting all rows from the table
    func clearStorage() async throws {
        try await Task {
            do {
                try db.run(clipItems.delete())
            } catch {
                throw ClipboardStorageError.databaseError(error)
            }
        }.value
    }
}

/// Errors that can occur during clipboard storage operations
enum ClipboardStorageError: LocalizedError {
    case applicationSupportDirectoryNotFound
    case encodingFailed(Error)
    case decodingFailed(Error)
    case fileSystemError(Error)
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryNotFound:
            return "Could not locate Application Support directory"
        case .encodingFailed(let error):
            return "Failed to encode clipboard data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode clipboard data: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
} 
