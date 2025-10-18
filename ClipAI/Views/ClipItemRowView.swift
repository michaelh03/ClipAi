import SwiftUI
import AppKit
import Foundation

// MARK: - Content Type Support

/// Enum to categorize clipboard content for better UI representation
enum ContentType {
    case text
    case url
    case multiline
    case longText
}

/// View that displays appropriate icon for different content types
struct ContentTypeIcon: View {
    let type: ContentType

    var body: some View {
        Group {
            switch type {
            case .url:
                Image(systemName: "link")
                    .foregroundColor(.blue)
            case .multiline:
                Image(systemName: "text.alignleft")
                    .foregroundColor(.purple)
            case .longText:
                Image(systemName: "doc.text")
                    .foregroundColor(.orange)
            case .text:
                Image(systemName: "textformat")
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(size: 11, weight: .medium))
    }
}

/// A SwiftUI view that displays a single clipboard item in a modern card format
struct ClipItemRowView: View {
    let clipItem: ClipItem
    @State private var isHovered = false
    @State private var showingLLMRequest = false
    @State private var isAnyAPIKeyConfigured = false

    // One-click processing states
    @State private var isProcessingWithAI = false
    @State private var showSuccessIndicator = false
    @State private var showErrorMessage: String? = nil

    // Services
    private let keychainService = KeychainService()

    // MARK: - Computed Properties

    /// Check if one-click processing is available (requires default provider and prompt)
    private var isOneClickProcessingAvailable: Bool {
        // Check if default provider and at least one prompt are configured
        return isAnyAPIKeyConfigured &&
               (UserDefaults.standard.string(forKey: "userSelectedPrompt1") != nil ||
                UserDefaults.standard.string(forKey: "userSelectedPrompt2") != nil ||
                UserDefaults.standard.string(forKey: "userSelectedPrompt3") != nil)
    }

    /// Get content type for better UI styling
    /// Uses preview text for performance - no need to check full content for UI display
    private var contentType: ContentType {
        if clipItem.preview.hasPrefix("http://") || clipItem.preview.hasPrefix("https://") {
            return .url
        } else if clipItem.preview.contains("\n") && clipItem.preview.count > 50 {
            return .multiline
        } else if clipItem.preview.count > 50 {
            return .longText
        } else {
            return .text
        }
    }

    /// Get preview text with better formatting
    /// Uses preview text for performance - sufficient for UI display
    private var formattedPreview: String {
        switch contentType {
        case .url:
            return clipItem.preview
        case .multiline:
            return clipItem.preview.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? clipItem.preview
        default:
            return clipItem.preview
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Source app icon with improved styling
                SourceAppIconView(clipItem: clipItem)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                            .scaleEffect(isHovered ? 1.1 : 1.0)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isHovered)

                // Content preview area with better hierarchy
                VStack(alignment: .leading, spacing: 4) {
                    // Content type indicator and preview
                    HStack(spacing: 8) {
                        ContentTypeIcon(type: contentType)

                        Text(formattedPreview)
                            .font(.system(.body, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }

                    // Secondary line with metadata
                    HStack(spacing: 8) {
                        if let relative = clipItem.relativeDateDescription {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10, weight: .medium))
                                Text(relative)
                                    .font(.system(.caption, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }

                        if contentType == .multiline {
                            HStack(spacing: 4) {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 10, weight: .medium))
                                Text("\(clipItem.preview.components(separatedBy: .newlines).count)+ lines")
                                    .font(.system(.caption, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        } else if clipItem.preview.count > 50 {
                            HStack(spacing: 4) {
                                Image(systemName: "textformat.size")
                                    .font(.system(size: 10, weight: .medium))
                                Text("100+ chars")
                                    .font(.system(.caption, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Action buttons area
                        HStack(spacing: 8) {
                            // Error message display
                            if let errorMessage = showErrorMessage {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10, weight: .medium))
                                    Text("Error")
                                        .font(.system(.caption2, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .help(errorMessage)
                                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                            }

                            // Ask AI Button (hover-triggered)
                            if isHovered && showErrorMessage == nil {
                                Button(action: {
                                    // Check if one-click processing is available
                                    if isOneClickProcessingAvailable {
                                        performOneClickAIProcessing()
                                    } else {
                                        // Fallback to existing modal behavior
                                        showingLLMRequest = true
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Group {
                                            if isProcessingWithAI {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                            } else if showSuccessIndicator {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.green)
                                            } else {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(isAnyAPIKeyConfigured ? .accentColor : .secondary)
                                            }
                                        }

                                        if !isProcessingWithAI && !showSuccessIndicator {
                                            Text("AI")
                                                .font(.system(.caption2, weight: .semibold))
                                                .foregroundColor(isAnyAPIKeyConfigured ? .accentColor : .secondary)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(isAnyAPIKeyConfigured ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(!isAnyAPIKeyConfigured || isProcessingWithAI)
                                .help(getButtonHelpText())
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity)
                                ))
                            }

                            // Copy indicator (always visible but subtle)
                            if !isHovered || showErrorMessage != nil {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isHovered ? Color.primary.opacity(0.1) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle()) // Makes entire row tappable
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            checkAPIKeyConfiguration()
        }
        .sheet(isPresented: $showingLLMRequest) {
            LLMRequestView(clipboardContent: clipItem.content)
        }
    }
    
    // MARK: - One-Click Processing Methods
    
    /// Perform one-click AI processing with default settings
    private func performOneClickAIProcessing() {
        // Check if defaults are configured
        guard isOneClickProcessingAvailable else {
            // Fallback to existing modal behavior
            showingLLMRequest = true
            return
        }
        
        // Start processing with loading state
        withAnimation(.easeInOut(duration: 0.2)) {
            isProcessingWithAI = true
        }
        
        // Process in background
        Task {
            await processClipboardContentWithDefaults()
        }
    }
    
    /// Process clipboard content with default provider and prompt
    @MainActor
    private func processClipboardContentWithDefaults() async {
        do {
            // Use shared processor
            _ = try await OneClickAIProcessor.shared.processToClipboard(content: clipItem.content)
            
            // Show success feedback
            withAnimation(.easeInOut(duration: 0.3)) {
                showSuccessIndicator = true
            }
            
            // Hide success indicator after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.showSuccessIndicator = false
                }
            }
            
        } catch {
            // Show error feedback
            showErrorMessage = error.localizedDescription
            
            // Hide error after delay  
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.showErrorMessage = nil
            }
        }
        
        // Stop processing state
        withAnimation(.easeInOut(duration: 0.2)) {
            isProcessingWithAI = false
        }
    }
    

    
    // MARK: - Helper Methods
    
    /// Get appropriate help text for the sparkles button based on current state
    private func getButtonHelpText() -> String {
        if !isAnyAPIKeyConfigured {
            return "No API keys configured"
        } else if isProcessingWithAI {
            return "Processing with AI..."
        } else if showSuccessIndicator {
            return "AI processing completed!"
        } else if isOneClickProcessingAvailable {
            return "Process with AI (one-click)"
        } else {
            return "Ask AI"
        }
    }
    
    /// Check if any API keys are configured for LLM providers
    private func checkAPIKeyConfiguration() {
        // Check for known provider IDs
        let knownProviders = ["openai", "gemini", "google", "claude", "anthropic"]
        
        isAnyAPIKeyConfigured = knownProviders.contains { providerId in
            do {
                return try keychainService.hasAPIKey(for: providerId)
            } catch {
                return false
            }
        }
    }
}

#if DEBUG
// MARK: - Preview
struct ClipItemRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Short content preview
            ClipItemRowView(clipItem: ClipItem(content: "Hello, world!"))
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Short Content")
            
            // Long content preview (will be truncated)
            ClipItemRowView(clipItem: ClipItem(content: "This is a very long clipboard content that will be truncated to show how the preview works with longer text that exceeds the 80 character limit."))
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Long Content")
            
            // Multi-line content preview
            ClipItemRowView(clipItem: ClipItem(content: "Line 1\nLine 2\nLine 3\nThis should demonstrate how multi-line content is handled"))
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Multi-line Content")
            
            // Content with source app metadata
            ClipItemRowView(clipItem: ClipItem(content: "Sample text from Safari", metadata: [
                "sourceAppName": "Safari",
                "sourceAppBundleID": "com.apple.Safari"
            ]))
                .previewLayout(.sizeThatFits)
                .previewDisplayName("With Source App")
        }
    }
}
#endif

// MARK: - Source App Icon View
/// A view that displays the icon of the source application for a clipboard item
struct SourceAppIconView: View {
    let clipItem: ClipItem
    @State private var appIcon: NSImage?
    
    var body: some View {
        Group {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback icon when no source app is available
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadAppIcon()
        }
        .help(clipItem.sourceAppName ?? "Unknown source")
    }
    
    private func loadAppIcon() {
        // Try to get app icon from bundle identifier first (most reliable)
        if let bundleID = clipItem.sourceAppBundleID,
           let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            appIcon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            return
        }
        
        // Fallback: try to get icon from bundle path
        if let bundlePath = clipItem.sourceAppBundlePath {
            appIcon = NSWorkspace.shared.icon(forFile: bundlePath)
            return
        }
        
        // No icon available, will show fallback
        appIcon = nil
    }
} 
