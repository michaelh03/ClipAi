import SwiftUI

/// View displayed when no item is selected for preview
/// 
/// This view provides a friendly empty state with helpful information
/// about the preview functionality when no clipboard item is selected.
struct EmptyPreviewView: View {
    /// Animation state for the icon
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon with subtle animation
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.secondary.opacity(0.6))
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
            
            VStack(spacing: 12) {
                // Main message
                Text("No Preview Available")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                // Description
                Text("Select a clipboard item to see its preview")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Help information
            VStack(spacing: 8) {
                Text("Preview supports:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    previewTypeItem(icon: "doc.text", text: "Plain Text")
                    previewTypeItem(icon: "curlybraces", text: "Code")
                    previewTypeItem(icon: "curlybraces.square", text: "JSON")
                    previewTypeItem(icon: "paintpalette", text: "Colors")
                }
            }
            .padding(.top, 16)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Empty preview state")
        .accessibilityHint("Select a clipboard item from the list to see its preview")
    }
    
    /// Individual preview type item
    private func previewTypeItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 12)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview Support
#Preview("Default State") {
    EmptyPreviewView()
        .frame(width: 300, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Wide Layout") {
    EmptyPreviewView()
        .frame(width: 500, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Narrow Layout") {
    EmptyPreviewView()
        .frame(width: 250, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Dark Mode") {
    EmptyPreviewView()
        .frame(width: 350, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .environment(\.colorScheme, .dark)
}