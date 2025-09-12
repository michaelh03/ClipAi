import SwiftUI

/// Main preview container view that displays preview content and header
/// 
/// This view serves as the root container for the preview pane, managing
/// the layout and coordination between the header and content areas.
struct PreviewWindowView: View {
    /// The clipboard item to preview
    let item: ClipItem?
    
    /// The preview provider registry for finding appropriate providers
    let providerRegistry: PreviewProviderRegistry
    
    /// General settings view model for shared settings like font size
    @ObservedObject var generalSettingsViewModel: GeneralSettingsViewModel
    
    /// Whether the preview pane is currently visible
    @Binding var isVisible: Bool
    
    /// Width of the preview pane
    @Binding var paneWidth: CGFloat
    
    /// Minimum width for the preview pane
    private let minWidth: CGFloat = 250
    
    /// Maximum width for the preview pane
    private let maxWidth: CGFloat = 800
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section
            PreviewHeaderView(
                item: item,
                isVisible: $isVisible
            )
            .frame(height: 44)
            
            // Divider between header and content
            Divider()
            
            // Content section
            PreviewContentView(
                item: item,
                providerRegistry: providerRegistry,
                generalSettingsViewModel: generalSettingsViewModel
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: paneWidth)
        .frame(minWidth: minWidth, maxWidth: maxWidth)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            // Left border
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(width: 1),
            alignment: .leading
        )
        // Accessibility support
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preview Pane")
        .accessibilityHint(item != nil ? "Showing preview of clipboard item" : "No item selected for preview")
    }
}

// MARK: - Preview Support
#Preview("With Text Item") {
    @Previewable @State var isVisible = true
    @Previewable @State var paneWidth: CGFloat = 300
    
    let sampleItem = ClipItem(content: "This is a sample text that we're previewing in the preview pane.")
    let registry = PreviewProviderRegistry()
    
    PreviewWindowView(
        item: sampleItem,
        providerRegistry: registry,
        generalSettingsViewModel: GeneralSettingsViewModel(),
        isVisible: $isVisible,
        paneWidth: $paneWidth
    )
    .frame(height: 400)
}

#Preview("No Item Selected") {
    @Previewable @State var isVisible = true
    @Previewable @State var paneWidth: CGFloat = 300
    
    let registry = PreviewProviderRegistry()
    
    PreviewWindowView(
        item: nil,
        providerRegistry: registry,
        generalSettingsViewModel: GeneralSettingsViewModel(),
        isVisible: $isVisible,
        paneWidth: $paneWidth
    )
    .frame(height: 400)
}

#Preview("Narrow Width") {
    @Previewable @State var isVisible = true
    @Previewable @State var paneWidth: CGFloat = 250
    
    let sampleItem = ClipItem(content: "Short text")
    let registry = PreviewProviderRegistry()
    
    PreviewWindowView(
        item: sampleItem,
        providerRegistry: registry,
        generalSettingsViewModel: GeneralSettingsViewModel(),
        isVisible: $isVisible,
        paneWidth: $paneWidth
    )
    .frame(height: 400)
}