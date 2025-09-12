import Foundation

/// Specialized detector for code content with language detection and keyword matching
class CodeDetector {
    
    // MARK: - Language Detection
    
    enum ProgrammingLanguage: String, CaseIterable {
        case swift = "Swift"
        case javascript = "JavaScript"
        case typescript = "TypeScript"
        case python = "Python"
        case java = "Java"
        case csharp = "C#"
        case cpp = "C++"
        case c = "C"
        case php = "PHP"
        case ruby = "Ruby"
        case go = "Go"
        case rust = "Rust"
        case kotlin = "Kotlin"
        case scala = "Scala"
        case objectivec = "Objective-C"
        case shell = "Shell"
        case sql = "SQL"
        case html = "HTML"
        case css = "CSS"
        case xml = "XML"
        case json = "JSON"
        case yaml = "YAML"
        case markdown = "Markdown"
        case unknown = "Unknown"
        
        var fileExtensions: Set<String> {
            switch self {
            case .swift:
                return ["swift"]
            case .javascript:
                return ["js", "mjs", "cjs"]
            case .typescript:
                return ["ts", "tsx"]
            case .python:
                return ["py", "pyw", "pyi"]
            case .java:
                return ["java"]
            case .csharp:
                return ["cs"]
            case .cpp:
                return ["cpp", "cxx", "cc", "hpp", "hxx", "hh"]
            case .c:
                return ["c", "h"]
            case .php:
                return ["php", "phtml"]
            case .ruby:
                return ["rb", "rbw"]
            case .go:
                return ["go"]
            case .rust:
                return ["rs"]
            case .kotlin:
                return ["kt", "kts"]
            case .scala:
                return ["scala", "sc"]
            case .objectivec:
                return ["m", "mm"]
            case .shell:
                return ["sh", "bash", "zsh", "fish"]
            case .sql:
                return ["sql"]
            case .html:
                return ["html", "htm"]
            case .css:
                return ["css", "scss", "sass", "less"]
            case .xml:
                return ["xml", "plist"]
            case .json:
                return ["json"]
            case .yaml:
                return ["yaml", "yml"]
            case .markdown:
                return ["md", "markdown"]
            case .unknown:
                return []
            }
        }
        
        var keywords: Set<String> {
            switch self {
            case .swift:
                return ["func", "class", "struct", "enum", "protocol", "extension", "import", "var", "let", "if", "else", "for", "while", "return", "private", "public", "internal", "fileprivate", "static", "final", "override", "init", "deinit", "subscript", "typealias", "associatedtype", "inout", "mutating", "nonmutating", "@objc", "@available", "weak", "strong", "unowned", "lazy", "computed", "willSet", "didSet"]
                
            case .javascript, .typescript:
                return ["function", "class", "const", "let", "var", "if", "else", "for", "while", "return", "import", "export", "default", "async", "await", "promise", "then", "catch", "try", "throw", "new", "this", "super", "extends", "implements", "interface", "type", "enum", "namespace", "module", "require", "typeof", "instanceof", "null", "undefined", "true", "false"]
                
            case .python:
                return ["def", "class", "import", "from", "if", "elif", "else", "for", "while", "return", "try", "except", "finally", "with", "as", "pass", "break", "continue", "lambda", "yield", "global", "nonlocal", "assert", "del", "raise", "and", "or", "not", "in", "is", "None", "True", "False", "self", "cls", "__init__", "__main__"]
                
            case .java:
                return ["class", "interface", "enum", "extends", "implements", "import", "package", "public", "private", "protected", "static", "final", "abstract", "synchronized", "volatile", "transient", "native", "strictfp", "void", "int", "long", "double", "float", "char", "boolean", "byte", "short", "if", "else", "for", "while", "do", "switch", "case", "default", "return", "break", "continue", "try", "catch", "finally", "throw", "throws", "new", "this", "super", "null", "true", "false"]
                
            case .csharp:
                return ["class", "struct", "interface", "enum", "namespace", "using", "public", "private", "protected", "internal", "static", "readonly", "const", "virtual", "override", "abstract", "sealed", "partial", "void", "int", "long", "double", "float", "char", "bool", "string", "object", "if", "else", "for", "foreach", "while", "do", "switch", "case", "default", "return", "break", "continue", "try", "catch", "finally", "throw", "new", "this", "base", "null", "true", "false", "async", "await", "var"]
                
            case .cpp, .c:
                return ["class", "struct", "union", "enum", "namespace", "using", "typedef", "template", "typename", "public", "private", "protected", "static", "const", "volatile", "inline", "virtual", "override", "final", "void", "int", "long", "double", "float", "char", "bool", "if", "else", "for", "while", "do", "switch", "case", "default", "return", "break", "continue", "try", "catch", "throw", "new", "delete", "this", "nullptr", "true", "false", "#include", "#define", "#ifdef", "#ifndef", "#endif", "#pragma"]
                
            case .php:
                return ["class", "interface", "trait", "extends", "implements", "namespace", "use", "public", "private", "protected", "static", "final", "abstract", "const", "function", "if", "else", "elseif", "for", "foreach", "while", "do", "switch", "case", "default", "return", "break", "continue", "try", "catch", "finally", "throw", "new", "this", "self", "parent", "null", "true", "false", "array", "object", "string", "int", "float", "bool", "callable", "iterable", "void", "mixed"]
                
            case .ruby:
                return ["class", "module", "def", "end", "if", "elsif", "else", "unless", "case", "when", "for", "while", "until", "loop", "break", "next", "return", "yield", "begin", "rescue", "ensure", "raise", "require", "include", "extend", "attr_reader", "attr_writer", "attr_accessor", "private", "protected", "public", "self", "super", "nil", "true", "false", "and", "or", "not"]
                
            case .go:
                return ["package", "import", "func", "var", "const", "type", "struct", "interface", "map", "slice", "chan", "if", "else", "for", "range", "switch", "case", "default", "select", "return", "break", "continue", "fallthrough", "goto", "defer", "go", "make", "new", "append", "len", "cap", "close", "delete", "copy", "panic", "recover", "nil", "true", "false", "iota"]
                
            case .rust:
                return ["fn", "struct", "enum", "impl", "trait", "mod", "use", "pub", "let", "mut", "const", "static", "if", "else", "match", "for", "while", "loop", "break", "continue", "return", "yield", "async", "await", "move", "ref", "self", "Self", "super", "crate", "where", "unsafe", "extern", "true", "false", "None", "Some", "Ok", "Err"]
                
            case .kotlin:
                return ["class", "interface", "object", "enum class", "data class", "sealed class", "abstract class", "fun", "val", "var", "const", "lateinit", "lazy", "by", "delegate", "if", "else", "when", "for", "while", "do", "return", "break", "continue", "try", "catch", "finally", "throw", "import", "package", "public", "private", "protected", "internal", "open", "final", "abstract", "override", "companion", "init", "constructor", "this", "super", "null", "true", "false"]
                
            case .scala:
                return ["class", "object", "trait", "case class", "abstract class", "def", "val", "var", "lazy val", "if", "else", "match", "case", "for", "while", "do", "return", "yield", "try", "catch", "finally", "throw", "import", "package", "extends", "with", "override", "abstract", "final", "sealed", "implicit", "private", "protected", "this", "super", "null", "true", "false", "None", "Some", "Option", "Either", "Left", "Right"]
                
            case .objectivec:
                return ["@interface", "@implementation", "@protocol", "@property", "@synthesize", "@dynamic", "@class", "@selector", "@encode", "@synchronized", "@try", "@catch", "@finally", "@throw", "@autoreleasepool", "if", "else", "for", "while", "do", "switch", "case", "default", "return", "break", "continue", "self", "super", "nil", "YES", "NO", "TRUE", "FALSE", "NSString", "NSArray", "NSDictionary", "NSObject"]
                
            case .shell:
                return ["if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac", "function", "return", "break", "continue", "exit", "export", "local", "readonly", "declare", "set", "unset", "source", "alias", "unalias", "cd", "pwd", "ls", "cp", "mv", "rm", "mkdir", "rmdir", "chmod", "chown", "grep", "awk", "sed", "sort", "uniq", "wc", "head", "tail", "cat", "echo", "printf"]
                
            case .sql:
                return ["SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "TABLE", "DATABASE", "INDEX", "VIEW", "PROCEDURE", "FUNCTION", "TRIGGER", "FROM", "WHERE", "JOIN", "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "FULL JOIN", "GROUP BY", "ORDER BY", "HAVING", "UNION", "DISTINCT", "AS", "AND", "OR", "NOT", "NULL", "IS", "IN", "LIKE", "BETWEEN", "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END", "COUNT", "SUM", "AVG", "MIN", "MAX"]
                
            case .html:
                return ["<!DOCTYPE", "<html", "<head", "<body", "<div", "<span", "<p", "<h1", "<h2", "<h3", "<h4", "<h5", "<h6", "<a", "<img", "<ul", "<ol", "<li", "<table", "<tr", "<td", "<th", "<form", "<input", "<button", "<select", "<option", "<textarea", "<label", "<script", "<style", "<link", "<meta", "<title", "class=", "id=", "src=", "href=", "alt=", "title="]
                
            case .css:
                return ["color", "background", "font", "margin", "padding", "border", "width", "height", "display", "position", "float", "clear", "overflow", "z-index", "opacity", "transform", "transition", "animation", "media", "hover", "active", "focus", "before", "after", "nth-child", "first-child", "last-child", "rgba", "rgb", "hsl", "hsla", "px", "em", "rem", "%", "vh", "vw", "auto", "none", "inherit", "initial", "unset"]
                
            case .xml:
                return ["<?xml", "xmlns", "xsi", "schemaLocation", "version", "encoding", "standalone", "CDATA", "DOCTYPE", "ELEMENT", "ATTLIST", "ENTITY", "NOTATION"]
                
            case .json:
                return ["null", "true", "false"]
                
            case .yaml:
                return ["---", "...", "null", "true", "false", "yes", "no", "on", "off"]
                
            case .markdown:
                return ["#", "##", "###", "####", "#####", "######", "*", "**", "_", "__", "`", "```", "---", "***", "___", "[]", "()", "[]()", "![]()", "|", ":-:", ":--", "--:", ">", "- [ ]", "- [x]"]
                
            case .unknown:
                return []
            }
        }
        
        var commonPatterns: [String] {
            switch self {
            case .swift:
                return ["func\\s+\\w+\\s*\\(", "class\\s+\\w+", "struct\\s+\\w+", "enum\\s+\\w+", "import\\s+\\w+", "let\\s+\\w+\\s*=", "var\\s+\\w+\\s*:", "@\\w+", "\\?\\?", "\\?\\.", "->", "\\$0"]
                
            case .javascript, .typescript:
                return ["function\\s*\\w*\\s*\\(", "const\\s+\\w+\\s*=", "let\\s+\\w+\\s*=", "var\\s+\\w+\\s*=", "class\\s+\\w+", "import\\s+.*from", "export\\s+(default\\s+)?", "=>", "async\\s+", "await\\s+", "\\.then\\(", "\\.catch\\("]
                
            case .python:
                return ["def\\s+\\w+\\s*\\(", "class\\s+\\w+", "import\\s+\\w+", "from\\s+\\w+\\s+import", "if\\s+__name__\\s*==\\s*['\"]__main__['\"]", "self\\.", "\\bself\\b", "def\\s+__\\w+__\\s*\\("]
                
            case .java:
                return ["public\\s+class\\s+\\w+", "private\\s+\\w+", "public\\s+static\\s+void\\s+main", "import\\s+\\w+", "package\\s+\\w+", "@\\w+", "\\bSystem\\.out\\.println\\b", "new\\s+\\w+\\s*\\("]
                
            case .csharp:
                return ["public\\s+class\\s+\\w+", "private\\s+\\w+", "public\\s+static\\s+void\\s+Main", "using\\s+\\w+", "namespace\\s+\\w+", "\\[\\w+\\]", "Console\\.WriteLine", "new\\s+\\w+\\s*\\("]
                
            case .cpp, .c:
                return ["#include\\s*<\\w+>", "#include\\s*\"\\w+\"", "int\\s+main\\s*\\(", "class\\s+\\w+", "struct\\s+\\w+", "template\\s*<", "std::", "cout\\s*<<", "cin\\s*>>", "endl"]
                
            case .php:
                return ["<\\?php", "\\$\\w+", "function\\s+\\w+\\s*\\(", "class\\s+\\w+", "echo\\s+", "print\\s+", "->", "::"]
                
            case .ruby:
                return ["def\\s+\\w+", "class\\s+\\w+", "module\\s+\\w+", "require\\s+", "@\\w+", "@@\\w+", "\\|\\w+\\|", "end\\s*$"]
                
            case .go:
                return ["package\\s+\\w+", "import\\s+\\(", "func\\s+\\w+\\s*\\(", "type\\s+\\w+\\s+struct", "var\\s+\\w+\\s+\\w+", ":=", "fmt\\."]
                
            case .rust:
                return ["fn\\s+\\w+\\s*\\(", "struct\\s+\\w+", "enum\\s+\\w+", "impl\\s+\\w+", "use\\s+\\w+", "let\\s+\\w+\\s*=", "let\\s+mut\\s+\\w+", "&\\w+", "\\|\\w+\\|"]
                
            case .kotlin:
                return ["fun\\s+\\w+\\s*\\(", "class\\s+\\w+", "val\\s+\\w+\\s*=", "var\\s+\\w+\\s*:", "when\\s*\\(", "it\\.", "\\?."]
                
            case .scala:
                return ["def\\s+\\w+\\s*\\(", "class\\s+\\w+", "object\\s+\\w+", "val\\s+\\w+\\s*=", "var\\s+\\w+\\s*:", "case\\s+class", "=>", "_\\s*=>"]
                
            case .objectivec:
                return ["@interface\\s+\\w+", "@implementation\\s+\\w+", "@property\\s*\\(", "\\[\\w+\\s+\\w+", "NSString\\s*\\*", "alloc\\]\\s*init"]
                
            case .shell:
                return ["#!/bin/bash", "#!/bin/sh", "\\$\\{\\w+\\}", "\\$\\w+", "if\\s*\\[", "fi\\s*$", "\\|\\s*\\w+"]
                
            case .sql:
                return ["SELECT\\s+.*FROM", "INSERT\\s+INTO", "UPDATE\\s+\\w+\\s+SET", "DELETE\\s+FROM", "CREATE\\s+TABLE", "ALTER\\s+TABLE", "JOIN\\s+\\w+\\s+ON"]
                
            case .html:
                return ["<!DOCTYPE\\s+html>", "<html.*>", "<head>", "<body>", "<div.*>", "<script.*>", "<style.*>", "</\\w+>"]
                
            case .css:
                return ["\\{[^{}]*\\}", "\\.\\w+\\s*\\{", "#\\w+\\s*\\{", "\\w+:\\s*\\w+;", "@media", "@import"]
                
            case .xml:
                return ["<\\?xml.*\\?>", "<\\w+.*>.*</\\w+>", "xmlns:", "xsi:"]
                
            case .json:
                return ["\\{.*\\}", "\\[.*\\]", "\"\\w+\"\\s*:", ":\\s*(\".*\"|\\d+|true|false|null)"]
                
            case .yaml:
                return ["---", "\\w+:\\s*\\w+", "\\s*-\\s+\\w+", "\\|", ">"]
                
            case .markdown:
                return ["^#{1,6}\\s+", "\\*\\*.*\\*\\*", "\\*.*\\*", "`.*`", "```\\w*", "^\\s*[-*+]\\s+", "\\[.*\\]\\(.*\\)"]
                
            case .unknown:
                return []
            }
        }
    }
    
    // MARK: - Detection Methods
    
    /// Determines if the given text is code
    /// - Parameter text: The text to analyze
    /// - Returns: True if the text appears to be code
    func isCode(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }
        
        // Quick checks for obvious code patterns
        if hasCodeStructure(trimmedText) {
            return true
        }
        
        // Language-specific detection with stricter gating to avoid false positives from generic prose
        let detectedLanguage = detectLanguage(trimmedText)
        if detectedLanguage != .unknown {
            // Re-evaluate with score details to ensure we are not matching only on common words like
            // "and", "or", "for", "is" in natural language sentences.
            let languageScore = calculateLanguageScore(for: trimmedText, language: detectedLanguage)
            let patternMatches = countPatternMatches(in: trimmedText, for: detectedLanguage)
            
            // Require at least one structural pattern match OR a high overall language score
            // before classifying as code. This prevents prose with incidental keyword overlaps
            // from being misclassified as code.
            if patternMatches >= 1 || languageScore >= 0.6 {
                return true
            }
        }
        
        // Check for code-like characteristics
        return hasCodeCharacteristics(trimmedText)
    }
    
    /// Detects the programming language of the given code
    /// - Parameter text: The code text to analyze
    /// - Returns: The detected programming language
    func detectLanguage(_ text: String) -> ProgrammingLanguage {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return .unknown }
        
        var languageScores: [ProgrammingLanguage: Double] = [:]
        
        // Check each language
        for language in ProgrammingLanguage.allCases {
            guard language != .unknown else { continue }
            
            let score = calculateLanguageScore(for: trimmedText, language: language)
            if score > 0 {
                languageScores[language] = score
            }
        }
        
        // Return the language with the highest score
        return languageScores.max(by: { $0.value < $1.value })?.key ?? .unknown
    }
    
    /// Gets confidence score for whether the text is code
    /// - Parameter text: The text to analyze
    /// - Returns: Confidence score from 0.0 to 1.0
    func getCodeConfidence(_ text: String) -> Double {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return 0.0 }
        
        var confidence: Double = 0.0
        
        // Structure-based confidence
        if hasCodeStructure(trimmedText) {
            confidence += 0.4
        }
        
        // Language detection confidence
        let detectedLanguage = detectLanguage(trimmedText)
        if detectedLanguage != .unknown {
            let languageScore = calculateLanguageScore(for: trimmedText, language: detectedLanguage)
            confidence += languageScore * 0.4
        }
        
        // Characteristics-based confidence
        if hasCodeCharacteristics(trimmedText) {
            confidence += 0.2
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Private Helper Methods
    
    private func hasCodeStructure(_ text: String) -> Bool {
        // Check for common code structures
        let codePatterns = [
            "\\{[^{}]*\\}",                    // Braces with content
            "\\([^()]*\\)\\s*\\{",             // Function-like pattern
            ";\\s*$",                          // Lines ending with semicolon
            "//.*$",                           // Single-line comments
            "/\\*.*\\*/",                      // Multi-line comments
            "#.*$",                            // Hash comments
            "=\".*\"",                         // String assignments
            "\\w+\\s*=\\s*\\w+",              // Variable assignments
            "if\\s*\\(",                       // If statements
            "for\\s*\\(",                      // For loops
            "while\\s*\\(",                    // While loops
            "function\\s*\\w*\\s*\\(",         // Function definitions
            "class\\s+\\w+",                   // Class definitions
            "import\\s+\\w+",                  // Import statements
            "\\w+\\.\\w+\\s*\\(",             // Method calls
        ]
        
        let combinedPattern = codePatterns.joined(separator: "|")
        
        do {
            let regex = try NSRegularExpression(pattern: combinedPattern, options: [.anchorsMatchLines, .caseInsensitive])
            let range = NSRange(location: 0, length: text.utf16.count)
            let matches = regex.matches(in: text, options: [], range: range)
            
            // If we find multiple matches, it's likely code
            return matches.count >= 2
        } catch {
            return false
        }
    }
    
    private func hasCodeCharacteristics(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        
        // Check for indentation patterns (common in code)
        let indentedLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && line.count > trimmed.count
        }
        
        // If more than 30% of lines are indented, likely code
        let indentationRatio = Double(indentedLines.count) / Double(lines.count)
        if indentationRatio > 0.3 {
            return true
        }
        
        // Check for high symbol density (common in code)
        let symbolCharacters = CharacterSet(charactersIn: "{}();=<>!&|+-*/%^~")
        let symbolCount = text.unicodeScalars.filter { symbolCharacters.contains($0) }.count
        let symbolDensity = Double(symbolCount) / Double(text.count)
        
        return symbolDensity > 0.05 // More than 5% symbols
    }
    
    private func calculateLanguageScore(for text: String, language: ProgrammingLanguage) -> Double {
        var score: Double = 0.0
        
        // Keyword matching
        let keywordMatches = countKeywordMatches(in: text, for: language)
        let keywordScore = min(Double(keywordMatches) / 10.0, 0.5) // Max 0.5 from keywords
        score += keywordScore
        
        // Pattern matching
        let patternMatches = countPatternMatches(in: text, for: language)
        let patternScore = min(Double(patternMatches) / 5.0, 0.3) // Max 0.3 from patterns
        score += patternScore
        
        // File extension hint (if text starts with a filename)
        if hasFileExtensionHint(in: text, for: language) {
            score += 0.2
        }
        
        return min(score, 1.0)
    }
    
    private func countKeywordMatches(in text: String, for language: ProgrammingLanguage) -> Int {
        let keywords = language.keywords
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        return words.reduce(0) { count, word in
            let cleanWord = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            return count + (keywords.contains(cleanWord.lowercased()) ? 1 : 0)
        }
    }
    
    private func countPatternMatches(in text: String, for language: ProgrammingLanguage) -> Int {
        let patterns = language.commonPatterns
        var matchCount = 0
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: text.utf16.count)
                let matches = regex.matches(in: text, options: [], range: range)
                matchCount += matches.count
            } catch {
                continue
            }
        }
        
        return matchCount
    }
    
    private func hasFileExtensionHint(in text: String, for language: ProgrammingLanguage) -> Bool {
        let firstLine = text.components(separatedBy: .newlines).first ?? ""
        let extensions = language.fileExtensions
        
        return extensions.contains { ext in
            firstLine.lowercased().contains(".\(ext)")
        }
    }
}