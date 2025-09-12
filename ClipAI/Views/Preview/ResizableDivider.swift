import SwiftUI

/// Draggable divider component for resizing preview pane width
/// 
/// This component provides a visual and interactive divider that allows users
/// to resize the preview pane by dragging horizontally.
struct ResizableDivider: View {
    /// Current width of the preview pane
    @Binding var paneWidth: CGFloat
    
    /// Whether the preview pane is visible
    @Binding var isVisible: Bool
    
    /// Minimum allowed pane width
    let minWidth: CGFloat
    
    /// Maximum allowed pane width  
    let maxWidth: CGFloat
    
    /// Whether the divider is currently being hovered
    @State private var isHovered = false
    
    /// Whether the divider is currently being dragged
    @State private var isDragging = false
    
    /// Width of the divider itself
    private let dividerWidth: CGFloat = 6
    
    /// Visual width of the divider line
    private let lineWidth: CGFloat = 1
    
    init(
        paneWidth: Binding<CGFloat>,
        isVisible: Binding<Bool>,
        minWidth: CGFloat = 250,
        maxWidth: CGFloat = 600
    ) {
        self._paneWidth = paneWidth
        self._isVisible = isVisible
        self.minWidth = minWidth
        self.maxWidth = maxWidth
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Draggable area
            Rectangle()
                .fill(Color.clear)
                .frame(width: dividerWidth)
                .overlay(
                    // Visual divider line
                    Rectangle()
                        .fill(dividerLineColor)
                        .frame(width: lineWidth)
                )
                .contentShape(Rectangle())
                .cursor(isHovered || isDragging ? .resizeLeftRight : .arrow)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                            }
                            
                            let newWidth = paneWidth - value.translation.width
                            paneWidth = max(minWidth, min(maxWidth, newWidth))
                        }
                        .onEnded { _ in
                            isDragging = false
                            
                            // If dragged very narrow, hide the pane
                            if paneWidth < minWidth * 0.8 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isVisible = false
                                }
                            }
                        }
                )
                // Accessibility
                .accessibilityElement()
                .accessibilityLabel("Preview pane resizer")
                .accessibilityHint("Drag to resize preview pane width")
                .accessibilityAddTraits(.isButton)
        }
    }
    
    /// Color for the divider line based on current state
    private var dividerLineColor: Color {
        if isDragging {
            return Color.accentColor
        } else if isHovered {
            return Color.primary.opacity(0.6)
        } else {
            return Color(NSColor.separatorColor)
        }
    }
}

// MARK: - Cursor Support
private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovered in
            if isHovered {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Preview Support
#Preview("Normal State") {
    @Previewable @State var paneWidth: CGFloat = 300
    @Previewable @State var isVisible = true
    
    return HStack(spacing: 0) {
        Rectangle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: 200)
            .overlay(Text("Left Pane"))
        
        ResizableDivider(
            paneWidth: $paneWidth,
            isVisible: $isVisible,
            minWidth: 200,
            maxWidth: 500
        )
        
        Rectangle()
            .fill(Color.green.opacity(0.3))
            .frame(width: paneWidth)
            .overlay(Text("Preview Pane\nWidth: \(Int(paneWidth))"))
    }
    .frame(height: 300)
}

#Preview("Minimum Width") {
    @Previewable @State var paneWidth: CGFloat = 200
    @Previewable @State var isVisible = true
    
    return HStack(spacing: 0) {
        Rectangle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: 400)
            .overlay(Text("Left Pane"))
        
        ResizableDivider(
            paneWidth: $paneWidth,
            isVisible: $isVisible,
            minWidth: 200,
            maxWidth: 500
        )
        
        Rectangle()
            .fill(Color.green.opacity(0.3))
            .frame(width: paneWidth)
            .overlay(Text("Preview Pane\nWidth: \(Int(paneWidth))"))
    }
    .frame(height: 300)
}

#Preview("Maximum Width") {
    @Previewable @State var paneWidth: CGFloat = 500
    @Previewable @State var isVisible = true
    
    return HStack(spacing: 0) {
        Rectangle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: 100)
            .overlay(Text("Left Pane"))
        
        ResizableDivider(
            paneWidth: $paneWidth,
            isVisible: $isVisible,
            minWidth: 200,
            maxWidth: 500
        )
        
        Rectangle()
            .fill(Color.green.opacity(0.3))
            .frame(width: paneWidth)
            .overlay(Text("Preview Pane\nWidth: \(Int(paneWidth))"))
    }
    .frame(height: 300)
}