# Repository Guidelines

## Project Structure & Module Organization
- `ClipAI/` contains the macOS app source, organized by MVVM layers: `Controllers/`, `Model/`, `Services/`, `ViewModels/`, `Views/`, and `Utils/`.
- `ClipAI/Assets.xcassets` and `ClipAI/Prompts/` hold UI assets and built-in prompt templates.
- `ClipAITests/` and `ClipAIUITests/` are XCTest targets for unit and UI coverage.
- `assets/` stores README/demo media; `scripts/` contains release tooling; `dist/` and `build/` are build artifacts.

## Build, Test, and Development Commands
- `xcodebuild -scheme ClipAI -configuration Release` builds the app from the command line.
- `xcodebuild test -scheme ClipAI -destination 'platform=macOS'` runs unit and UI tests.
- `scripts/create_dmg.sh` builds a release DMG; add `--notarize` to sign/notarize (requires Apple credentials).

## Coding Style & Naming Conventions
- Use Xcode’s default Swift formatting (2-space indentation) and keep SwiftUI views readable and declarative.
- Prefer `@MainActor` for UI-facing classes and async/await for I/O.
- Follow existing naming: `*View`, `*ViewModel`, `*Controller`, and `*Service` suffixes.

## Testing Guidelines
- Unit tests live in `ClipAITests/` and should target model/store logic (e.g., `ClipboardStore`).
- UI tests live in `ClipAIUITests/` and cover core workflows.
- Name tests with clear intent (e.g., `testClipboardStoreDeduplicatesItems`).

## Commit & Pull Request Guidelines
- Commit messages are short, imperative, sentence case (e.g., "Add JIRA prompt template"). Avoid prefixes.
- PRs should include a concise summary, testing notes, and screenshots/GIFs for UI changes.

## Security & Configuration Tips
- API keys are stored in Keychain; do not log or persist secrets in UserDefaults.
- Local data lives in `~/Library/Application Support/ClipAI/` (clipboard DB, prompts DB) and logs in `~/Library/Logs/ClipAI/`.

## Agent-Specific Instructions
- Do not run the app; repository owner runs it manually.
