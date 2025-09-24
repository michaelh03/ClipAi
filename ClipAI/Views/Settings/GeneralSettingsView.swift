import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                shortcutsSection
                Divider()
                previewSection
                Divider()
                startupSection
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcuts")
                .font(.headline)

            // Show App
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Show App")
                    Spacer()
                    Button("Reset to default") { viewModel.resetShowToDefault() }
                        .buttonStyle(.borderless)
                }

                recorderRow(initialDisplay: viewModel.showShortcutDisplay, message: viewModel.showShortcutMessage) { spec in
                    viewModel.updateShow(from: spec)
                }
            }

            // One-Click AI Action 1
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("One-Click AI Action 1")
                    Spacer()
                    Button("Reset to default") { viewModel.resetOneClick1ToDefault() }
                        .buttonStyle(.borderless)
                }

                recorderRow(initialDisplay: viewModel.oneClick1ShortcutDisplay, message: viewModel.oneClick1ShortcutMessage) { spec in
                    viewModel.updateOneClick1(from: spec)
                }
            }
            
            // One-Click AI Action 2
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("One-Click AI Action 2")
                    Spacer()
                    Button("Reset to default") { viewModel.resetOneClick2ToDefault() }
                        .buttonStyle(.borderless)
                }

                recorderRow(initialDisplay: viewModel.oneClick2ShortcutDisplay, message: viewModel.oneClick2ShortcutMessage) { spec in
                    viewModel.updateOneClick2(from: spec)
                }
            }
            
            // One-Click AI Action 3
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("One-Click AI Action 3")
                    Spacer()
                    Button("Reset to default") { viewModel.resetOneClick3ToDefault() }
                        .buttonStyle(.borderless)
                }

                recorderRow(initialDisplay: viewModel.oneClick3ShortcutDisplay, message: viewModel.oneClick3ShortcutMessage) { spec in
                    viewModel.updateOneClick3(from: spec)
                }
            }

            // Chat Improvement
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Edit AI Response")
                    Spacer()
                    Button("Reset to default") { viewModel.resetChatImprovementToDefault() }
                        .buttonStyle(.borderless)
                }

                recorderRow(initialDisplay: viewModel.chatImprovementShortcutDisplay, message: viewModel.chatImprovementShortcutMessage) { spec in
                    viewModel.updateChatImprovement(from: spec)
                }

                Text("Opens a chat window to refine your most recent AI response.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Must include ⌘ and at least one additional modifier.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func recorderRow(initialDisplay: String, message: GeneralSettingsViewModel.InlineMessage?, onChange: @escaping (ShortcutSpec?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                ShortcutRecorderView(initialDisplay: initialDisplay) { spec in
                    onChange(spec)
                }
            }

            if let message = message {
                HStack(spacing: 6) {
                    Image(systemName: message.isError ? "exclamationmark.triangle" : "info.circle")
                        .foregroundColor(message.isError ? .red : .secondary)
                    Text(message.text)
                        .font(.caption)
                        .foregroundColor(message.isError ? .red : .secondary)
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
            
            HStack {
                Text("Font Size")
                Spacer()
                HStack(spacing: 8) {
                    Button(action: { viewModel.decreasePreviewFontSize() }) {
                        Image(systemName: "textformat.size.smaller")
                    }
                    .disabled(!viewModel.canDecreasePreviewFontSize)
                    
                    Text("\(Int(viewModel.previewFontSize))pt")
                        .font(.body)
                        .frame(width: 35)
                    
                    Button(action: { viewModel.increasePreviewFontSize() }) {
                        Image(systemName: "textformat.size.larger")
                    }
                    .disabled(!viewModel.canIncreasePreviewFontSize)
                    
                    Button("Reset") { viewModel.resetPreviewFontSizeToDefault() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
            
            HStack {
                Text("Theme")
                Spacer()
                HStack(spacing: 8) {
                    Menu {
                        ForEach(GeneralSettingsViewModel.availableThemes, id: \.1) { theme in
                            Button(theme.0) {
                                viewModel.previewTheme = theme.1
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.currentThemeDisplayName)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                  
                  
                  
                    
                    Button("Reset") { viewModel.resetPreviewThemeToDefault() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
            
            Text("Font size and theme apply to all preview types (code, text, etc.)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Startup")
                .font(.headline)
            Toggle("Start ClipAI at login", isOn: $viewModel.isStartAtLoginEnabled)
            Text("Changes apply immediately.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}


#Preview {
    GeneralSettingsView(viewModel: GeneralSettingsViewModel())
        .frame(width: 500, height: 600)
}

