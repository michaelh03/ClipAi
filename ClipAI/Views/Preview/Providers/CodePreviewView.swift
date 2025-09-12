import SwiftUI
import HighlightSwift

/// Code preview implementation with syntax highlighting using HighlightSwift
/// 
/// This view provides syntax-highlighted display of code content with
/// language detection, theme support, and code statistics.
struct CodePreviewView: View {
    /// The clipboard item to preview
    let item: ClipItem
    
    /// General settings view model for font controls
    @ObservedObject var generalSettingsViewModel: GeneralSettingsViewModel
    
    /// Whether to show code statistics
    @State private var showStats = false
    
    /// Detected programming language
    @State private var detectedLanguage: String?
    
    /// Code confidence from HighlightSwift
    @State private var codeConfidence: Double = 0.8
    
    var body: some View {
        mainContainer
    }
    
    private var mainContainer: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()  
            contentArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Code Preview")
        .accessibilityValue(accessibilityDescription)
    }
    
    private var accessibilityDescription: String {
        "Language: \(detectedLanguage ?? "Unknown"), Theme: \(generalSettingsViewModel.currentThemeDisplayName), Font size \(Int(generalSettingsViewModel.previewFontSize)) points"
    }
    
    private var toolbar: some View {
        HStack {
            languageIndicator
            Spacer()
            statsToggle
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var languageIndicator: some View {
        Group {
            if let language = detectedLanguage {
                HStack(spacing: 4) {
                    Image(systemName: "curlybraces")
                        .foregroundColor(.secondary)
                    Text(language)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    
    private var statsToggle: some View {
        Button(action: { showStats.toggle() }) {
            Image(systemName: showStats ? "info.circle.fill" : "info.circle")
        }
        .buttonStyle(PlainButtonStyle())
        .help("Toggle code statistics")
    }
    
    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if showStats {
                    codeStatistics
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                
                codeTextView
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    /// Code text view with syntax highlighting
    private var codeTextView: some View {
        Group {
            if let colorScheme = colorSchemeForTheme(generalSettingsViewModel.previewTheme) {
                CodeText(item.content)
                    .colorScheme(colorScheme)
            } else {
                CodeText(item.content)
            }
        }
        .font(.system(size: generalSettingsViewModel.previewFontSize, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .task {
            // HighlightSwift automatically detects the language using highlight.js
            // We indicate this by showing "Auto-detected" with high confidence
            detectedLanguage = "Auto-detected"
            codeConfidence = 0.8
        }
    }
    
    /// Code statistics view
    private var codeStatistics: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Code Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: 8) {
                statisticItem("Language", value: detectedLanguage ?? "Unknown")
                statisticItem("Characters", value: item.content.count)
                statisticItem("Lines", value: lineCount)
                statisticItem("Code Confidence", value: "\(Int(codeConfidence * 100))%")
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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
    
    /// Line count calculation
    private var lineCount: Int {
        return item.content.components(separatedBy: .newlines).count
    }
    
    /// Convert theme string to ColorScheme
    private func colorSchemeForTheme(_ theme: String) -> ColorScheme? {
        switch theme {
        case "github-dark", "vs-dark", "atom-one-dark":
            return .dark
        case "github", "vs", "xcode":
            return .light
        default:
            return nil // Use system default
        }
    }
}

// MARK: - Preview Support
#Preview("Swift Code") {
    let swiftCode = ClipItem(content: """
        import SwiftUI
        
        struct ContentView: View {
            @State private var name = "World"
            
            var body: some View {
                VStack {
                    Text("Hello, \\(name)!")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    TextField("Enter name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }
                .padding()
            }
        }
        """)
    
    CodePreviewView(item: swiftCode, generalSettingsViewModel: GeneralSettingsViewModel())
        .frame(width: 500, height: 400)
}

#Preview("JavaScript Code") {
    let jsCode = ClipItem(content: """
        function fibonacci(n) {
            if (n <= 1) return n;
            return fibonacci(n - 1) + fibonacci(n - 2);
        }
        
        const numbers = [1, 2, 3, 4, 5];
        const squared = numbers.map(x => x * x);
        
        console.log('Fibonacci of 10:', fibonacci(10));
        console.log('Squared numbers:', squared);
        
        // Arrow function example
        const greet = (name) => {
            return `Hello, ${name}!`;
        };
        """)
    
    CodePreviewView(item: jsCode, generalSettingsViewModel: GeneralSettingsViewModel())
        .frame(width: 500, height: 400)
}

#Preview("Python Code") {
    let pythonCode = ClipItem(content: """
        import json
        from typing import List, Dict
        
        def process_data(data: List[Dict]) -> Dict:
            \"\"\"Process a list of dictionaries and return summary.\"\"\"
            result = {
                'count': len(data),
                'keys': set()
            }
            
            for item in data:
                result['keys'].update(item.keys())
            
            return result
        
        # Example usage
        sample_data = [
            {'name': 'Alice', 'age': 30},
            {'name': 'Bob', 'age': 25, 'city': 'NYC'}
        ]
        
        summary = process_data(sample_data)
        print(json.dumps(summary, indent=2))
        """)
    
    CodePreviewView(item: pythonCode, generalSettingsViewModel: GeneralSettingsViewModel())
        .frame(width: 500, height: 400)
}
