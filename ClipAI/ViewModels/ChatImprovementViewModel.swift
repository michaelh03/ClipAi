import Foundation
import SwiftUI
import AppKit

/// ViewModel for managing chat improvement conversations with AI
@MainActor
class ChatImprovementViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The original clipboard content that was processed
    @Published var originalContent: String = ""

    /// The original AI response to improve upon
    @Published var originalResponse: String = ""

    /// Chat conversation history
    @Published var chatHistory: [ChatMessage] = []

    /// Current user input for refinement
    @Published var currentInput: String = ""

    /// Whether an AI request is currently in progress
    @Published var isProcessing: Bool = false

    /// Current progress message during AI processing
    @Published var progressMessage: String = ""

    /// Whether there was an error in the last request
    @Published var hasError: Bool = false

    /// Error message to display
    @Published var errorMessage: String? = nil

    /// Whether the window should be dismissed
    @Published var shouldDismiss: Bool = false

    // MARK: - Private Properties

    private let requestManager: LLMRequestManager = LLMRequestManager()

    // MARK: - Closures

    /// Callback when the user wants to close the window
    var closeRequestedHandler: (() -> Void)?

    /// Callback when the final response should be copied to clipboard
    var copyResponseHandler: ((String) -> Void)?

    // MARK: - Initialization

    init() {
        // Empty initializer - will be configured when showing the chat
    }

    /// Configure the chat with initial content and response
    /// - Parameters:
    ///   - originalContent: The original clipboard content
    ///   - originalResponse: The AI's initial response
    func configure(originalContent: String, originalResponse: String) {
        let isNewContent = self.originalContent != originalContent || self.originalResponse != originalResponse

        self.originalContent = originalContent
        self.originalResponse = originalResponse

        // Only reset chat history if this is new content
        if isNewContent {
            self.chatHistory = [
                ChatMessage.aiMessage(originalResponse)
            ]
        }

        // Clear any current state (but preserve chat history)
        self.currentInput = ""
        self.isProcessing = false
        self.hasError = false
        self.errorMessage = nil
        self.progressMessage = ""
    }

    // MARK: - Public Methods

    /// Send a refinement request to improve the AI response
    func sendImprovementRequest() async {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let userMessage = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add user message to chat history
        chatHistory.append(ChatMessage.userMessage(userMessage))

        // Clear input
        currentInput = ""

        // Start processing
        isProcessing = true
        hasError = false
        errorMessage = nil
        progressMessage = "Improving response..."

        do {
            // Get default provider and AI configuration
            guard let provider = await LLMProviderRegistry.shared.getDefaultProvider() else {
                throw LLMError.serviceUnavailable(provider: "default")
            }

            // Build context from chat history
            let contextPrompt = buildContextPrompt(userRefinement: userMessage)

            // Send request
            let response = try await requestManager.sendRequest(
                provider: provider,
                prompt: contextPrompt,
                systemPrompt: "You are helping the user refine and improve a previous AI response. The user will provide the original content, the previous response, and their refinement request. Provide an improved response that addresses their specific feedback.",
                model: await getSelectedModel(for: provider)
            )

            // Add AI response to chat history
            chatHistory.append(ChatMessage.aiMessage(response))

        } catch {
            hasError = true
            errorMessage = "Failed to improve response: \(error.localizedDescription)"
            AppLog("ChatImprovementViewModel: Error improving response - \(error)", level: .error, category: "ChatImprovement")
        }

        isProcessing = false
        progressMessage = ""
    }

    /// Copy the latest AI response to clipboard
    func copyLatestResponse() {
        guard let latestAIResponse = getLatestAIResponse() else {
            AppLog("ChatImprovementViewModel: No AI response to copy", level: .warning, category: "ChatImprovement")
            return
        }

        // Copy to system clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(latestAIResponse, forType: .string)

        // Notify handler
        copyResponseHandler?(latestAIResponse)

        AppLog("ChatImprovementViewModel: Copied improved response to clipboard", level: .info, category: "ChatImprovement")
    }

    /// Get the latest AI response from chat history
    func getLatestAIResponse() -> String? {
        return chatHistory.last(where: { !$0.isUser })?.content
    }

    /// Clear the chat and reset to original response only
    func resetChat() {
        chatHistory = [
            ChatMessage.aiMessage(originalResponse)
        ]
        currentInput = ""
        isProcessing = false
        hasError = false
        errorMessage = nil
        progressMessage = ""
    }

    /// Force reset for new AI content - called when a new AI operation is triggered
    func forceResetForNewContent(originalContent: String, originalResponse: String) {
        self.originalContent = originalContent
        self.originalResponse = originalResponse

        // Always reset history for new content
        self.chatHistory = [
            ChatMessage.aiMessage(originalResponse)
        ]

        // Clear any current state
        self.currentInput = ""
        self.isProcessing = false
        self.hasError = false
        self.errorMessage = nil
        self.progressMessage = ""
    }

    /// Request to close the window
    func requestClose() {
        shouldDismiss = true
        closeRequestedHandler?()
    }

    /// Handle keyboard shortcuts
    func handleKeyboardShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        switch shortcut {
        case .send:
            if !isProcessing && !currentInput.isEmpty {
                Task {
                    await sendImprovementRequest()
                }
                return true
            }
        case .copy:
            copyLatestResponse()
            return true
        case .escape:
            requestClose()
            return true
        }
        return false
    }

    // MARK: - Private Methods

    /// Build the context prompt for the AI including conversation history
    private func buildContextPrompt(userRefinement: String) -> String {
        var prompt = "Original content:\n\(originalContent)\n\n"

        // Add conversation history
        if chatHistory.count > 1 {
            prompt += "Conversation history:\n"
            for message in chatHistory {
                let role = message.isUser ? "User" : "Assistant"
                prompt += "\(role): \(message.content)\n\n"
            }
        }

        prompt += "User's refinement request: \(userRefinement)\n\n"
        prompt += "Please provide an improved response that addresses the user's feedback while maintaining relevance to the original content."

        return prompt
    }

    /// Get the selected model for the given provider
    private func getSelectedModel(for provider: LLMProvider) async -> String? {
        guard let providerId = await LLMProviderRegistry.shared.getDefaultProviderId() else { return nil }
        let selectedModels = UserDefaults.standard.dictionary(forKey: "selectedModels") as? [String: String] ?? [:]
        return selectedModels[providerId]
    }
}

// MARK: - Keyboard Shortcuts

extension ChatImprovementViewModel {
    enum KeyboardShortcut {
        case send    // ⌘↩
        case copy    // ⌘C
        case escape  // Escape
    }
}