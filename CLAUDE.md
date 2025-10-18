# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClipAI is a macOS menu bar application that provides intelligent clipboard history management with AI processing capabilities. Built with SwiftUI and Swift Package Manager dependencies.

## Development Commands

### Building and Running
Don't run the project, i will manually run it myself

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
4. `ContentTypeDetector` classifies content (code, JSON, color, text)
5. `PreviewProviderRegistry` selects appropriate preview renderer
6. `LLMProvider` abstraction supports multiple AI services (OpenAI, Gemini)
7. `LLMRequestManager` orchestrates requests with retry logic and rate limiting
8. `OneClickAIProcessor` handles one-click AI processing workflows
9. `ChatImprovementController` manages multi-turn AI refinement sessions

### Key Components

**Application Entry Point:**
- `ClipAIApp.swift` - SwiftUI app with menu bar setup in `AppDelegate`

**Core Business Logic:**
- `ClipboardStore` - Centralized clipboard history management with delegate pattern
- `ClipItem` - Domain model for clipboard entries with UUIDv7, content, timestamps, metadata
- `ChatMessage` - Messages in multi-turn chat improvement conversations
- Storage backends: `SQLiteClipboardStorage`, `JSONClipboardStorage`, `InMemoryClipboardStorage`

**System Integration:**
- `PasteboardMonitor` - Monitors NSPasteboard changes with delegate callbacks
- `HotKeyListener` - Global hotkey registration (5 shortcuts: show, one-click-1/2/3, chat-improvement)
- `AppLogger` - Centralized logging with in-memory ring buffer and file persistence

**Window Controllers:**
- `PopupController` - Main clipboard history window with keyboard focus management
- `ChatImprovementController` - Separate window for iterative AI refinement
- `LLMSettingsWindowController` - Preferences window

**Content Detection & Preview:**
- `ContentTypeDetector` - Multi-rule detection system with confidence scoring
- `CodeDetector` - Language detection for 22+ programming languages
- `JSONDetector` - JSON validation and structure detection
- `ClipContentType` - Enum for content classification (text, code, JSON, color)
- `PreviewProviderRegistry` - Preview provider management
- Preview views: `TextPreviewView`, `CodePreviewView`, `JSONPreviewView`, `ColorPreviewView`

**AI Integration:**
- `LLMProvider` protocol - Abstraction for AI services
- `MacPawOpenAIProvider`, `GeminiProvider` - Concrete implementations
- `LLMProviderRegistry` - Provider management and default selection
- `LLMRequestManager` - Request orchestration with retry logic and rate limiting
- `OneClickAIProcessor` - Orchestrates one-click AI processing workflows
- `PromptStore` - SQLite-backed system prompt management with template substitution
- `KeychainService` - Secure API key storage

**UI Layer:**
- `PopupView` - Main floating window with search, list, and preview pane
- `ClipboardListView` - List of clipboard items with metadata
- `PreviewWindowView` - Resizable preview pane with content-type-specific rendering
- `ChatImprovementView` - Multi-turn chat interface

**ViewModels:**
- `PopupViewModel` - Popup state, search filtering, keyboard navigation
- `ChatImprovementViewModel` - Multi-turn chat state management
- `GeneralSettingsViewModel` - App-wide settings (shortcuts, font size, themes)
- `LLMSettingsViewModel` - Provider-specific configuration
- `LLMRequestViewModel` - AI request state tracking

**Settings Views:**
- `GeneralSettingsView` - Shortcuts, launch-at-login, font size, theme selection
- `AIConfigurationView` - Per-provider API key and model selection
- `SystemPromptEditorView` - Template editor for system prompts
- `LogsView` - Application log viewer with filtering

### Key Patterns

**Dependency Injection:**
- ClipboardStore can accept custom storage backends and monitor instances
- LLMProvider protocol allows swapping AI services
- Controllers receive dependencies via initializers
- Preview provider registry for extensible content rendering

**Delegate Pattern:**
- `ClipboardStoreDelegate` for store change notifications
- `PasteboardMonitorDelegate` for clipboard change detection
- NSWindow delegate patterns for custom window behavior

**Storage Abstraction:**
- `ClipboardStorageProtocol` with multiple implementations
- Automatic fallback chain: SQLite → JSON → InMemory
- `PromptStore` SQLite database: `~/Library/Application Support/ClipAI/promptsV13.sqlite`

**Settings Management:**
- `SettingsStorage` for persistence via UserDefaults
- `GeneralSettingsKeys` enum for type-safe key access
- Shortcut specifications with `ShortcutSpec` model
- Settings change notifications: `generalShortcutsChanged`

**Content Classification:**
- Multi-rule detection system with confidence scoring
- Priority-based content type selection
- Sophisticated code language detection (22+ languages)
- JSON structure validation

**Preview System:**
- Provider pattern for content-type-specific rendering
- `PreviewProviderRegistry` manages provider selection
- Resizable preview pane (250-800pt width)
- Theme-aware syntax highlighting for code

**Request Management:**
- Retry logic with exponential backoff (1s to 30s, max 3 attempts)
- Rate limiting per provider (60 req/min, 10 burst)
- In-flight request tracking with UUIDs
- AI activity notifications for status bar animation

### Package Dependencies

The project uses Swift Package Manager with these key dependencies:
- **OpenAI** (MacPaw/OpenAI) - OpenAI API client
- **SQLite** (stephencelis/SQLite.swift) - Database layer
- **HotKey** (soffes/HotKey) - Global hotkey registration
- **KeychainSwift** - Secure credential storage
- **HighlightSwift** - Code syntax highlighting
- **LaunchAtLogin** - Auto-launch functionality

## Project Structure

### Directory Layout
```
ClipAI/
├── ClipAI/                    # Main application source (61 Swift files)
│   ├── ClipAIApp.swift       # App entry point with AppDelegate
│   ├── ContentView.swift     # Root SwiftUI view (minimal)
│   ├── Assets.xcassets/      # Images and app icon
│   ├── ClipAI.entitlements   # App sandbox permissions
│   ├── Controllers/          # NSWindow lifecycle (3 files)
│   ├── Model/                # Domain models (7 files)
│   ├── Services/             # System services (10 files)
│   │   └── Providers/        # LLM implementations (2 files)
│   ├── ViewModels/           # UI state (5 files)
│   ├── Views/                # SwiftUI views
│   │   ├── Settings/         # Settings UI (7 files)
│   │   ├── Preview/          # Preview system (8 files)
│   │   │   └── Providers/    # Type-specific previews (4 files)
│   │   └── Custom/           # Custom controls
│   ├── Utils/                # Utilities (6 files)
│   ├── Prompts/              # System prompt templates
│   └── Resources/            # Additional resources
├── ClipAITests/              # Unit tests
├── ClipAIUITests/            # UI tests
├── assets/                   # Image assets
├── build/                    # Build artifacts
├── dist/                     # Distribution builds
├── scripts/                  # Build automation
├── docs/                     # Documentation
└── ClipAI.xcodeproj/         # Xcode project
```

### Data Storage Locations
- **Clipboard storage**: `~/Library/Application Support/ClipAI/clipboard.db` (SQLite)
- **Prompts database**: `~/Library/Application Support/ClipAI/promptsV13.sqlite`
- **Application logs**: `~/Library/Logs/ClipAI/ClipAI.log`
- **Settings**: UserDefaults (`com.clipai` bundle ID)
- **API keys**: Keychain (`com.clipai.llm.apikey.*`)

## Development Guidelines

### File Organization
- Follow existing MVVM structure in organized folders
- **Model/** - Domain models and data structures (7 files)
  - `ClipItem`, `ChatMessage`, `ClipContentType`, `SystemPrompt`, `ShortcutSpec`
  - `ClipboardStorage` - Storage protocol and implementations
  - `ClipItemPreviewProvider` - Preview provider registry
  - `LLMError` - Comprehensive error types
- **Services/** - System-level services (10 files)
  - Core: `ClipboardStore`, `PasteboardMonitor`, `HotKeyListener`
  - AI: `LLMProvider`, `LLMProviderRegistry`, `LLMRequestManager`, `OneClickAIProcessor`
  - Storage: `PromptStore`, `KeychainService`, `SettingsStorage`
  - Logging: `AppLogger`
  - **Services/Providers/** - Concrete LLM implementations
- **Controllers/** - NSWindow lifecycle management (3 files)
  - `PopupController`, `ChatImprovementController`, `LLMSettingsWindowController`
- **ViewModels/** - UI state management (5 files)
  - `PopupViewModel`, `ChatImprovementViewModel`, `GeneralSettingsViewModel`, `LLMSettingsViewModel`, `LLMRequestViewModel`
- **Views/** - SwiftUI views
  - Root: `PopupView`, `ClipboardListView`, `ClipItemRowView`, `SearchBarView`
  - **Views/Settings/** - Settings UI (7 files)
  - **Views/Preview/** - Preview system (8 files)
    - Container: `PreviewWindowView`, `PreviewContentView`, `PreviewHeaderView`, `ResizableDivider`
    - **Views/Preview/Providers/** - Type-specific preview views (4 files)
  - **Views/Custom/** - Custom controls
- **Utils/** - Utility functions (6 files)
  - `ContentTypeDetector`, `CodeDetector`, `JSONDetector`, `ContentDetectionRule`
  - `UUIDV7`, `PreviewConfig`

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
1. Implement `LLMProvider` protocol with methods:
   - `send(prompt:systemPrompt:model:)` - Async request handling
   - `isConfigured()` - Validate API key and configuration
   - `availableModels()` - Return model list
   - `id` and `displayName` properties
2. Register in `LLMProviderRegistry.setupProviders()`
3. Add API key storage in `KeychainService`
4. Add UI configuration in `AIConfigurationView`
5. Handle provider-specific errors in `LLMError`
6. Consider retry behavior in `LLMRequestManager`

### Content Detection Extension
To add new content types:
1. Add case to `ClipContentType` enum
2. Create detection rule in `ContentDetectionRule`
3. Implement detector class (e.g., `YourTypeDetector`)
4. Add to `ContentTypeDetector.detectContentType()` with confidence scoring
5. Create preview provider in `Views/Preview/Providers/`
6. Register in `PreviewProviderRegistry`

### Preview Provider Integration
To add new preview types:
1. Implement `ClipItemPreviewProvider` protocol
2. Create SwiftUI view for rendering in `Views/Preview/Providers/`
3. Register in `PreviewProviderRegistry.setupProviders()`
4. Handle content type selection in `PreviewContentView`

### Settings and Configuration
- New settings should use `SettingsStorage` utility
- Add keys to `GeneralSettingsKeys` enum
- Settings UI lives in `Views/Settings/`
- Consider both general and provider-specific settings
- Post `generalShortcutsChanged` notification for shortcut updates
- Theme selection: GitHub Light/Dark, VS Light/Dark, Xcode, Atom One Dark

### Menu Bar and Popup Management
- Status item configuration in `AppDelegate.applicationDidFinishLaunching`
- Popup showing/hiding managed by `PopupController`
- Window positioning and focus management handled automatically
- Outside click detection for popup dismissal
- Keyboard navigation in `PopupViewModel`:
  - ↑↓ arrows for list navigation
  - Enter to copy selected item
  - Escape to close popup
  - Tab to toggle preview pane
- Custom `PopupWindow` (NSWindow subclass) can become key for input
- Preview pane resize via `ResizableDivider` with mouse tracking

### Window Controllers
- `PopupController` - Main clipboard history window
  - Integrates `NSHostingView<PopupView>` for SwiftUI
  - Manages window visibility and keyboard focus
  - Disables chat improvement keyboard monitoring when active
- `ChatImprovementController` - Multi-turn chat window
  - Separate `ChatImprovementWindow` instance
  - Coordinates with `HotKeyListener` for keyboard shortcuts
  - Disables popup keyboard monitoring while active
- `LLMSettingsWindowController` - Preferences window
  - Standard NSWindow with title bar, resizable
  - Frame persistence across launches

### Logging and Debugging
- Use `AppLogger` for all logging with appropriate levels
- Categories: general, clipboard, AI, storage, UI
- Thread ID automatically captured
- Access logs via Settings → Logs
- Log file rotation handled automatically
- In-memory buffer for quick access to recent logs

## Important Implementation Details

### Clipboard History
- Maximum 100 items with automatic trimming
- Duplicate detection prevents same content multiple entries
- UUIDv7 for sortable, chronologically ordered unique IDs
- Persistence across app launches via storage backends
- Real-time monitoring with immediate UI updates (0.5s polling interval)
- Source app metadata capture (name, bundle ID, path, icon)

### Content Detection
- Four primary content types: `plainText`, `code`, `json`, `color`
- Multi-rule detection with confidence scoring
- `CodeDetector` supports 22+ programming languages:
  - Swift, JavaScript, Python, Java, C/C++, Go, Rust, TypeScript, etc.
  - Language-specific keyword detection
  - File extension pattern matching
  - Syntax pattern recognition
- `JSONDetector` validates structure and schema
- Priority-based content type selection for ambiguous content

### Preview System
- Provider pattern for extensible content rendering
- Type-specific preview views:
  - **Text**: Plain text with word wrap
  - **Code**: Syntax highlighting with HighlightSwift, 6 theme options
  - **JSON**: Formatted with indentation, collapsible structure
  - **Color**: Visual swatch with format conversion display
- Resizable preview pane (250-800pt width)
- `PreviewWindowView` with material background
- `ResizableDivider` for draggable pane resizing

### AI Processing

**One-Click Actions:**
- Three configurable one-click actions with separate shortcuts
- Per-action prompt configuration
- Per-provider model selection
- Template-based system prompts with `{content}` substitution
- Last result storage for chat improvement workflow
- Automatic result copy to clipboard

**Chat Improvement:**
- Separate floating window for multi-turn conversations
- `ChatMessage` model with user/AI distinction
- Iterative AI refinement workflow
- Session-based chat history
- Distinct keyboard shortcut from one-click actions

**Request Management:**
- `LLMRequestManager` orchestrates all AI requests
- Retry logic: max 3 attempts, exponential backoff (1-30s)
- Rate limiting: 60 req/min with 10 burst capacity
- In-flight request tracking
- Provider-agnostic error handling
- Automatic provider configuration validation

### Logging System
- `AppLogger` centralized logging infrastructure
- In-memory ring buffer (max 2000 entries)
- File persistence: `~/Library/Logs/ClipAI/ClipAI.log`
- Log levels: debug, info, warning, error
- Thread ID tracking for debugging
- Observable for UI integration in `LogsView`
- Category-based organization

### Status Bar Integration
- Menu bar application with NSStatusItem
- Dynamic icon animation during AI processing
- CABasicAnimation rotation for processing indicator
- Activity counter for concurrent AI requests
- Notifications: `aiActivityDidStart`, `aiActivityDidFinish`

### Security Considerations
- Sensitive credentials stored in keychain via `KeychainSwift`
- Service prefix: `com.clipai.llm.apikey`
- No credentials in UserDefaults or logs
- Accessibility permission handling for paste operations
- Secure provider API key management
- API key validation on settings save

### Platform Integration
- Menu bar application (NSStatusItem)
- Global hotkey support with conflict detection (5 configurable shortcuts)
- Legacy shortcut migration for backward compatibility
- Custom NSWindow subclasses for proper window behavior:
  - `PopupWindow` - Can become key for keyboard input
  - `ChatImprovementWindow` - Separate floating window
- Window positioning and focus management
- Outside click detection for popup dismissal
- macOS-specific features:
  - Launch at login via `LaunchAtLogin` package
  - Accessibility permissions
  - App bundle metadata extraction