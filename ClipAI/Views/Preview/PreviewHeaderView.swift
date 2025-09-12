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
        HStack(spacing: 8) {
            // Content type icon and label
            if let item = item {
                Label {
                    Text(item.contentType.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                } icon: {
                    Image(systemName: item.contentType.iconName)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            } else {
                Label("No Preview", systemImage: "doc.questionmark")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
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