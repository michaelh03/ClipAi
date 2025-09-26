import SwiftUI
import AppKit

/// Custom NSWindow for the chat improvement window
class ChatImprovementWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return false
    }
}

/// NSWindowController that manages the chat improvement window
class ChatImprovementController: NSWindowController {
    private var hostingView: NSHostingView<ChatImprovementView>?
    private var chatViewModel: ChatImprovementViewModel?
    private var outsideClickMonitor: Any?
    private weak var popupController: PopupController?

    /// Initialize the chat improvement controller
    init(popupController: PopupController? = nil) {
        self.popupController = popupController
        // Create the window with proper styling
        let window = ChatImprovementWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        setupWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        guard let window = window else { return }

        // Window appearance and behavior
        window.isOpaque = false
        window.hasShadow = false // We'll use SwiftUI shadow instead
        window.backgroundColor = NSColor.clear
        window.level = .floating
        window.collectionBehavior = [.transient, .ignoresCycle, .moveToActiveSpace, .fullScreenAuxiliary]

        // Allow window to become key for keyboard input
        window.canHide = false

        // Disable window move
        window.isMovable = false

        // Close window when it loses focus
        window.hidesOnDeactivate = true

        // Set up window delegate for additional behavior
        window.delegate = self
    }

    /// Show the chat improvement window with the provided content
    /// - Parameters:
    ///   - originalContent: The original clipboard content
    ///   - originalResponse: The AI's initial response to improve
    func showChatImprovement(originalContent: String, originalResponse: String) {
        guard let window = window else { return }

        AppLog("ChatImprovementController: Showing chat improvement window", level: .info, category: "ChatImprovement")

        // Disable popup keyboard monitoring while chat window is active
        popupController?.popupViewModel?.disableKeyboardMonitoring()

        // Create or configure the view model
        let viewModel = ChatImprovementViewModel()
        viewModel.configure(originalContent: originalContent, originalResponse: originalResponse)

        // Set up callbacks
        viewModel.closeRequestedHandler = { [weak self] in
            self?.hideChatWindow()
        }

        viewModel.copyResponseHandler = { [weak self] response in
            AppLog("ChatImprovementController: Response copied to clipboard: \(response.prefix(50))...", level: .info, category: "ChatImprovement")
            // The response is already copied to clipboard in the view model
            // We could add additional actions here if needed
        }

        self.chatViewModel = viewModel

        // Create the SwiftUI view
        let chatView = ChatImprovementView(viewModel: viewModel)
        hostingView = NSHostingView(rootView: chatView)

        // Set the hosting view as the window's content view
        window.contentView = hostingView

        // Calculate window position (center of main screen)
        let windowSize = window.frame.size
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero

        let centerOrigin = NSPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )

        // Set window position and show
        window.setFrameOrigin(centerOrigin)

        // Ensure the window is visible in the current Space before activation
        window.orderFrontRegardless()

        // Activate the app to allow keyboard input without causing a Space switch
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])

        // Make the window key
        window.makeKeyAndOrderFront(nil)

        // Start monitoring for clicks outside the window after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.startMonitoringForOutsideClicks()
        }
    }

    /// Hide the chat improvement window
    func hideChatWindow() {
        AppLog("ChatImprovementController: Hiding chat improvement window", level: .info, category: "ChatImprovement")

        // Re-enable popup keyboard monitoring when chat window closes
        popupController?.popupViewModel?.enableKeyboardMonitoring()

        stopMonitoringForOutsideClicks()
        window?.orderOut(nil)

        // Clear the view model
        chatViewModel = nil
        hostingView = nil
    }

    /// Toggle chat window visibility
    func toggleChatWindow() {
        if window?.isVisible == true {
            hideChatWindow()
        } else {
            // Cannot show without content - this should be called from the hotkey handler
            // which will check for available content first
            AppLog("ChatImprovementController: Cannot toggle - no content provided", level: .warning, category: "ChatImprovement")
        }
    }

    // MARK: - Outside Click Monitoring

    private func startMonitoringForOutsideClicks() {
        stopMonitoringForOutsideClicks() // Ensure we don't have multiple monitors

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event)
        }
    }

    private func stopMonitoringForOutsideClicks() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    private func handleOutsideClick(_ event: NSEvent) {
        guard let window = window, window.isVisible else { return }

        // Check if the click was inside our window
        let mouseLocation = NSEvent.mouseLocation
        let windowLocation = window.convertPoint(fromScreen: mouseLocation)
        let windowFrame = NSRect(origin: .zero, size: window.frame.size)

        AppLog("ChatImprovement outside click detected - Mouse: \(mouseLocation), Window: \(windowLocation), Frame: \(windowFrame)", level: .debug, category: "ChatImprovement")

        if !windowFrame.contains(windowLocation) {
            AppLog("Click was outside chat window, hiding window", level: .info, category: "ChatImprovement")
            hideChatWindow()
        }
    }

    deinit {
        stopMonitoringForOutsideClicks()
    }
}

// MARK: - NSWindowDelegate

extension ChatImprovementController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        // Add a small delay to avoid hiding window when components are gaining focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let window = self.window else { return }

            // Only hide if the window is still not key and visible
            if !window.isKeyWindow && window.isVisible {
                self.hideChatWindow()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        stopMonitoringForOutsideClicks()
    }
}
