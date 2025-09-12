import SwiftUI

/// Content router view that selects appropriate preview provider based on content type
/// 
/// This view acts as a coordinator, determining which preview provider should handle
/// the current clipboard item and rendering the appropriate preview.
struct PreviewContentView: View {
    /// The clipboard item to preview
    let item: ClipItem?
    
    /// The preview provider registry for finding appropriate providers
    let providerRegistry: PreviewProviderRegistry
    
    /// General settings view model for shared settings like font size
    @ObservedObject var generalSettingsViewModel: GeneralSettingsViewModel
    
    /// Animation namespace for smooth transitions
    @Namespace private var previewTransition
    
    var body: some View {
        Group {
            if let item = item {
                // Find and use appropriate provider
                if let provider = providerRegistry.findProvider(for: item) {
                    provider.createPreview(for: item, generalSettingsViewModel: generalSettingsViewModel)
                        .id("preview-\(item.id)")
                        .matchedGeometryEffect(id: "content", in: previewTransition)
                } else {
                    // Fallback to basic text preview if no provider found
                    TextPreviewView(item: item, generalSettingsViewModel: generalSettingsViewModel)
                        .id("preview-\(item.id)")
                        .matchedGeometryEffect(id: "content", in: previewTransition)
                }
            } else {
                // Show empty state when no item is selected
                EmptyPreviewView()
                    .id("preview-empty")
                    .matchedGeometryEffect(id: "content", in: previewTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: item?.id)
        // Accessibility support
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preview Content")
        .accessibilityHint(item != nil ? "Showing preview content" : "No content to preview")
    }
}

// MARK: - Preview Support
#Preview("With Text Item") {
    let sampleItem = ClipItem(content: "This is sample text content that will be previewed using the default text provider.")
    let registry = PreviewProviderRegistry()
    
    PreviewContentView(
        item: sampleItem,
        providerRegistry: registry,
        generalSettingsViewModel: GeneralSettingsViewModel()
    )
    .frame(width: 300, height: 400)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("With Code Item") {
    let codeItem = ClipItem(content: """
        func calculateSum(a: Int, b: Int) -> Int {
            return a + b
        }
        
        let result = calculateSum(a: 5, b: 3)
        print("Result: \\(result)")
        """)
    let registry = PreviewProviderRegistry()
    
    PreviewContentView(
        item: codeItem,
        providerRegistry: registry,
        generalSettingsViewModel: GeneralSettingsViewModel()
    )
    .frame(width: 400, height: 300)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("With JSON Item") {
    let jsonItem = ClipItem(content: """
        {
            "users": [
                {
                    "id": 1,
                    "name": "John Doe",
                    "email": "john@example.com",
                    "active": true
                },
                {
                    "id": 2,
                    "name": "Jane Smith",
                    "email": "jane@example.com",
                    "active": false
                }
            ],
            "count": 2
        }
        """)
    let registry = PreviewProviderRegistry()
    
    PreviewContentView(
        item: jsonItem,
        providerRegistry: registry,
        generalSettingsViewModel: GeneralSettingsViewModel()
    )
    .frame(width: 350, height: 400)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("No Item Selected") {
    let registry = PreviewProviderRegistry()
    
    PreviewContentView(
        item: nil,
        providerRegistry: registry,
        generalSettingsViewModel: GeneralSettingsViewModel()
    )
    .frame(width: 300, height: 400)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("With Color Item") {
    let colorItem = ClipItem(content: "#FF5733")
    let registry = PreviewProviderRegistry()
    
    PreviewContentView(
        item: colorItem,
        providerRegistry: registry,
        generalSettingsViewModel: GeneralSettingsViewModel()
    )
    .frame(width: 300, height: 200)
    .background(Color(NSColor.windowBackgroundColor))
}