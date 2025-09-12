import Foundation
import AppKit

/// Protocol for notifying clipboard store changes
@MainActor
protocol ClipboardStoreDelegate: AnyObject {
    func clipboardStore(_ store: ClipboardStore, didUpdateItems items: [ClipItem])
}

/// Data manager that handles clipboard history without UI state
@MainActor
class ClipboardStore: PasteboardMonitorDelegate {
    /// Array of clipboard items, ordered by most recent first
    private(set) var items: [ClipItem] = []
    
    /// Delegate to notify of changes
    weak var delegate: ClipboardStoreDelegate?
    
    /// Maximum number of clipboard items to store
    private let maxItems = 100
    
    /// Storage backend for persistence
    private let storage: ClipboardStorageProtocol
    
    /// Flag to prevent recursive saves during loading
    private var isLoading = false
    
    /// Pasteboard monitor for automatic clipboard detection
    private let pasteboardMonitor: PasteboardMonitor
    
    /// Initialize the clipboard store with a storage backend and optional pasteboard monitor
    /// - Parameters:
    ///   - storage: The storage implementation to use (defaults to SQLite storage)
    ///   - monitor: The pasteboard monitor to use (defaults to creating a new one)
    init(storage: ClipboardStorageProtocol? = nil, monitor: PasteboardMonitor? = nil) {
        // Use provided storage or create default SQLite storage
        if let storage = storage {
            self.storage = storage
        } else {
            do {
                self.storage = try SQLiteClipboardStorage()
            } catch {
                // Fallback to JSON storage if SQLite fails to initialize
                print("Warning: Failed to initialize SQLite storage, trying JSON storage: \(error)")
                do {
                    self.storage = try JSONClipboardStorage()
                } catch {
                    // Final fallback to in-memory storage
                    print("Warning: Failed to initialize JSON storage, using in-memory storage: \(error)")
                    self.storage = InMemoryClipboardStorage()
                }
            }
        }
        
        // Use provided monitor or create new one
        self.pasteboardMonitor = monitor ?? PasteboardMonitor()
        
        // Set ourselves as the delegate for the pasteboard monitor
        self.pasteboardMonitor.delegate = self
        
        // Load existing items from storage
        Task {
            await loadItems()
        }
    }
    
    /// Load items from storage
    private func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loadedItems = try await storage.loadItems()
            items = Array(loadedItems.prefix(maxItems)) // Ensure we don't exceed maxItems
            delegate?.clipboardStore(self, didUpdateItems: items)
        } catch {
            print("Error loading clipboard items: \(error)")
            // Keep existing empty items array
        }
    }
    
    /// Save items to storage
    private func saveItems() async {
        guard !isLoading else { return } // Don't save while loading
        
        do {
            try await storage.saveItems(items)
        } catch {
            print("Error saving clipboard items: \(error)")
        }
    }
    
    /// Add a new clipboard item to the store
    /// - Parameters:
    ///   - content: The clipboard text content to add
    ///   - metadata: Optional metadata dictionary (defaults to empty)
    func addItem(content: String, metadata: [String: String] = [:]) {
        // Don't add empty content
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Don't add if it's the same as the most recent item
        if let mostRecent = items.first, mostRecent.content == content {
            return
        }
        
        // Remove any existing item with the same content
        items.removeAll { $0.content == content }
        
        // Create new item and insert at the beginning
        let newItem = ClipItem(content: content, metadata: metadata)
        items.insert(newItem, at: 0)
        
        // Trim to maximum items if needed
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        
        // Notify delegate of changes
        delegate?.clipboardStore(self, didUpdateItems: items)
        
        // Save to storage
        Task {
            await saveItems()
        }
    }
    
    /// Remove a specific item from the store
    /// - Parameter item: The ClipItem to remove
    func removeItem(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        
        // Notify delegate of changes
        delegate?.clipboardStore(self, didUpdateItems: items)
        
        // Save to storage
        Task {
            await saveItems()
        }
    }
    
    /// Remove an item at a specific index
    /// - Parameter index: The index of the item to remove
    func removeItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        items.remove(at: index)
        
        // Notify delegate of changes
        delegate?.clipboardStore(self, didUpdateItems: items)
        
        // Save to storage
        Task {
            await saveItems()
        }
    }
    
    /// Clear all clipboard items
    func clearAll() {
        items.removeAll()
        
        // Notify delegate of changes
        delegate?.clipboardStore(self, didUpdateItems: items)
        
        // Save to storage
        Task {
            await saveItems()
        }
    }
    
    /// Clear all clipboard items and storage
    func clearAllAndStorage() async {
        items.removeAll()
        
        // Notify delegate of changes
        delegate?.clipboardStore(self, didUpdateItems: items)
        
        do {
            try await storage.clearStorage()
        } catch {
            print("Error clearing storage: \(error)")
        }
    }
    
    /// Get an item by its ID
    /// - Parameter id: The UUID of the item to find
    /// - Returns: The ClipItem if found, nil otherwise
    func item(withId id: String) -> ClipItem? {
        return items.first { $0.id == id }
    }
    
    /// Check if the store contains an item with the given content
    /// - Parameter content: The content to search for
    /// - Returns: True if an item with this content exists
    func contains(content: String) -> Bool {
        return items.contains { $0.content == content }
    }
    
    /// Get the most recent clipboard item
    var mostRecentItem: ClipItem? {
        return items.first
    }
    
    /// Get the total count of items
    var count: Int {
        return items.count
    }
    
    /// Check if the store is empty
    var isEmpty: Bool {
        return items.isEmpty
    }
    
    /// Start monitoring the pasteboard for changes
    func startMonitoring() {
        pasteboardMonitor.startMonitoring()
    }
    
    /// Stop monitoring the pasteboard for changes
    func stopMonitoring() {
        pasteboardMonitor.stopMonitoring()
    }
}

// MARK: - PasteboardMonitorDelegate
@MainActor
extension ClipboardStore {
    /// Called when new text content is detected on the clipboard
    /// - Parameters:
    ///   - monitor: The pasteboard monitor that detected the change
    ///   - content: The new clipboard text content
    ///   - sourceAppMetadata: Metadata about the source application
    func pasteboardMonitor(_ monitor: PasteboardMonitor, didDetectNewContent content: String, sourceAppMetadata: [String: String]) {
        // Automatically add the new clipboard content to our store with source app metadata
        addItem(content: content, metadata: sourceAppMetadata)
    }
}

// MARK: - Debug Helpers
extension ClipboardStore {
    /// Add sample data for testing purposes
    func addSampleData() {
        let sampleContents = [
            "Hello, World!",
            "This is a longer clipboard item that demonstrates how the preview functionality works with extended text content.",
            "https://www.example.com",
            "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello, World!\")\n    }\n}",
            "user@example.com",
            "Short text",
            "Another clipboard entry with some more text to show in the list",
            "API_KEY=abc123def456ghi789",
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            "Final test item"
        ]
        
        for content in sampleContents {
            addItem(content: content)
        }
    }
} 
