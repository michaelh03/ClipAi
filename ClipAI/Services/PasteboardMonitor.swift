import Foundation
import AppKit

/// Protocol for objects that want to receive clipboard updates
@MainActor
protocol PasteboardMonitorDelegate: AnyObject {
    /// Called when new text content is detected on the clipboard
    /// - Parameters:
    ///   - monitor: The pasteboard monitor that detected the change
    ///   - content: The new clipboard text content
    ///   - sourceAppMetadata: Metadata about the source application
    func pasteboardMonitor(_ monitor: PasteboardMonitor, didDetectNewContent content: String, sourceAppMetadata: [String: String])
}

/// Service that monitors the system pasteboard for changes and notifies delegates of new content
@MainActor
class PasteboardMonitor: ObservableObject {
    
    // MARK: - Properties
    
    /// Delegate to notify of clipboard changes
    weak var delegate: PasteboardMonitorDelegate?
    
    /// Current change count from NSPasteboard
    private var lastChangeCount: Int = 0
    
    /// Timer for polling the pasteboard
    private var monitorTimer: Timer?
    
    /// Polling interval in seconds
    private let pollingInterval: TimeInterval = 0.5
    
    /// Flag to track if monitoring is active
    @Published private(set) var isMonitoring = false
    
    // MARK: - Initialization
    
    init() {
        // Initialize with current pasteboard state
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring the pasteboard for changes
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount
        
        // Create timer that fires on the main queue
        monitorTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForPasteboardChanges()
            }
        }
        
        print("PasteboardMonitor: Started monitoring clipboard")
    }
    
    /// Stop monitoring the pasteboard
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
        
        print("PasteboardMonitor: Stopped monitoring clipboard")
    }
    
    /// Manually check for pasteboard changes (useful for testing)
    func checkForPasteboardChanges() {
        let currentChangeCount = NSPasteboard.general.changeCount
        
        // Check if the pasteboard has changed
        guard currentChangeCount != lastChangeCount else { return }
        
        lastChangeCount = currentChangeCount
        
        // Get the current clipboard content
        guard let clipboardContent = getClipboardText() else { return }
        
        // Capture source app information
        let sourceAppMetadata = captureSourceAppMetadata()
        
        // Notify delegate of new content
        delegate?.pasteboardMonitor(self, didDetectNewContent: clipboardContent, sourceAppMetadata: sourceAppMetadata)
    }
    
    // MARK: - Private Methods
    
    /// Get the current text content from the clipboard
    /// - Returns: The clipboard text content, or nil if no text available
    private func getClipboardText() -> String? {
        let pasteboard = NSPasteboard.general
        
        // Check if clipboard contains text
        guard let string = pasteboard.string(forType: .string) else {
            return nil
        }
        
        // Don't return empty or whitespace-only strings
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty else {
            return nil
        }
        
        return string
    }
    
    /// Capture metadata about the source application that likely put content on the clipboard
    /// - Returns: Dictionary containing source app information
    private func captureSourceAppMetadata() -> [String: String] {
        var metadata: [String: String] = [:]
        
        // Get the frontmost application as a best guess for the source
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            metadata["sourceAppName"] = frontmostApp.localizedName ?? ""
            metadata["sourceAppBundleID"] = frontmostApp.bundleIdentifier ?? ""
            metadata["sourceAppPID"] = String(frontmostApp.processIdentifier)
            
            // Try to get the app icon path for later use
            if let bundleURL = frontmostApp.bundleURL {
                metadata["sourceAppBundlePath"] = bundleURL.path
            }
        }
        
        return metadata
    }
}

// MARK: - Convenience Methods
extension PasteboardMonitor {
    
    /// Get the current clipboard content without monitoring
    /// - Returns: Current clipboard text content or nil
    func getCurrentClipboardContent() -> String? {
        return getClipboardText()
    }
    
    /// Check if the pasteboard currently contains text
    /// - Returns: True if clipboard contains text content
    func hasTextContent() -> Bool {
        return NSPasteboard.general.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.string.rawValue])
    }
} 