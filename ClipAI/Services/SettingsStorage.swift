import Foundation

// Notification names for settings-related changes
extension Notification.Name {
    static let generalShortcutsChanged = Notification.Name("GeneralShortcutsChanged")
}

/// Keys for persisted general settings
enum GeneralSettingsKeys: String {
    case showShortcut = "general.showShortcut"
    case oneClickShortcut1 = "general.oneClickShortcut1"
    case oneClickShortcut2 = "general.oneClickShortcut2"
    case oneClickShortcut3 = "general.oneClickShortcut3"
    case chatImprovementShortcut = "general.chatImprovementShortcut"
    case previewFontSize = "general.previewFontSize"
    case previewTheme = "general.previewTheme"

    // Legacy key for migration
    case oneClickShortcut = "general.oneClickShortcut"
}

/// Simple wrapper around UserDefaults for storing and retrieving settings
/// related to general preferences like global shortcuts.
enum SettingsStorage {
    private static let defaults: UserDefaults = .standard

    // MARK: - Shortcut Persistence

    static func saveShortcut(_ shortcut: ShortcutSpec, for key: GeneralSettingsKeys) {
        do {
            let data = try JSONEncoder().encode(shortcut)
            defaults.set(data, forKey: key.rawValue)
        } catch {
            // If encoding fails, ensure we don't leave partial state
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    static func loadShortcut(for key: GeneralSettingsKeys) -> ShortcutSpec? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        do {
            return try JSONDecoder().decode(ShortcutSpec.self, from: data)
        } catch {
            return nil
        }
    }
    
    // MARK: - Font Size Persistence
    
    static func savePreviewFontSize(_ fontSize: CGFloat) {
        defaults.set(fontSize, forKey: GeneralSettingsKeys.previewFontSize.rawValue)
    }
    
    static func loadPreviewFontSize() -> CGFloat? {
        let value = defaults.object(forKey: GeneralSettingsKeys.previewFontSize.rawValue) as? CGFloat
        return value
    }
    
    // MARK: - Theme Persistence
    
    static func savePreviewTheme(_ theme: String) {
        defaults.set(theme, forKey: GeneralSettingsKeys.previewTheme.rawValue)
    }
    
    static func loadPreviewTheme() -> String? {
        return defaults.string(forKey: GeneralSettingsKeys.previewTheme.rawValue)
    }
}

