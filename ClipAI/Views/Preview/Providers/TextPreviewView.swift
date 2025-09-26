import SwiftUI

/// Basic text preview implementation with enhanced typography
/// 
/// This view provides a clean, readable display of text content with
/// proper formatting, typography, and basic text statistics.
struct TextPreviewView: View {
    /// The clipboard item to preview
    let item: ClipItem
    
    /// General settings view model for font controls
    @ObservedObject var generalSettingsViewModel: GeneralSettingsViewModel
    
    /// Whether to show text statistics
    @State private var showStats = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Controls toolbar
            HStack {
                Spacer()

                // Statistics toggle
                Button(action: { showStats.toggle() }) {
                    Image(systemName: showStats ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Toggle text statistics")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )

            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Text statistics (if enabled)
                    if showStats {
                        textStatistics
                    }

                    // Main text content
                    Text(item.content)
                        .font(.system(size: generalSettingsViewModel.previewFontSize, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.regularMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                        )
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Accessibility
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Text Preview")
        .accessibilityValue("Font size \(Int(generalSettingsViewModel.previewFontSize)) points")
    }
    
    /// Text statistics view
    private var textStatistics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text Statistics")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: 12) {
                statisticItem("Characters", value: item.content.count)
                statisticItem("Words", value: wordCount)
                statisticItem("Lines", value: lineCount)
                statisticItem("Reading Time", value: "\(estimatedReadingTime) min")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    /// Individual statistic item
    private func statisticItem(_ label: String, value: Any) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    /// Word count calculation
    private var wordCount: Int {
        let words = item.content.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    /// Line count calculation
    private var lineCount: Int {
        return item.content.components(separatedBy: .newlines).count
    }
    
    /// Estimated reading time in minutes
    private var estimatedReadingTime: Int {
        // Average reading speed: 200 words per minute
        let wordsPerMinute = 200
        return max(1, wordCount / wordsPerMinute)
    }
}

// MARK: - Preview Support
#Preview("Short Text") {
    let shortItem = ClipItem(content: "This is a short text sample for preview.")
    
    TextPreviewView(item: shortItem, generalSettingsViewModel: GeneralSettingsViewModel())
        .frame(width: 400, height: 300)
}

#Preview("Long Text") {
    let longItem = ClipItem(content: """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
        
        Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
        
        Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.
        
        Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.
        """)
    
    TextPreviewView(item: longItem, generalSettingsViewModel: GeneralSettingsViewModel())
        .frame(width: 400, height: 500)
}

#Preview("Code-like Text") {
    let codeItem = ClipItem(content: """
        function calculateSum(a, b) {
            return a + b;
        }
        
        const result = calculateSum(5, 3);
        console.log('Result:', result);
        
        // This looks like code but isn't detected as such
        for (let i = 0; i < 10; i++) {
            console.log(i);
        }
        """)
    
    TextPreviewView(item: codeItem, generalSettingsViewModel: GeneralSettingsViewModel())
        .frame(width: 400, height: 400)
}
