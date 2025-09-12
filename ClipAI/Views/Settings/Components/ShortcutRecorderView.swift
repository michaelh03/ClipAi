import SwiftUI
import AppKit
import Carbon

/// A SwiftUI control that records a keyboard shortcut using an underlying NSView to capture key events.
///
/// Emits a `ShortcutSpec` when a combination is captured, or `nil` when cleared.
struct ShortcutRecorderView: View {
    // MARK: - Inputs
    let initialDisplay: String
    let onChange: (ShortcutSpec?) -> Void

    // MARK: - Local State
    @State private var isRecording: Bool = false
    @State private var displayText: String

    init(initialDisplay: String, onChange: @escaping (ShortcutSpec?) -> Void) {
        self.initialDisplay = initialDisplay
        self.onChange = onChange
        _displayText = State(initialValue: initialDisplay)
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                .overlay(
                    Text(isRecording ? "Type new shortcut…" : displayText)
                        .font(.system(.body, design: .monospaced))
                )
                .frame(width: 200, height: 32)

            Button(isRecording ? "Stop" : "Record") {
                withAnimation { isRecording.toggle() }
            }
            .buttonStyle(.bordered)

            Button("Clear") {
                displayText = ""
                onChange(nil)
            }
            .buttonStyle(.bordered)
            .disabled(displayText.isEmpty)

            // Invisible capture view that becomes first responder while recording
            ShortcutCaptureRepresentable(isRecording: $isRecording) { spec in
                self.displayText = spec.display
                self.onChange(spec)
            }
            .frame(width: 0, height: 0)
            .clipped()
        }
    }
}

// MARK: - NSViewRepresentable bridge
private struct ShortcutCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCaptured: (ShortcutSpec) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(onCaptured: onCaptured) }

    func makeNSView(context: Context) -> RecorderNSView {
        let v = RecorderNSView()
        v.coordinator = context.coordinator
        return v
    }

        func updateNSView(_ nsView: RecorderNSView, context: Context) {
            nsView.coordinator = context.coordinator
            context.coordinator.setRecording = { value in
                DispatchQueue.main.async {
                    self.isRecording = value
                }
            }
        if isRecording {
            DispatchQueue.main.async {
                nsView.startRecording()
            }
        } else {
            nsView.stopRecording()
        }
    }

    // MARK: - Coordinator
        final class Coordinator {
            let onCaptured: (ShortcutSpec) -> Void
            var setRecording: ((Bool) -> Void)?
            init(onCaptured: @escaping (ShortcutSpec) -> Void) { self.onCaptured = onCaptured }
    }

    // MARK: - NSView that captures key events
    final class RecorderNSView: NSView {
        weak var coordinator: Coordinator?
        private var isActive: Bool = false

        override var acceptsFirstResponder: Bool { true }
        override func becomeFirstResponder() -> Bool { true }
        override func resignFirstResponder() -> Bool { true }

        func startRecording() {
            guard !isActive else { return }
            isActive = true
            self.window?.makeFirstResponder(self)
        }

        func stopRecording() {
            guard isActive else { return }
            isActive = false
            if self.window?.firstResponder === self {
                self.window?.makeFirstResponder(nil)
            }
        }

        override func keyDown(with event: NSEvent) {
            guard isActive else { return }

            // Allow ESC to cancel recording without emitting a value
            if event.keyCode == UInt16(kVK_Escape) {
                coordinator?.setRecording?(false)
                stopRecording()
                return
            }

            // Build ShortcutSpec from the event
            let keyCode = Int(event.keyCode)
            let modifiers = Self.carbonModifiers(from: event.modifierFlags)
            let keyString = Self.keyDisplay(from: event)

            let display = Self.displayString(modifierFlags: event.modifierFlags, key: keyString)
            let spec = ShortcutSpec(keyCode: keyCode, modifiers: modifiers, display: display)

            coordinator?.onCaptured(spec)
            coordinator?.setRecording?(false)
            stopRecording()
        }

        // Intercept Command-based shortcuts that AppKit routes via key equivalents
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard isActive else { return false }
            if event.type == .keyDown {
                keyDown(with: event)
                return true
            }
            return false
        }

        // MARK: - Helpers
        private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
            var result: Int = 0
            if flags.contains(.control) { result |= Int(controlKey) }
            if flags.contains(.command) { result |= Int(cmdKey) }
            if flags.contains(.option) { result |= Int(optionKey) }
            if flags.contains(.shift) { result |= Int(shiftKey) }
            return result
        }

        private static func keyDisplay(from event: NSEvent) -> String {
            // Prefer a visible character, fall back to key code
            if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                return chars.uppercased()
            }
            return "KeyCode \(event.keyCode)"
        }

        private static func displayString(modifierFlags: NSEvent.ModifierFlags, key: String) -> String {
            var parts: [String] = []
            if modifierFlags.contains(.control) { parts.append("⌃") }
            if modifierFlags.contains(.command) { parts.append("⌘") }
            if modifierFlags.contains(.option) { parts.append("⌥") }
            if modifierFlags.contains(.shift) { parts.append("⇧") }
            parts.append(key)
            return parts.joined()
        }
    }
}

