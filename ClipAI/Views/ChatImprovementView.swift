import SwiftUI

/// SwiftUI view for the chat improvement window
struct ChatImprovementView: View {
    @StateObject private var viewModel: ChatImprovementViewModel
    @FocusState private var isInputFieldFocused: Bool
    @State private var scrollViewProxy: ScrollViewProxy?

    // MARK: - Initialization

    init(viewModel: ChatImprovementViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Main content area
            if viewModel.isProcessing {
                processingView
            } else {
                chatContentView
            }

            // Input area
            inputView
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            // Focus input field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFieldFocused = true
                scrollToBottom()
            }
        }
        .onChange(of: viewModel.chatHistory.count) {
            // Scroll to bottom when new messages are added
            scrollToBottom()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "message.bubble.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Improve AI Response")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    viewModel.requestClose()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.cancelAction)
            }

            Divider()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Chat Content View

    private var chatContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Show original content context
                    originalContentView

                    // Chat messages
                    ForEach(viewModel.chatHistory) { message in
                        chatMessageView(message)
                            .id(message.id)
                    }

                    // Error message if present
                    if viewModel.hasError, let errorMessage = viewModel.errorMessage {
                        errorMessageView(errorMessage)
                    }

                    // Invisible spacer for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .onAppear {
                scrollViewProxy = proxy
            }
        }
    }

    // MARK: - Original Content View

    private var originalContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                Text("Original Content")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text(viewModel.originalContent)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Chat Message View

    private func chatMessageView(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Message bubble
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isUser ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .textSelection(.enabled)

                // Timestamp and actions
                HStack {
                    Text(message.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if !message.isUser && message.id == viewModel.chatHistory.last(where: { !$0.isUser })?.id {
                        Button(action: {
                            viewModel.copyLatestResponse()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.caption2)
                                Text("Copy")
                                    .font(.caption2)
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 8)
                    }

                    Spacer()
                }
                .padding(.horizontal, message.isUser ? 16 : 4)
            }

            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Error Message View

    private func errorMessageView(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text(error)
                .font(.body)
                .foregroundColor(.red)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)

                Text(viewModel.progressMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 12) {
                // Input field with send button
                HStack(spacing: 12) {
                    TextField("How would you like to improve this response?", text: $viewModel.currentInput, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFieldFocused)
                        .disabled(viewModel.isProcessing)
                        .lineLimit(3)
                        .onSubmit {
                            if !viewModel.currentInput.isEmpty && !viewModel.isProcessing {
                                Task {
                                    await viewModel.sendImprovementRequest()
                                }
                            }
                        }

                    Button(action: {
                        Task {
                            await viewModel.sendImprovementRequest()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.currentInput.isEmpty || viewModel.isProcessing)
                    .keyboardShortcut(.return, modifiers: [.command])
                }

                // Keyboard shortcuts hint
                HStack {
                    Text("⌘↩ to send • ⌘C to copy latest response • Esc to close")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Reset Chat") {
                        viewModel.resetChat()
                        scrollToBottom()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Helper Methods

    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
              scrollViewProxy?.scrollTo("bottom", anchor: UnitPoint.bottom)
            }
        }
    }
}
