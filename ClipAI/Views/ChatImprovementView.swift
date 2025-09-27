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
            chatContentView

            // Input area
            inputView
        }
        .frame(width: 500, height: 600)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Focus input field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFieldFocused = true
                scrollToBottom()
            }
        }
        .onChange(of: viewModel.chatHistory.count) { _, _ in
            // Scroll to bottom when new messages are added
            scrollToBottom()
        }
        .onChange(of: viewModel.isProcessing) { _, isProcessing in
            // Scroll to bottom when processing state changes
            if isProcessing {
                scrollToBottom()
            }
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
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Chat Content View

    private var chatContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
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

                    // Loading indicator at bottom of chat
                    if viewModel.isProcessing {
                        loadingIndicatorView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.9)),
                                removal: .opacity
                            ))
                    }

                    // Invisible spacer for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.3), value: viewModel.chatHistory.count)
                .animation(.easeInOut(duration: 0.4), value: viewModel.isProcessing)
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
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
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // Message bubble with improved styling
                VStack(alignment: .leading, spacing: 0) {
                    Text(message.content)
                        .font(.body)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(
                    Group {
                        if message.isUser {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accentColor)
                                .shadow(
                                    color: Color.black.opacity(0.15),
                                    radius: 4,
                                    x: 0,
                                    y: 2
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(
                                    color: Color.black.opacity(0.08),
                                    radius: 2,
                                    x: 0,
                                    y: 1
                                )
                        }
                    }
                )
                .foregroundColor(message.isUser ? .white : .primary)
                .textSelection(.enabled)

                // Timestamp and actions row
                HStack(spacing: 8) {
                    if message.isUser {
                        Spacer()
                    }

                    Text(message.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if !message.isUser && message.id == viewModel.chatHistory.last(where: { !$0.isUser })?.id {
                        Button(action: {
                            viewModel.copyLatestResponse()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.caption2)
                                Text("Copy")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                        }
                        .keyboardShortcut("c", modifiers: [.command])
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: false)
                    }

                    if !message.isUser {
                        Spacer()
                    }
                }
                .padding(.horizontal, 4)
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95).combined(with: .move(edge: .bottom))),
            removal: .opacity.combined(with: .scale(scale: 0.9))
        ))
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Loading Indicator View

    private var loadingIndicatorView: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer(minLength: 60)

            VStack(alignment: .leading, spacing: 6) {
                // Loading bubble with typing animation
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))

                    Text(viewModel.progressMessage.isEmpty ? "Thinking..." : viewModel.progressMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.5), value: viewModel.progressMessage)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(0.08),
                            radius: 2,
                            x: 0,
                            y: 1
                        )
                )

                // Timestamp placeholder
                HStack {
                    Text("Now")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 60)
        }
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

            VStack(spacing: 8) {
                // Input field with send button
                HStack(spacing: 8) {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helper Methods

    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.4)) {
              scrollViewProxy?.scrollTo("bottom", anchor: UnitPoint.bottom)
            }
        }
    }
}
