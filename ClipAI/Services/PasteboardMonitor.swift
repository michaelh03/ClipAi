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
        AppLog("PasteboardMonitor: Initialized with changeCount=\(lastChangeCount)", level: .debug, category: "Clipboard")
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring the pasteboard for changes
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount
        AppLog("PasteboardMonitor: Scheduling timer (interval=\(pollingInterval)s), initial changeCount=\(lastChangeCount)", level: .debug, category: "Clipboard")
        
        // Create timer that fires on the main queue
        monitorTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
//                AppLog("PasteboardMonitor: Timer tick", level: .debug, category: "Clipboard")
                self?.checkForPasteboardChanges()
            }
        }
        
        AppLog("PasteboardMonitor: Started monitoring clipboard", level: .info, category: "Clipboard")
    }
    
    /// Stop monitoring the pasteboard
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
        
        AppLog("PasteboardMonitor: Stopped monitoring clipboard (lastChangeCount=\(lastChangeCount))", level: .info, category: "Clipboard")
    }
    
    /// Manually check for pasteboard changes (useful for testing)
    func checkForPasteboardChanges() {
        let currentChangeCount = NSPasteboard.general.changeCount
//        AppLog("PasteboardMonitor: Checking pasteboard (current=\(currentChangeCount), last=\(lastChangeCount))", level: .debug, category: "Clipboard")
        
        // Check if the pasteboard has changed
        guard currentChangeCount != lastChangeCount else {
//            AppLog("PasteboardMonitor: No change detected", level: .debug, category: "Clipboard")
            return
        }
        
        lastChangeCount = currentChangeCount
        AppLog("PasteboardMonitor: Change detected, updated lastChangeCount=\(lastChangeCount)", level: .debug, category: "Clipboard")
        
        // Get the current clipboard content
        AppLog("PasteboardMonitor: Attempting to read clipboard text", level: .debug, category: "Clipboard")
        guard let clipboardContent = getClipboardText() else {
            AppLog("PasteboardMonitor: No readable text content found on clipboard", level: .debug, category: "Clipboard")
            return
        }
        let preview = clipboardContent.replacingOccurrences(of: "\n", with: " ")
        let previewSnippet = String(preview.prefix(80))
        AppLog("PasteboardMonitor: Clipboard text length=\(clipboardContent.count), preview=\"\(previewSnippet)\"", level: .debug, category: "Clipboard")
        
        // Capture source app information
        let sourceAppMetadata = captureSourceAppMetadata()
        if let name = sourceAppMetadata["sourceAppName"], let bundle = sourceAppMetadata["sourceAppBundleID"], let pid = sourceAppMetadata["sourceAppPID"] {
            AppLog("PasteboardMonitor: Source app name=\(name), bundleID=\(bundle), pid=\(pid)", level: .debug, category: "Clipboard")
        } else {
            AppLog("PasteboardMonitor: Source app metadata not available", level: .debug, category: "Clipboard")
        }
        
        // Notify delegate of new content
        if let delegate = delegate {
            AppLog("PasteboardMonitor: Notifying delegate of new content", level: .debug, category: "Clipboard")
            delegate.pasteboardMonitor(self, didDetectNewContent: clipboardContent, sourceAppMetadata: sourceAppMetadata)
        } else {
            AppLog("PasteboardMonitor: Delegate is nil; dropping clipboard update", level: .warning, category: "Clipboard")
        }
    }
    
    // MARK: - Private Methods
    
    /// Get the current text content from the clipboard
    /// - Returns: The clipboard text content, or nil if no text available
    private func getClipboardText() -> String? {
        let pasteboard = NSPasteboard.general
        
        // Check if clipboard contains text
        guard let string = pasteboard.string(forType: .string) else {
            AppLog("PasteboardMonitor: NSPasteboard has no string for type .string", level: .debug, category: "Clipboard")
            return nil
        }
        
        // Don't return empty or whitespace-only strings
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty else {
            AppLog("PasteboardMonitor: Clipboard string is empty or whitespace-only; ignoring", level: .debug, category: "Clipboard")
            return nil
        }
        AppLog("PasteboardMonitor: Clipboard string read successfully (length=\(string.count), trimmedLength=\(trimmedString.count))", level: .debug, category: "Clipboard")
        
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
            AppLog("PasteboardMonitor: Captured frontmost app metadata", level: .debug, category: "Clipboard")
        } else {
            AppLog("PasteboardMonitor: No frontmost application available for metadata", level: .debug, category: "Clipboard")
        }
        
        return metadata
    }
}

// MARK: - Convenience Methods
extension PasteboardMonitor {
    
    /// Get the current clipboard content without monitoring
    /// - Returns: Current clipboard text content or nil
    func getCurrentClipboardContent() -> String? {
        AppLog("PasteboardMonitor: getCurrentClipboardContent invoked", level: .debug, category: "Clipboard")
        return getClipboardText()
    }
    
    /// Check if the pasteboard currently contains text
    /// - Returns: True if clipboard contains text content
    func hasTextContent() -> Bool {
        let result = NSPasteboard.general.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.string.rawValue])
        AppLog("PasteboardMonitor: hasTextContent=\(result)", level: .debug, category: "Clipboard")
        return result
    }
} 
