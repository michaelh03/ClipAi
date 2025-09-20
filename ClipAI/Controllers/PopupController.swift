import SwiftUI
import AppKit
import ApplicationServices

/// Custom NSWindow that can become key window
class PopupWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

/// NSWindowController that manages the popup window for displaying clipboard history
class PopupController: NSWindowController {
  private let clipboardStore: ClipboardStore
  private let generalSettingsViewModel: GeneralSettingsViewModel
  private var hostingView: NSHostingView<PopupView>?
  private var popupViewModel: PopupViewModel?
  private var previouslyFrontmostApp: NSRunningApplication?

  /// Initialize the popup controller with a clipboard store and general settings
  /// - Parameters:
  ///   - clipboardStore: The ClipboardStore to display items from
  ///   - generalSettingsViewModel: The GeneralSettingsViewModel for shared settings
  init(clipboardStore: ClipboardStore, generalSettingsViewModel: GeneralSettingsViewModel) {
    self.clipboardStore = clipboardStore
    self.generalSettingsViewModel = generalSettingsViewModel

    // Create the window with proper styling
    let window = PopupWindow(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    super.init(window: window)

    setupWindow()
    setupContent()
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

  private func setupContent() {
    guard let window = window else { return }

    // Create the shared view model so the controller can interact with it directly
    let viewModel = PopupViewModel(clipboardStore: clipboardStore, generalSettingsViewModel: generalSettingsViewModel)
    self.popupViewModel = viewModel
    self.popupViewModel?.itemSelectedHandler = {
      self.hidePopup()
    }
    self.popupViewModel?.closeRequestedHandler = {
      self.hidePopup()
    }
    self.popupViewModel?.pasteRequestedHandler = { [weak self] in
      guard let self = self else { return }
      // Capture the previous app before hiding popup
      let previousApp = self.previouslyFrontmostApp
      
      // Hide popup without restoring focus (we'll handle focus ourselves)
      self.hidePastePopup()
      
      // Delay to allow popup to fully hide
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        if let app = previousApp {
          // Use proper activation options to ensure focus
          _ = app.activate(options: [.activateIgnoringOtherApps])
          
          // Additional delay to ensure the app is ready to receive input
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Self.sendPasteKeystroke()
            // Clear the reference after paste operation is complete
            self.previouslyFrontmostApp = nil
          }
        } else {
          AppLog("PopupController: No previous app to restore focus to", level: .warning, category: "Popup")
          // Still try to send the keystroke to current frontmost app
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.sendPasteKeystroke()
          }
        }
      }
    }
    
    
    
    

    // Create the SwiftUI view with the injected view model and fade out callback
    let popupView = PopupView(viewModel: viewModel) { [weak self] in
      // Hide the popup when fade out animation completes
      self?.hidePopup()
    }
    hostingView = NSHostingView(rootView: popupView)

    // Set the hosting view as the window's content view
    window.contentView = hostingView

  }

  /// Check if accessibility permissions are granted
  private static func hasAccessibilityPermissions() -> Bool {
    // AXIsProcessTrusted returns true if accessibility is enabled for this app
    return AXIsProcessTrusted()
  }
  
  /// Programmatically sends Cmd+V to paste in the focused application
  private static func sendPasteKeystroke() {
    AppLog("PopupController: Attempting to send paste keystroke", level: .info, category: "Popup")
    
    // Check if we have accessibility permissions first
    if hasAccessibilityPermissions() {
      AppLog("PopupController: Using CGEvent method (accessibility enabled)", level: .debug, category: "Popup")
      sendPasteKeystrokeViaCGEvent()
    } else {
      AppLog("PopupController: Using AppleScript method (no accessibility permissions)", level: .debug, category: "Popup")
      sendPasteKeystrokeViaAppleScript()
    }
  }
  
  /// Send paste keystroke using CGEvent (requires accessibility permissions)
  private static func sendPasteKeystrokeViaCGEvent() {
    let commandFlag: CGEventFlags = .maskCommand
    // Key down for 'v'
    if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true) { // 9 = kVK_ANSI_V
      keyDown.flags = commandFlag
      keyDown.post(tap: .cghidEventTap)
    }
    // Key up for 'v'
    if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) {
      keyUp.flags = commandFlag
      keyUp.post(tap: .cghidEventTap)
    }
  }
  
  /// Send paste keystroke using AppleScript (fallback method)
  private static func sendPasteKeystrokeViaAppleScript() {
    let script = """
    tell application "System Events"
        keystroke "v" using command down
    end tell
    """
    
    var error: NSDictionary?
    if let appleScript = NSAppleScript(source: script) {
      appleScript.executeAndReturnError(&error)
      if let error = error {
        AppLog("PopupController: AppleScript paste failed - \(error)", level: .error, category: "Popup")
        // Show alert to user about accessibility permissions
        showAccessibilityPermissionAlert()
      } else {
        AppLog("PopupController: AppleScript paste executed successfully", level: .debug, category: "Popup")
      }
    }
  }
  
  /// Show alert to help user enable accessibility permissions
  private static func showAccessibilityPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = "ClipAI needs accessibility permissions to paste content into other applications. Please grant permission in System Preferences > Security & Privacy > Privacy > Accessibility."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Open System Preferences")
    alert.addButton(withTitle: "Cancel")
    
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      // Open System Preferences to Accessibility section
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
      }
    }
  }

  /// Show the popup window centered on the main screen
  func showPopup() {
    guard let window = window else { return }
    AppLog("PopupController: showPopup called", level: .info, category: "Popup")

    // let mouseLocation = NSEvent.mouseLocation
    // (Cursor position no longer needed when centering)

    // Calculate window position
    let windowSize = window.frame.size
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
    
    // Calculate center position of the main (visible) screen
    let centerOrigin = NSPoint(
      x: screenFrame.midX - windowSize.width / 2,
      y: screenFrame.midY - windowSize.height / 2
    )
    
    // Set window position and show
    window.setFrameOrigin(centerOrigin)

    // Capture the currently frontmost application so we can restore focus later
    previouslyFrontmostApp = NSWorkspace.shared.frontmostApplication

    // Ensure the popup is visible in the current Space before activation
    window.orderFrontRegardless()

    // Activate the app to allow keyboard input without causing a Space switch
    NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])

    // Make the popup key
    window.makeKeyAndOrderFront(nil)

    // Reset fade out state and select first item when showing the popup
    popupViewModel?.onPopupWillShow()
    // Note: List focus is handled in PopupView.onAppear for keyboard navigation

    // Start monitoring for clicks outside the window after a brief delay
    // This prevents false positives during initial focus setup
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      self?.startMonitoringForOutsideClicks()
    }
  }
  /// Hide the popup window
  func hidePopup() {
    AppLog("PopupController: hidePopup called", level: .info, category: "Popup")
    stopMonitoringForOutsideClicks()
    popupViewModel?.searchText = ""
    window?.orderOut(nil)

    // Restore focus to the previously frontmost application to avoid Space switching
    if let previousApp = previouslyFrontmostApp, previousApp.processIdentifier != NSRunningApplication.current.processIdentifier {
      _ = previousApp.activate(options: [])
    }
    previouslyFrontmostApp = nil
  }
  
  /// Hide the popup window for paste operations without restoring focus
  private func hidePastePopup() {
    AppLog("PopupController: hidePastePopup called", level: .info, category: "Popup")
    stopMonitoringForOutsideClicks()
    popupViewModel?.searchText = ""
    window?.orderOut(nil)
    // Note: We don't restore focus here or clear previouslyFrontmostApp 
    // because the paste handler will manage focus restoration
  }

  /// Toggle popup visibility
  func togglePopup() {
    if window?.isVisible == true {
      hidePopup()
    } else {
      showPopup()
    }
  }

  // MARK: - Outside Click Monitoring

  private var outsideClickMonitor: Any?

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
    
    AppLog("Outside click detected - Mouse: \(mouseLocation), Window: \(windowLocation), Frame: \(windowFrame)", level: .debug, category: "Popup")

    if !windowFrame.contains(windowLocation) {
      AppLog("Click was outside window, hiding popup", level: .info, category: "Popup")
      hidePopup()
    } else {
      AppLog("Click was inside window, keeping popup visible", level: .debug, category: "Popup")
    }
  }

  deinit {
    stopMonitoringForOutsideClicks()
  }
}



// MARK: - NSWindowDelegate

extension PopupController: NSWindowDelegate {
  func windowDidResignKey(_ notification: Notification) {
    // Add a small delay to avoid hiding popup when search field is gaining focus
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self = self, let window = self.window else { return }
      
      // Only hide if the window is still not key and visible
      if !window.isKeyWindow && window.isVisible {
        self.hidePopup()
      }
    }
  }

  func windowWillClose(_ notification: Notification) {
    stopMonitoringForOutsideClicks()
  }
}
