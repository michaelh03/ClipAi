import Foundation
import SwiftUI
import Carbon
import LaunchAtLogin

final class GeneralSettingsViewModel: ObservableObject {
    struct InlineMessage {
        let text: String
        let isError: Bool
    }

    // MARK: - Published State
    @Published var showShortcutDisplay: String
    @Published var oneClick1ShortcutDisplay: String
    @Published var oneClick2ShortcutDisplay: String
    @Published var oneClick3ShortcutDisplay: String
    @Published var showShortcutMessage: InlineMessage?
    @Published var oneClick1ShortcutMessage: InlineMessage?
    @Published var oneClick2ShortcutMessage: InlineMessage?
    @Published var oneClick3ShortcutMessage: InlineMessage?
    @Published var isStartAtLoginEnabled: Bool {
        didSet {
            // Avoid redundant writes
            if LaunchAtLogin.isEnabled != isStartAtLoginEnabled {
                LaunchAtLogin.isEnabled = isStartAtLoginEnabled
            }
        }
    }
    
    @Published var previewFontSize: CGFloat {
        didSet {
            SettingsStorage.savePreviewFontSize(previewFontSize)
        }
    }
    
    @Published var previewTheme: String {
        didSet {
            SettingsStorage.savePreviewTheme(previewTheme)
        }
    }

    // Keep the current effective shortcut specs for validation/conflict checks
    @Published private(set) var showShortcutSpec: ShortcutSpec
    @Published private(set) var oneClick1ShortcutSpec: ShortcutSpec
    @Published private(set) var oneClick2ShortcutSpec: ShortcutSpec
    @Published private(set) var oneClick3ShortcutSpec: ShortcutSpec
    
    // MARK: - Font Size Constants
    /// Default font size for previews
    static let defaultPreviewFontSize: CGFloat = 13
    /// Minimum font size
    static let minPreviewFontSize: CGFloat = 10
    /// Maximum font size
    static let maxPreviewFontSize: CGFloat = 24
    
    // MARK: - Theme Constants
    /// Default theme for code preview
    static let defaultPreviewTheme: String = "github"
    /// Available theme options
    static let availableThemes = [
        ("GitHub Light", "github"),
        ("GitHub Dark", "github-dark"),
        ("VS Light", "vs"),
        ("VS Dark", "vs-dark"),
        ("Xcode", "xcode"),
        ("Atom One Dark", "atom-one-dark")
    ]

    init() {
        // Load persisted shortcuts or fall back to defaults
        let persistedShow: ShortcutSpec = SettingsStorage.loadShortcut(for: .showShortcut) ?? HotKeyListener.defaultShowShortcut
        
        // Handle migration from legacy one-click shortcut to action 1
        let persistedOneClick1: ShortcutSpec
        if let legacyShortcut = SettingsStorage.loadShortcut(for: .oneClickShortcut) {
            // Migrate legacy shortcut to action 1
            persistedOneClick1 = legacyShortcut
            SettingsStorage.saveShortcut(legacyShortcut, for: .oneClickShortcut1)
            // Remove legacy key
            UserDefaults.standard.removeObject(forKey: GeneralSettingsKeys.oneClickShortcut.rawValue)
        } else {
            persistedOneClick1 = SettingsStorage.loadShortcut(for: .oneClickShortcut1) ?? HotKeyListener.defaultOneClickShortcut1
        }
        
        let persistedOneClick2: ShortcutSpec = SettingsStorage.loadShortcut(for: .oneClickShortcut2) ?? HotKeyListener.defaultOneClickShortcut2
        let persistedOneClick3: ShortcutSpec = SettingsStorage.loadShortcut(for: .oneClickShortcut3) ?? HotKeyListener.defaultOneClickShortcut3

        self.showShortcutSpec = persistedShow
        self.oneClick1ShortcutSpec = persistedOneClick1
        self.oneClick2ShortcutSpec = persistedOneClick2
        self.oneClick3ShortcutSpec = persistedOneClick3

        self.showShortcutDisplay = persistedShow.display
        self.oneClick1ShortcutDisplay = persistedOneClick1.display
        self.oneClick2ShortcutDisplay = persistedOneClick2.display
        self.oneClick3ShortcutDisplay = persistedOneClick3.display
        self.showShortcutMessage = nil
        self.oneClick1ShortcutMessage = nil
        self.oneClick2ShortcutMessage = nil
        self.oneClick3ShortcutMessage = nil
        // Reflect actual system setting managed by LaunchAtLogin
        self.isStartAtLoginEnabled = LaunchAtLogin.isEnabled
        
        // Load persisted font size or fall back to default
        self.previewFontSize = SettingsStorage.loadPreviewFontSize() ?? GeneralSettingsViewModel.defaultPreviewFontSize
        
        // Load persisted theme or fall back to default
        self.previewTheme = SettingsStorage.loadPreviewTheme() ?? GeneralSettingsViewModel.defaultPreviewTheme
    }

    // MARK: - Intent
    func resetShowToDefault() {
        // Apply default spec, persist, and notify so runtime hotkeys update immediately
        let defaultSpec = HotKeyListener.defaultShowShortcut
        showShortcutSpec = defaultSpec
        showShortcutDisplay = defaultSpec.display
        SettingsStorage.saveShortcut(defaultSpec, for: .showShortcut)
        NotificationCenter.default.post(name: .generalShortcutsChanged, object: nil)
        showShortcutMessage = InlineMessage(text: "Reset to default", isError: false)
    }

    func resetOneClick1ToDefault() {
        let defaultSpec = HotKeyListener.defaultOneClickShortcut1
        oneClick1ShortcutSpec = defaultSpec
        oneClick1ShortcutDisplay = defaultSpec.display
        SettingsStorage.saveShortcut(defaultSpec, for: .oneClickShortcut1)
        NotificationCenter.default.post(name: .generalShortcutsChanged, object: nil)
        oneClick1ShortcutMessage = InlineMessage(text: "Reset to default", isError: false)
    }
    
    func resetOneClick2ToDefault() {
        let defaultSpec = HotKeyListener.defaultOneClickShortcut2
        oneClick2ShortcutSpec = defaultSpec
        oneClick2ShortcutDisplay = defaultSpec.display
        SettingsStorage.saveShortcut(defaultSpec, for: .oneClickShortcut2)
        NotificationCenter.default.post(name: .generalShortcutsChanged, object: nil)
        oneClick2ShortcutMessage = InlineMessage(text: "Reset to default", isError: false)
    }
    
    func resetOneClick3ToDefault() {
        let defaultSpec = HotKeyListener.defaultOneClickShortcut3
        oneClick3ShortcutSpec = defaultSpec
        oneClick3ShortcutDisplay = defaultSpec.display
        SettingsStorage.saveShortcut(defaultSpec, for: .oneClickShortcut3)
        NotificationCenter.default.post(name: .generalShortcutsChanged, object: nil)
        oneClick3ShortcutMessage = InlineMessage(text: "Reset to default", isError: false)
    }

    // MARK: - Updates from Recorder
    func updateShow(from spec: ShortcutSpec?) {
        guard let spec = spec else {
            showShortcutDisplay = ""
            showShortcutMessage = InlineMessage(text: "Cleared", isError: false)
            return
        }

        // Validation: must include ⌘ and at least one of ⌃ ⌥ ⇧
        guard hasRequiredModifiers(spec) else {
            showShortcutMessage = InlineMessage(
                text: "Shortcut must include ⌘ and at least one of ⌃, ⌥, or ⇧.",
                isError: true
            )
            return
        }

        // Conflict: cannot duplicate any One‑Click AI shortcuts
        if isDuplicate(spec, with: oneClick1ShortcutSpec) {
            showShortcutMessage = InlineMessage(
                text: "Conflicts with One‑Click AI Action 1 shortcut.",
                isError: true
            )
            return
        }
        if isDuplicate(spec, with: oneClick2ShortcutSpec) {
            showShortcutMessage = InlineMessage(
                text: "Conflicts with One‑Click AI Action 2 shortcut.",
                isError: true
            )
            return
        }
        if isDuplicate(spec, with: oneClick3ShortcutSpec) {
            showShortcutMessage = InlineMessage(
                text: "Conflicts with One‑Click AI Action 3 shortcut.",
                isError: true
            )
            return
        }

        // Accept
        showShortcutSpec = spec
        showShortcutDisplay = spec.display
        // Persist
        SettingsStorage.saveShortcut(spec, for: .showShortcut)
        // Notify
        NotificationCenter.default.post(name: .generalShortcutsChanged, object: nil)
        if let warning = commonSystemShortcutWarning(for: spec) {
            showShortcutMessage = InlineMessage(text: warning, isError: false)
        } else {
            showShortcutMessage = InlineMessage(text: "Updated", isError: false)
        }
    }

    func updateOneClick1(from spec: ShortcutSpec?) {
        guard let spec = spec else {
            oneClick1ShortcutDisplay = ""
            oneClick1ShortcutMessage = InlineMessage(text: "Cleared", isError: false)
            return
        }

        guard hasRequiredModifiers(spec) else {
            oneClick1ShortcutMessage = InlineMessage(
                text: "Shortcut must include ⌘ and at least one of ⌃, ⌥, or ⇧.",
                isError: true
            )
            return
        }

        if let conflictMessage = getConflictMessage(for: spec, excluding: 1) {
            oneClick1ShortcutMessage = InlineMessage(text: conflictMessage, isError: true)
            return
        }

        oneClick1ShortcutSpec = spec
        oneClick1ShortcutDisplay = spec.display
        SettingsStorage.saveShortcut(spec, for: .oneClickShortcut1)
        NotificationCenter.default.post(name: .generalShortcutsChanged, object: nil)
        if let warning = commonSystemShortcutWarning(for: spec) {
            oneClick1ShortcutMessage = InlineMessage(text: warning, isError: false)
        } else {
            oneClick1ShortcutMessage = InlineMessage(text: "Updated", isError: false)
        }
    }
    
    func updateOneClick2(from spec: ShortcutSpec?) {
        guard let spec = spec else {
            oneClick2ShortcutDisplay = ""
            oneClick2ShortcutMessage = InlineMessage(text: "Cleared", isError: false)
            return
        }

        guard hasRequiredModifiers(spec) else {
            oneClick2ShortcutMessage = InlineMessage(
                text: "Shortcut must include ⌘ and at least one of ⌃, ⌥, or ⇧.",
                isError: true
            )
            return
        }

        if let conflictMessage = getConflictMessage(for: spec, excluding: 2) {
            oneClick2ShortcutMessage = InlineMessage(text: conflictMessage, isError: true)
            return
        }

        oneClick2ShortcutSpec = spec
        oneClick2ShortcutDisplay = spec.display
        SettingsStorage.saveShortcut(spec, for: .oneClickShortcut2)
        NotificationCenter.default.post(name: .generalShortcutsChanged, object: nil)
        if let warning = commonSystemShortcutWarning(for: spec) {
            oneClick2ShortcutMessage = InlineMessage(text: warning, isError: false)
        } else {
            oneClick2ShortcutMessage = InlineMessage(text: "Updated", isError: false)
        }
    }
    
    func updateOneClick3(from spec: ShortcutSpec?) {
        guard let spec = spec else {
            oneClick3ShortcutDisplay = ""
            oneClick3ShortcutMessage = InlineMessage(text: "Cleared", isError: false)
            return
        }

        guard hasRequiredModifiers(spec) else {
            oneClick3ShortcutMessage = InlineMessage(
                text: "Shortcut must include ⌘ and at least one of ⌃, ⌥, or ⇧.",
                isError: true
            )
            return
        }

        if let conflictMessage = getConflictMessage(for: spec, excluding: 3) {
            oneClick3ShortcutMessage = InlineMessage(text: conflictMessage, isError: true)
            return
        }

        oneClick3ShortcutSpec = spec
        oneClick3ShortcutDisplay = spec.display
        SettingsStorage.saveShortcut(spec, for: .oneClickShortcut3)
        NotificationCenter.default.post(name: .generalShortcutsChanged, object: nil)
        if let warning = commonSystemShortcutWarning(for: spec) {
            oneClick3ShortcutMessage = InlineMessage(text: warning, isError: false)
        } else {
            oneClick3ShortcutMessage = InlineMessage(text: "Updated", isError: false)
        }
    }

    // MARK: - Validation Helpers
    private func hasRequiredModifiers(_ spec: ShortcutSpec) -> Bool {
        let mods = spec.modifiers
        let hasCmd = (mods & Int(cmdKey)) == Int(cmdKey)
        let hasAtLeastOneOther =
            (mods & Int(controlKey)) == Int(controlKey) ||
            (mods & Int(optionKey)) == Int(optionKey) ||
            (mods & Int(shiftKey)) == Int(shiftKey)
        return hasCmd && hasAtLeastOneOther
    }

    private func isDuplicate(_ a: ShortcutSpec, with b: ShortcutSpec?) -> Bool {
        guard let b = b else { return false }
        return a.keyCode == b.keyCode && a.modifiers == b.modifiers
    }
    
    /// Get conflict message for a shortcut spec, excluding a specific action from conflict checking
    /// - Parameters:
    ///   - spec: The shortcut spec to check
    ///   - excluding: Action number to exclude (1, 2, or 3), or 0 for none
    /// - Returns: Conflict message if there's a conflict, nil otherwise
    private func getConflictMessage(for spec: ShortcutSpec, excluding: Int) -> String? {
        if isDuplicate(spec, with: showShortcutSpec) {
            return "Conflicts with Show App shortcut."
        }
        if excluding != 1 && isDuplicate(spec, with: oneClick1ShortcutSpec) {
            return "Conflicts with One‑Click AI Action 1 shortcut."
        }
        if excluding != 2 && isDuplicate(spec, with: oneClick2ShortcutSpec) {
            return "Conflicts with One‑Click AI Action 2 shortcut."
        }
        if excluding != 3 && isDuplicate(spec, with: oneClick3ShortcutSpec) {
            return "Conflicts with One‑Click AI Action 3 shortcut."
        }
        return nil
    }

    private func commonSystemShortcutWarning(for spec: ShortcutSpec) -> String? {
        // Warn (non-blocking) for known macOS screenshot shortcuts: ⌘⇧3/4/5
        let mods = spec.modifiers
        let isCmdShift = (mods & Int(cmdKey)) == Int(cmdKey) && (mods & Int(shiftKey)) == Int(shiftKey)
        if isCmdShift {
            if spec.keyCode == Int(kVK_ANSI_3) { return "Common macOS shortcut (Screenshot). It may not work reliably." }
            if spec.keyCode == Int(kVK_ANSI_4) { return "Common macOS shortcut (Screenshot). It may not work reliably." }
            if spec.keyCode == Int(kVK_ANSI_5) { return "Common macOS shortcut (Screenshot). It may not work reliably." }
        }
        return nil
    }
    
    // MARK: - Font Size Controls
    
    /// Increase preview font size
    func increasePreviewFontSize() {
        previewFontSize = min(GeneralSettingsViewModel.maxPreviewFontSize, previewFontSize + 1)
    }
    
    /// Decrease preview font size
    func decreasePreviewFontSize() {
        previewFontSize = max(GeneralSettingsViewModel.minPreviewFontSize, previewFontSize - 1)
    }
    
    /// Reset preview font size to default
    func resetPreviewFontSizeToDefault() {
        previewFontSize = GeneralSettingsViewModel.defaultPreviewFontSize
    }
    
    /// Check if font size can be increased
    var canIncreasePreviewFontSize: Bool {
        previewFontSize < GeneralSettingsViewModel.maxPreviewFontSize
    }
    
    /// Check if font size can be decreased
    var canDecreasePreviewFontSize: Bool {
        previewFontSize > GeneralSettingsViewModel.minPreviewFontSize
    }
    
    // MARK: - Theme Controls
    
    /// Reset preview theme to default
    func resetPreviewThemeToDefault() {
        previewTheme = GeneralSettingsViewModel.defaultPreviewTheme
    }
    
    /// Get display name for current theme
    var currentThemeDisplayName: String {
        GeneralSettingsViewModel.availableThemes.first { $0.1 == previewTheme }?.0 ?? "Unknown"
    }
}

