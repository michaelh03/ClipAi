import SwiftUI

/// Header view for the preview pane showing content type and actions
/// 
/// This view displays information about the selected clipboard item and provides
/// actions for manipulating the preview pane (like closing it).
struct PreviewHeaderView: View {
    /// The clipboard item being previewed
    let item: ClipItem?
    
    /// Whether the preview pane is visible
    @Binding var isVisible: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Content type icon and label with modern styling
            if let item = item {
                HStack(spacing: 8) {
                    Image(systemName: item.contentType.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                        )

                    Text(item.contentType.displayName)
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.1))
                        )

                    Text("No Preview")
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Close button for preview pane
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Close Preview")
        }
        // Remove the old background styling since it's handled by parent
        // Accessibility support
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preview Header")
        .accessibilityHint(item != nil ? "Preview of \(item!.contentType.displayName) content" : "No preview available")
    }
    

}

// MARK: - Preview Support
#Preview("With Text Item") {
    @Previewable @State var isVisible = true
    let sampleItem = ClipItem(content: "This is sample content for preview")
    
    PreviewHeaderView(
        item: sampleItem,
        isVisible: $isVisible
    )
    .frame(width: 300, height: 44)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("With Code Item") {
    @Previewable @State var isVisible = true
    let codeItem = ClipItem(content: """
        func helloWorld() {
            print("Hello, World!")
        }
        """)
    
    PreviewHeaderView(
        item: codeItem,
        isVisible: $isVisible
    )
    .frame(width: 300, height: 44)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("With JSON Item") {
    @Previewable @State var isVisible = true
    let jsonItem = ClipItem(content: """
        {
            "name": "John Doe",
            "age": 30
        }
        """)
    
    PreviewHeaderView(
        item: jsonItem,
        isVisible: $isVisible
    )
    .frame(width: 300, height: 44)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("No Item") {
    @Previewable @State var isVisible = true
    
    PreviewHeaderView(
        item: nil as ClipItem?,
        isVisible: $isVisible
    )
    .frame(width: 300, height: 44)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Narrow Width") {
    @Previewable @State var isVisible = true
    let longNameItem = ClipItem(content: "This is a very long content that might cause truncation in the header")
    
    PreviewHeaderView(
        item: longNameItem,
        isVisible: $isVisible
    )
    .frame(width: 200, height: 44)
    .background(Color(NSColor.windowBackgroundColor))
}