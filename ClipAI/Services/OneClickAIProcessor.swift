import Foundation
import AppKit

/// Service that performs the one-click AI flow: resolve defaults, send request, and write result to clipboard
@MainActor
final class OneClickAIProcessor {
    static let shared = OneClickAIProcessor()
    private init() {}

    /// Check if one-click processing is ready for a specific action (default provider and action's prompt configured)
    /// - Parameter action: Action number (1, 2, or 3)
    func isReadyForOneClick(action: Int) async -> Bool {
        let providerRegistry = LLMProviderRegistry.shared
        guard await providerRegistry.getDefaultProvider() != nil else { return false }
        guard let id = UserDefaults.standard.string(forKey: "userSelectedPrompt\(action)"), UUID(uuidString: id) != nil else { return false }
        return true
    }
    
    /// Check if one-click processing is ready (default provider and default prompt configured) - legacy method
    func isReadyForOneClick() async -> Bool {
        return await isReadyForOneClick(action: 1)
    }

    /// Process provided text with default provider and action's prompt, writing the response back to the system clipboard
    /// - Parameters:
    ///   - content: Text to process
    ///   - action: Action number (1, 2, or 3)
    /// - Returns: The response written to the clipboard
    func processToClipboard(content: String, action: Int) async throws -> String {
        let providerRegistry = LLMProviderRegistry.shared
        let promptStore = PromptStore.shared

        guard let defaultProvider = await providerRegistry.getDefaultProvider() else {
            throw LLMError.serviceUnavailable(provider: "default")
        }

        guard let defaultPromptIdString = UserDefaults.standard.string(forKey: "userSelectedPrompt\(action)"),
              let defaultPromptId = UUID(uuidString: defaultPromptIdString) else {
            throw LLMError.invalidResponse(provider: "default", details: "System prompt not configured for action \(action)")
        }

        // Ensure prompts are available
        await promptStore.waitForInitialLoad()

        guard let systemPrompt = promptStore.prompts.first(where: { $0.id == defaultPromptId }) else {
            throw LLMError.invalidResponse(provider: "default", details: "System prompt not found for action \(action)")
        }

        let processedSystemPrompt = systemPrompt.processTemplate(with: content)

        let requestManager = LLMRequestManager()
        let response = try await requestManager.sendRequest(
            provider: defaultProvider,
            prompt: content,
            systemPrompt: processedSystemPrompt
        )

        // Write response to system clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(response, forType: .string)

        return response
    }
    
    /// Process provided text with default provider and prompt, writing the response back to the system clipboard - legacy method
    /// - Parameter content: Text to process
    /// - Returns: The response written to the clipboard
    func processToClipboard(content: String) async throws -> String {
        return try await processToClipboard(content: content, action: 1)
    }

    /// Read current clipboard text and process it to clipboard using action's configured prompt
    /// - Parameter action: Action number (1, 2, or 3)
    /// - Returns: The response written to the clipboard, or nil if no clipboard text
    func processCurrentClipboardToClipboard(action: Int) async throws -> String? {
        let pasteboardMonitor = PasteboardMonitor()
        guard let clipboardContent = pasteboardMonitor.getCurrentClipboardContent() else {
            return nil
        }
        return try await processToClipboard(content: clipboardContent, action: action)
    }
    
    /// Read current clipboard text and process it to clipboard using defaults - legacy method
    /// - Returns: The response written to the clipboard, or nil if no clipboard text
    func processCurrentClipboardToClipboard() async throws -> String? {
        return try await processCurrentClipboardToClipboard(action: 1)
    }
}

