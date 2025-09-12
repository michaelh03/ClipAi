import SwiftUI
import AppKit
import Foundation

/// A SwiftUI view that displays a single clipboard item in a row format
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Source app icon
            SourceAppIconView(clipItem: clipItem)
                .frame(width: 20, height: 20)
            
            // Content preview area
            VStack(alignment: .leading, spacing: 6) {
                // Main content preview with monospaced font and line clamping
                Text(clipItem.preview)
                .font(.system(.headline, design: .monospaced, weight: .regular))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .opacity(isHovered ? 1.0 : 0.9)
                
                // Timestamp and content type info
                HStack(spacing: 8) {
                   if let relative = clipItem.relativeDateDescription {
                       Text(relative)
                           .font(.system(.caption2, weight: .light))
                           .foregroundColor(.secondary)
                   }
                    
                    if clipItem.content.count > 80 {
                        Spacer()
                        Text("\(clipItem.content.count) chars")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                }
                .opacity(isHovered ? 0.9 : 0.7)
            }
            
            Spacer(minLength: 8)
            
            // Ask AI Button (hover-triggered)
            if isHovered {
                Button(action: {
                    // Check if one-click processing is available
                    if isOneClickProcessingAvailable {
                        performOneClickAIProcessing()
                    } else {
                        // Fallback to existing modal behavior
                        showingLLMRequest = true
                    }
                }) {
                    Group {
                        if isProcessingWithAI {
                            // Show loading indicator during processing
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if showSuccessIndicator {
                            // Show success checkmark
                            Image(systemName: "checkmark")
                                .font(.system(.caption, weight: .medium))
                                .foregroundColor(.green)
                        } else {
                            // Show sparkles icon with different styling based on availability
                            Image(systemName: "sparkles")
                                .font(.system(.caption, weight: .medium))
                                .foregroundColor(isAnyAPIKeyConfigured ? .accentColor : .secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isAnyAPIKeyConfigured || isProcessingWithAI)
                .help(getButtonHelpText())
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeInOut(duration: 0.12)),
                    removal: .opacity.animation(.easeInOut(duration: 0.12))
                ))
            }
            
            // Error message display
            if let errorMessage = showErrorMessage {
                Text("Error")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundColor(.red)
                    .help(errorMessage)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
            
            // Subtle indicator icon (space always reserved to avoid text shift)
            if showErrorMessage == nil {
                Image(systemName: "doc.on.doc")
                    .font(.system(.caption, weight: .medium))
                    .foregroundColor(.accentColor.opacity(0.7))
                    .opacity(isHovered ? 0.7 : 0) // Fade in/out on hover, slightly dimmed when Ask AI is visible
                    .frame(width: 14) // Reserve constant width
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        )
        .contentShape(Rectangle()) // Makes entire row tappable
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
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
