import Foundation
import HotKey
import AppKit
import Carbon

/// Service responsible for managing global hotkey registration and handling
class HotKeyListener {
    // MARK: - Static Defaults
    /// Default: ⌃⌘V
    static let defaultShowShortcut = ShortcutSpec(
        keyCode: Int(kVK_ANSI_V),
        modifiers: Int(cmdKey | optionKey),
        display: "⌥⌘V"
    )

    /// Default: ⌃⌘⌥1
    static let defaultOneClickShortcut1 = ShortcutSpec(
        keyCode: Int(kVK_ANSI_1),
        modifiers: Int(cmdKey | optionKey),
        display: "⌘⌥1"
    )
    
    /// Default: ⌃⌘⌥2
    static let defaultOneClickShortcut2 = ShortcutSpec(
        keyCode: Int(kVK_ANSI_2),
        modifiers: Int(cmdKey | optionKey),
        display: "⌘⌥2"
    )
    /// Default: ⌘⌥3
    static let defaultOneClickShortcut3 = ShortcutSpec(
        keyCode: Int(kVK_ANSI_3),
        modifiers: Int(cmdKey | optionKey),
        display: "⌘⌥3"
    )

    /// Default: ⌘⌥I
    static let defaultChatImprovementShortcut = ShortcutSpec(
        keyCode: Int(kVK_ANSI_I),
        modifiers: Int(cmdKey | optionKey),
        display: "⌘⌥I"
    )

    /// Legacy default for migration: ⌃⌘⌥V
    static let legacyDefaultOneClickShortcut = ShortcutSpec(
        keyCode: Int(kVK_ANSI_V),
        modifiers: Int(cmdKey | controlKey | optionKey),
        display: "⌃⌘⌥V"
    )

    // MARK: - Instance State
    private var hotKey: HotKey?
    private var oneClickAI1HotKey: HotKey?
    private var oneClickAI2HotKey: HotKey?
    private var oneClickAI3HotKey: HotKey?
    private var chatImprovementHotKey: HotKey?
    private weak var popupController: PopupController?
    private weak var chatImprovementController: ChatImprovementController?

    /// Initialize the hotkey listener with a popup controller
    init(popupController: PopupController) {
        self.popupController = popupController
        // Note: Hotkeys will be registered by the caller after initialization
        // to avoid double registration and ensure proper timing
    }

    /// Set the chat improvement controller for handling chat improvement shortcuts
    func setChatImprovementController(_ controller: ChatImprovementController?) {
        self.chatImprovementController = controller
    }
    
    /// Handle hotkey press event
    private func handleHotKeyPressed() {
        // Ensure we're on the main thread for UI operations
        DispatchQueue.main.async { [weak self] in
            self?.popupController?.togglePopup()
        }
    }
    
    /// Handle one-click AI action 1 hotkey press
    private func handleOneClickAI1HotKeyPressed() {
        DispatchQueue.main.async {
            self.performOneClickAIForCurrentClipboard(action: 1)
        }
    }
    
    /// Handle one-click AI action 2 hotkey press
    private func handleOneClickAI2HotKeyPressed() {
        DispatchQueue.main.async {
            self.performOneClickAIForCurrentClipboard(action: 2)
        }
    }
    
    /// Handle one-click AI action 3 hotkey press
    private func handleOneClickAI3HotKeyPressed() {
        DispatchQueue.main.async {
            self.performOneClickAIForCurrentClipboard(action: 3)
        }
    }

    /// Handle chat improvement hotkey press
    private func handleChatImprovementHotKeyPressed() {
        DispatchQueue.main.async {
            self.performChatImprovement()
        }
    }
    
    /// Perform one-click AI processing using configured provider and system prompt for the specified action
    private func performOneClickAIForCurrentClipboard(action: Int) {
        Task { @MainActor in
            do {
                let result = try await OneClickAIProcessor.shared.processCurrentClipboardToClipboard(action: action)
                if result == nil { NSSound.beep() }
            } catch {
                NSSound.beep()
            }
        }
    }

    /// Perform chat improvement by checking for last processed result and showing chat window
    private func performChatImprovement() {
        Task { @MainActor in
            // Check if there's a recent AI processing result to improve
            guard let lastResult = OneClickAIProcessor.shared.getLastProcessedResult() else {
                AppLog("HotKeyListener: No recent AI processing result available for improvement", level: .info, category: "ChatImprovement")
                NSSound.beep()
                return
            }

            // Show the chat improvement window
            chatImprovementController?.showChatImprovement(
                originalContent: lastResult.content,
                originalResponse: lastResult.response
            )
        }
    }

    // MARK: - Public Controls
    /// Enable hotkey registration
    func enable() {
        AppLog("Enabling hotkeys - show: \(hotKey != nil), oneClick1: \(oneClickAI1HotKey != nil), oneClick2: \(oneClickAI2HotKey != nil), oneClick3: \(oneClickAI3HotKey != nil), chatImprovement: \(chatImprovementHotKey != nil)", level: .info, category: "Hotkeys")
        hotKey?.isPaused = false
        oneClickAI1HotKey?.isPaused = false
        oneClickAI2HotKey?.isPaused = false
        oneClickAI3HotKey?.isPaused = false
        chatImprovementHotKey?.isPaused = false
    }

    /// Disable hotkey registration
    func disable() {
        hotKey?.isPaused = true
        oneClickAI1HotKey?.isPaused = true
        oneClickAI2HotKey?.isPaused = true
        oneClickAI3HotKey?.isPaused = true
        chatImprovementHotKey?.isPaused = true
    }

    /// Unregister all hotkeys
    func unregisterAll() {
        hotKey = nil
        oneClickAI1HotKey = nil
        oneClickAI2HotKey = nil
        oneClickAI3HotKey = nil
        chatImprovementHotKey = nil
    }

    /// Update all hotkeys at once. Old registrations are removed first.
    /// - Parameters:
    ///   - showShortcut: New Show App shortcut
    ///   - oneClickShortcut1: New One‑Click AI Action 1 shortcut
    ///   - oneClickShortcut2: New One‑Click AI Action 2 shortcut
    ///   - oneClickShortcut3: New One‑Click AI Action 3 shortcut
    ///   - chatImprovementShortcut: New Chat Improvement shortcut
    func update(showShortcut: ShortcutSpec, oneClickShortcut1: ShortcutSpec, oneClickShortcut2: ShortcutSpec, oneClickShortcut3: ShortcutSpec, chatImprovementShortcut: ShortcutSpec) {
        updateShowShortcut(showShortcut)
        updateOneClickShortcut1(oneClickShortcut1)
        updateOneClickShortcut2(oneClickShortcut2)
        updateOneClickShortcut3(oneClickShortcut3)
        updateChatImprovementShortcut(chatImprovementShortcut)
    }

    /// Update only the Show App shortcut
    func updateShowShortcut(_ spec: ShortcutSpec) {
        // Clean up previous hotkey
        hotKey = nil
        hotKey = makeHotKey(from: spec) { [weak self] in
            AppLog("Show hotkey pressed!", level: .info, category: "Hotkeys")
            self?.handleHotKeyPressed()
        }
        AppLog("Updated show shortcut to: \(spec.display)", level: .info, category: "Hotkeys")
    }

    /// Update only the One‑Click AI Action 1 shortcut
    func updateOneClickShortcut1(_ spec: ShortcutSpec) {
        // Clean up previous hotkey
        oneClickAI1HotKey = nil
        oneClickAI1HotKey = makeHotKey(from: spec) { [weak self] in
            self?.handleOneClickAI1HotKeyPressed()
        }
        AppLog("Updated one-click action 1 shortcut to: \(spec.display)", level: .info, category: "Hotkeys")
    }
    
    /// Update only the One‑Click AI Action 2 shortcut
    func updateOneClickShortcut2(_ spec: ShortcutSpec) {
        // Clean up previous hotkey
        oneClickAI2HotKey = nil
        oneClickAI2HotKey = makeHotKey(from: spec) { [weak self] in
            self?.handleOneClickAI2HotKeyPressed()
        }
        AppLog("Updated one-click action 2 shortcut to: \(spec.display)", level: .info, category: "Hotkeys")
    }
    
    /// Update only the One‑Click AI Action 3 shortcut
    func updateOneClickShortcut3(_ spec: ShortcutSpec) {
        // Clean up previous hotkey
        oneClickAI3HotKey = nil
        oneClickAI3HotKey = makeHotKey(from: spec) { [weak self] in
            self?.handleOneClickAI3HotKeyPressed()
        }
        AppLog("Updated one-click action 3 shortcut to: \(spec.display)", level: .info, category: "Hotkeys")
    }

    /// Update only the Chat Improvement shortcut
    func updateChatImprovementShortcut(_ spec: ShortcutSpec) {
        // Clean up previous hotkey
        chatImprovementHotKey = nil
        chatImprovementHotKey = makeHotKey(from: spec) { [weak self] in
            self?.handleChatImprovementHotKeyPressed()
        }
        AppLog("Updated chat improvement shortcut to: \(spec.display)", level: .info, category: "Hotkeys")
    }

    // MARK: - Helpers
    private func makeHotKey(from spec: ShortcutSpec, handler: @escaping () -> Void) -> HotKey? {
        // Translate ShortcutSpec (Carbon codes) into HotKey
        let combo = KeyCombo(carbonKeyCode: UInt32(spec.keyCode), carbonModifiers: UInt32(spec.modifiers))
        AppLog("Creating HotKey with keyCode: \(spec.keyCode), modifiers: \(spec.modifiers), display: \(spec.display)", level: .debug, category: "Hotkeys")
        
        let hk = HotKey(keyCombo: combo)
        hk.keyDownHandler = handler
        hk.isPaused = false
        AppLog("HotKey created successfully, isPaused: \(hk.isPaused)", level: .debug, category: "Hotkeys")
        return hk
    }
    
    /// Clean up resources
    deinit {
        hotKey = nil
        oneClickAI1HotKey = nil
        oneClickAI2HotKey = nil
        oneClickAI3HotKey = nil
        chatImprovementHotKey = nil
    }
} 
