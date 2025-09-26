import SwiftUI
import AppKit

/// A modern search field with clean styling that matches the updated clipboard UI
struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search clipboard…"
    /// When set `true` the field requests focus. The value is reset to `false` after focusing.
    @Binding var focus: Bool
    /// Callback when arrow keys are pressed to transfer focus back to list
    var onArrowKey: (() -> Void)?

    @FocusState private var isFieldFocused: Bool
    @State private var isHovered: Bool = false

    var body: some View {
        content
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .onChange(of: focus) { _, shouldFocus in
                if shouldFocus {
                    isFieldFocused = true
                    focus = false // Reset the binding
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isFieldFocused)
            .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }

    private var content: some View {
        HStack(spacing: 12) {
            searchIcon
            textField
            clearButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundView)
    }

    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.secondary)
            .opacity(text.isEmpty ? 0.6 : 0.8)
    }

    private var textField: some View {
        TextField(placeholder, text: $text)
            .focused($isFieldFocused)
            .font(.system(size: 16, weight: .medium))
            .textFieldStyle(PlainTextFieldStyle())
            .submitLabel(.search)
            .onSubmit {
                // Handle search submission if needed
            }
    }

    @ViewBuilder
    private var clearButton: some View {
        if !text.isEmpty {
            Button(action: {
                text = ""
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.primary.opacity(0.04))
            .overlay(borderView)
    }

    private var borderView: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        if isFieldFocused {
            return Color.accentColor.opacity(0.5)
        } else if isHovered {
            return Color.primary.opacity(0.15)
        } else {
            return Color.primary.opacity(0.08)
        }
    }

    private var borderWidth: CGFloat {
        isFieldFocused ? 1.5 : 1
    }

}
