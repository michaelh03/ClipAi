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
                Text("Show App")

                recorderRow(initialDisplay: viewModel.showShortcutDisplay, message: viewModel.showShortcutMessage, onChange: { spec in
                    viewModel.updateShow(from: spec)
                }, onResetToDefault: {
                    viewModel.clearShowShortcut()
                })
            }

            // One-Click AI Action 1
            VStack(alignment: .leading, spacing: 8) {
                Text("One-Click AI Action 1")

                recorderRow(initialDisplay: viewModel.oneClick1ShortcutDisplay, message: viewModel.oneClick1ShortcutMessage, onChange: { spec in
                    viewModel.updateOneClick1(from: spec)
                }, onResetToDefault: {
                    viewModel.clearOneClick1Shortcut()
                })
            }
            
            // One-Click AI Action 2
            VStack(alignment: .leading, spacing: 8) {
                Text("One-Click AI Action 2")

                recorderRow(initialDisplay: viewModel.oneClick2ShortcutDisplay, message: viewModel.oneClick2ShortcutMessage, onChange: { spec in
                    viewModel.updateOneClick2(from: spec)
                }, onResetToDefault: {
                    viewModel.clearOneClick2Shortcut()
                })
            }
            
            // One-Click AI Action 3
            VStack(alignment: .leading, spacing: 8) {
                Text("One-Click AI Action 3")

                recorderRow(initialDisplay: viewModel.oneClick3ShortcutDisplay, message: viewModel.oneClick3ShortcutMessage, onChange: { spec in
                    viewModel.updateOneClick3(from: spec)
                }, onResetToDefault: {
                    viewModel.clearOneClick3Shortcut()
                })
            }

            // Chat Improvement
            VStack(alignment: .leading, spacing: 8) {
                Text("Edit AI Response")

                recorderRow(initialDisplay: viewModel.chatImprovementShortcutDisplay, message: viewModel.chatImprovementShortcutMessage, onChange: { spec in
                    viewModel.updateChatImprovement(from: spec)
                }, onResetToDefault: {
                    viewModel.clearChatImprovementShortcut()
                })

                Text("Opens a chat window to refine your most recent AI response.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Must include ⌘ and at least one additional modifier.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func recorderRow(initialDisplay: String, message: GeneralSettingsViewModel.InlineMessage?, onChange: @escaping (ShortcutSpec?) -> Void, onResetToDefault: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                ShortcutRecorderView(initialDisplay: initialDisplay, onChange: { spec in
                    onChange(spec)
                }, onResetToDefault: onResetToDefault)
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

