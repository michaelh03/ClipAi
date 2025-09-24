# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClipAI is a macOS menu bar application that provides intelligent clipboard history management with AI processing capabilities. Built with SwiftUI and Swift Package Manager dependencies.

## Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -project ClipAI.xcodeproj -scheme ClipAI build

# Run tests
xcodebuild -project ClipAI.xcodeproj -scheme ClipAI test

# Clean build
xcodebuild -project ClipAI.xcodeproj -scheme ClipAI clean
```

### Available Targets
- `ClipAI` - Main application target
- `ClipAITests` - Unit tests
- `ClipAIUITests` - UI tests

## Architecture Overview

### High-Level Structure
The app follows MVVM pattern with these key layers:

**Core Data Flow:**
1. `PasteboardMonitor` detects clipboard changes
2. `ClipboardStore` manages clipboard history (SQLite/JSON/in-memory storage backends)
3. `PopupController` manages the floating window UI
4. `LLMProvider` abstraction supports multiple AI services (OpenAI, Gemini)
5. `OneClickAIProcessor` handles AI processing workflows

### Key Components

**Application Entry Point:**
- `ClipAIApp.swift` - SwiftUI app with menu bar setup in `AppDelegate`

**Core Business Logic:**
- `ClipboardStore` - Centralized clipboard history management with delegate pattern
- `ClipItem` - Domain model for clipboard entries with UUID, content, timestamps, metadata
- Storage backends: `SQLiteClipboardStorage`, `JSONClipboardStorage`, `InMemoryClipboardStorage`

**System Integration:**
- `PasteboardMonitor` - Monitors NSPasteboard changes with delegate callbacks
- `HotKeyListener` - Global hotkey registration for show/one-click shortcuts
- `PopupController` - NSWindow management for floating popup UI

**AI Integration:**
- `LLMProvider` protocol - Abstraction for AI services
- `MacPawOpenAIProvider`, `GeminiProvider` - Concrete implementations
- `LLMProviderRegistry` - Provider management and default selection
- `OneClickAIProcessor` - Orchestrates AI processing workflows
- `PromptStore` - System prompt management with template substitution

**UI Layer:**
- `PopupView` - Main floating window with search and list
- `PopupViewModel` - State management for popup interactions
- `GeneralSettingsViewModel` - App-wide settings management
- Settings views in `Views/Settings/`

### Key Patterns

**Dependency Injection:**
- ClipboardStore can accept custom storage backends and monitor instances
- LLMProvider protocol allows swapping AI services
- Controllers receive dependencies via initializers

**Delegate Pattern:**
- `ClipboardStoreDelegate` for store change notifications
- `PasteboardMonitorDelegate` for clipboard change detection

**Storage Abstraction:**
- `ClipboardStorageProtocol` with multiple implementations
- Automatic fallback: SQLite → JSON → InMemory

**Settings Management:**
- `SettingsStorage` for persistence via UserDefaults
- `GeneralSettingsKeys` enum for type-safe key access
- Shortcut specifications with `ShortcutSpec` model

### Package Dependencies

The project uses Swift Package Manager with these key dependencies:
- **OpenAI** (MacPaw/OpenAI) - OpenAI API client
- **SQLite** (stephencelis/SQLite.swift) - Database layer
- **HotKey** (soffes/HotKey) - Global hotkey registration
- **KeychainSwift** - Secure credential storage
- **HighlightSwift** - Code syntax highlighting
- **LaunchAtLogin** - Auto-launch functionality

## Development Guidelines

### File Organization
- Follow existing MVVM structure in organized folders
- Place new models in `Model/`
- Services that interact with system APIs go in `Services/`
- UI-related view models in `ViewModels/`
- SwiftUI views in `Views/` with appropriate subfolders

### Code Style
- Use `@MainActor` for UI-related classes
- Async/await for network and storage operations
- Comprehensive error handling with custom `LLMError` types
- Extensive logging via `AppLogger` with categorization

### Testing
- Unit tests should cover core business logic (ClipboardStore, storage layers)
- UI tests for critical user workflows
- Mock implementations for external dependencies (storage, monitors)

### AI Provider Integration
To add new LLM providers:
1. Implement `LLMProvider` protocol
2. Register in `LLMProviderRegistry.setupProviders()`
3. Add UI configuration in settings views
4. Handle provider-specific errors in `LLMError`

### Settings and Configuration
- New settings should use `SettingsStorage` utility
- Add keys to `GeneralSettingsKeys` enum
- Settings UI lives in `Views/Settings/`
- Consider both general and provider-specific settings

### Menu Bar and Popup Management
- Status item configuration in `AppDelegate.applicationDidFinishLaunching`
- Popup showing/hiding managed by `PopupController`
- Window positioning and focus management handled automatically
- Outside click detection for popup dismissal

## Important Implementation Details

### Clipboard History
- Maximum 100 items with automatic trimming
- Duplicate detection prevents same content multiple entries
- Persistence across app launches via storage backends
- Real-time monitoring with immediate UI updates

### AI Processing
- Three configurable one-click actions with separate shortcuts
- Template-based system prompts with `{content}` substitution
- Provider-agnostic request handling via abstraction layer
- Automatic provider configuration validation

### Security Considerations
- Sensitive credentials stored in keychain via `KeychainSwift`
- No credentials in UserDefaults or logs
- Accessibility permission handling for paste operations
- Secure provider API key management

### Platform Integration
- Menu bar application (NSStatusItem)
- Global hotkey support with conflict detection
- Proper window management for popup behavior
- macOS-specific features (accessibility, launch at login)