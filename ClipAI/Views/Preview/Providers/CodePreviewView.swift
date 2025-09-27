import SwiftUI
import HighlightSwift

/// Clean code preview with syntax highlighting
struct CodePreviewView: View {
    /// The clipboard item to preview
    let item: ClipItem

    /// General settings view model for font controls
    @ObservedObject var generalSettingsViewModel: GeneralSettingsViewModel

    /// Truncated content used for rendering the preview
    private var truncatedContent: String {
        let limit = PreviewConfig.maxPreviewCharacters
        if item.content.count <= limit {
            return item.content
        }
        return String(item.content.prefix(limit)) + "…"
    }

    var body: some View {
        codeTextView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Code text view with syntax highlighting
    private var codeTextView: some View {
        ScrollView {
            Group {
                if let colorScheme = colorSchemeForTheme(generalSettingsViewModel.previewTheme) {
                    CodeText(truncatedContent)
                        .colorScheme(colorScheme)
                } else {
                    CodeText(truncatedContent)
                }
            }
            .font(.system(size: generalSettingsViewModel.previewFontSize, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background(.regularMaterial)
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
