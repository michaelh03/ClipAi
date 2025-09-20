import SwiftUI
import AppKit

/// A macOS search field wrapped for SwiftUI that immediately forwards text changes via binding
/// and automatically becomes first responder when the view appears.
struct SearchBarView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search clipboard…"
    /// When set `true` the field requests focus. The value is reset to `false` after focusing.
    @Binding var focus: Bool
    /// Callback when arrow keys are pressed to transfer focus back to list
    var onArrowKey: (() -> Void)?

    // MARK: - NSViewRepresentable
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField(string: text)
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.sendsSearchStringImmediately = true
        field.focusRingType = .none
        field.translatesAutoresizingMaskIntoConstraints = false
        // Reduce unneeded bezel so it blends with popup material
        field.bezelStyle = .roundedBezel
        // Increase font size for better readability
        field.font = NSFont.systemFont(ofSize: 16)
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // Focus management
        if focus, nsView.window != nil, nsView.window?.firstResponder != nsView {
            AppLog("SearchField requesting focus...", level: .debug, category: "Popup")
            DispatchQueue.main.async {
                let didBecome = nsView.becomeFirstResponder()
                AppLog("SearchField became first responder: \(didBecome)", level: .debug, category: "Popup")
                // Reset the toggle so future updates don't steal focus
                focus = false
            }
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, NSSearchFieldDelegate {
        private let parent: SearchBarView
        init(_ parent: SearchBarView) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            AppLog("SearchBar text changed: '\(field.stringValue)'", level: .debug, category: "Popup")
            parent.text = field.stringValue
        }

        /// Handle special key commands (Escape, Arrow keys)
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Intercept Escape
                if !parent.text.isEmpty {
                    parent.text = ""
                    return true // handled – don't propagate
                }
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) ||
                      commandSelector == #selector(NSResponder.moveDown(_:)) {
                // Handle arrow keys - transfer focus back to list
                AppLog("SearchBar: Arrow key pressed, transferring focus to list", level: .debug, category: "Popup")
                parent.onArrowKey?()
                return true // handled – don't propagate
            }
            return false
        }
    }
}
