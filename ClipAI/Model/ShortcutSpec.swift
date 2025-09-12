import Foundation

/// Represents a global keyboard shortcut specification.
///
/// The `modifiers` property is a bitmask compatible with Carbon / HotKey modifier flags
/// and can be translated to `HotKey` registrations by higher-level services.
public struct ShortcutSpec: Codable, Equatable {
    /// Hardware key code (Carbon virtual key code)
    public let keyCode: Int

    /// Modifier bitmask (command, option, control, shift)
    public let modifiers: Int

    /// Human-friendly display string (e.g., "⌃⌘V")
    public let display: String

    public init(keyCode: Int, modifiers: Int, display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }
}

