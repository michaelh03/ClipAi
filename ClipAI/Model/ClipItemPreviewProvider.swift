import SwiftUI

/// Base protocol for all preview providers in the ClipAI preview system
/// 
/// This protocol defines the interface that all preview providers must implement
/// to participate in the content preview system. Each provider specializes in
/// rendering a specific type of clipboard content (text, code, JSON, colors, etc.)
protocol ClipItemPreviewProvider {
    /// The content type this provider supports
    var supportedContentType: ClipContentType { get }
    
    /// Priority for provider selection when multiple providers support the same content type
    /// Higher values indicate higher priority. Range: 0-100
    var priority: Int { get }
    
    /// Determines if this provider can preview the given clip item
    /// - Parameter item: The clipboard item to evaluate
    /// - Returns: True if this provider can handle the item's content
    func canPreview(_ item: ClipItem) -> Bool
    
    /// Creates a SwiftUI view to preview the given clip item
    /// - Parameters:
    ///   - item: The clipboard item to preview
    ///   - generalSettingsViewModel: The general settings view model for shared settings like font size
    /// - Returns: A SwiftUI view that renders the preview
    func createPreview(for item: ClipItem, generalSettingsViewModel: GeneralSettingsViewModel) -> AnyView
}

// MARK: - Default Implementation
extension ClipItemPreviewProvider {
    /// Default implementation checks if the item's content type matches the supported type
    func canPreview(_ item: ClipItem) -> Bool {
        return item.contentType == supportedContentType
    }
}

// MARK: - Preview Provider Registry

/// Result of provider selection with confidence scoring
struct PreviewProviderSelection {
    let provider: any ClipItemPreviewProvider
    let confidence: Double
    let reason: String
    
    init(provider: any ClipItemPreviewProvider, confidence: Double, reason: String) {
        self.provider = provider
        self.confidence = confidence
        self.reason = reason
    }
}

/// Statistics about the provider registry
struct PreviewRegistryStatistics {
    let totalProviders: Int
    let providersByType: [ClipContentType: Int]
    let avgPriority: Double
    let lastSelectionTime: Date?
    let selectionCount: Int
    
    init(totalProviders: Int, providersByType: [ClipContentType: Int], avgPriority: Double, lastSelectionTime: Date? = nil, selectionCount: Int = 0) {
        self.totalProviders = totalProviders
        self.providersByType = providersByType
        self.avgPriority = avgPriority
        self.lastSelectionTime = lastSelectionTime
        self.selectionCount = selectionCount
    }
}

/// Registry for managing and selecting preview providers
class PreviewProviderRegistry: ObservableObject {
    @Published private var providers: [any ClipItemPreviewProvider] = []
    
    // MARK: - Selection Tracking
    private var selectionHistory: [(provider: String, timestamp: Date)] = []
    private var lastSelectionTime: Date?
    private var selectionCount: Int = 0
    
    /// Register a new preview provider
    /// - Parameter provider: The provider to register
    func register(_ provider: any ClipItemPreviewProvider) {
        // Remove any existing provider of the same type with lower priority
        providers.removeAll { existingProvider in
            existingProvider.supportedContentType == provider.supportedContentType &&
            existingProvider.priority < provider.priority
        }
        
        providers.append(provider)
        
        // Sort by priority (descending) to ensure higher priority providers are checked first
        providers.sort { (lhs: any ClipItemPreviewProvider, rhs: any ClipItemPreviewProvider) in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            // If same priority, prefer by content type specificity
            return lhs.supportedContentType.detectionPriority > rhs.supportedContentType.detectionPriority
        }
        
        objectWillChange.send()
    }
    
    /// Find the best provider for the given clip item
    /// - Parameter item: The clipboard item to find a provider for
    /// - Returns: The best matching provider, or nil if none can handle the item
    func findProvider(for item: ClipItem) -> (any ClipItemPreviewProvider)? {
        let eligibleProviders = providers.filter { $0.canPreview(item) }
        
        guard !eligibleProviders.isEmpty else {
            return nil
        }
        
        // Return the highest priority provider that can handle the item
        let selectedProvider = eligibleProviders.first!
        
        // Track selection
        trackSelection(provider: selectedProvider)
        
        return selectedProvider
    }
    
    /// Get the best provider with confidence scoring
    /// - Parameter item: The clipboard item to find a provider for
    /// - Returns: Provider selection with confidence information
    func getBestProvider(for item: ClipItem) -> PreviewProviderSelection? {
        let eligibleProviders = providers.filter { $0.canPreview(item) }
        
        guard !eligibleProviders.isEmpty else {
            return nil
        }
        
        let bestProvider = eligibleProviders.first!
        
        // Calculate confidence based on provider priority and content type match
        let contentTypeConfidence = item.contentType == bestProvider.supportedContentType ? 1.0 : 0.8
        let priorityConfidence = Double(bestProvider.priority) / 100.0
        let overallConfidence = min((contentTypeConfidence + priorityConfidence) / 2.0, 1.0)
        
        let reason = buildSelectionReason(provider: bestProvider, item: item, eligibleCount: eligibleProviders.count)
        
        // Track selection
        trackSelection(provider: bestProvider)
        
        return PreviewProviderSelection(
            provider: bestProvider,
            confidence: overallConfidence,
            reason: reason
        )
    }
    
    /// Get all providers that can handle the given item, sorted by priority
    /// - Parameter item: The clipboard item to evaluate
    /// - Returns: Array of eligible providers sorted by priority
    func getAllEligibleProviders(for item: ClipItem) -> [any ClipItemPreviewProvider] {
        return providers.filter { $0.canPreview(item) }
    }
    
    /// Get providers by content type
    /// - Parameter contentType: The content type to filter by
    /// - Returns: Array of providers supporting the given content type
    func getProviders(for contentType: ClipContentType) -> [any ClipItemPreviewProvider] {
        return providers.filter { $0.supportedContentType == contentType }
    }
    
    /// Get all registered providers
    var allProviders: [any ClipItemPreviewProvider] {
        return providers
    }
    
    /// Remove all registered providers (useful for testing)
    func clearAll() {
        providers.removeAll()
        selectionHistory.removeAll()
        lastSelectionTime = nil
        selectionCount = 0
        objectWillChange.send()
    }
    
    /// Remove a specific provider
    /// - Parameter provider: The provider to remove
    func unregister(_ provider: any ClipItemPreviewProvider) {
        providers.removeAll { registeredProvider in
            registeredProvider.supportedContentType == provider.supportedContentType &&
            registeredProvider.priority == provider.priority
        }
        objectWillChange.send()
    }
    
    /// Get registry statistics
    func getStatistics() -> PreviewRegistryStatistics {
        let providersByType = Dictionary(grouping: providers, by: { $0.supportedContentType })
            .mapValues { $0.count }
        
        let avgPriority = providers.isEmpty ? 0.0 : Double(providers.map { $0.priority }.reduce(0, +)) / Double(providers.count)
        
        return PreviewRegistryStatistics(
            totalProviders: providers.count,
            providersByType: providersByType,
            avgPriority: avgPriority,
            lastSelectionTime: lastSelectionTime,
            selectionCount: selectionCount
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func trackSelection(provider: any ClipItemPreviewProvider) {
        let providerName = String(describing: type(of: provider))
        selectionHistory.append((provider: providerName, timestamp: Date()))
        lastSelectionTime = Date()
        selectionCount += 1
        
        // Keep only last 100 selections
        if selectionHistory.count > 100 {
            selectionHistory.removeFirst()
        }
    }
    
    private func buildSelectionReason(provider: any ClipItemPreviewProvider, item: ClipItem, eligibleCount: Int) -> String {
        let providerName = String(describing: type(of: provider))
        let contentType = provider.supportedContentType.rawValue
        let priority = provider.priority
        
        if eligibleCount == 1 {
            return "Only \(providerName) can handle \(contentType) content"
        } else {
            return "\(providerName) selected (priority: \(priority)) from \(eligibleCount) eligible providers for \(contentType) content"
        }
    }
}

// MARK: - Color Preview Provider

/// Color preview provider that handles color content types
struct ColorPreviewProvider: ClipItemPreviewProvider {
    let supportedContentType: ClipContentType = .color
    let priority: Int = 80 // High priority for color content
    
    func canPreview(_ item: ClipItem) -> Bool {
        // Check if content type is color (detected from preview at init)
        // No need to re-check patterns on full content for performance
        return item.contentType == .color
    }
    
    func createPreview(for item: ClipItem, generalSettingsViewModel: GeneralSettingsViewModel) -> AnyView {
        return AnyView(ColorPreviewView(item: item))
    }
}

// MARK: - Code Preview Provider

/// Code preview provider that handles code content types with syntax highlighting
struct CodePreviewProvider: ClipItemPreviewProvider {
    let supportedContentType: ClipContentType = .code
    let priority: Int = 75 // High priority for code content

    func canPreview(_ item: ClipItem) -> Bool {
        // Check if content type is code (detected from preview at init)
        // No need to re-run detector on full content for performance
        return item.contentType == .code
    }
    
    func createPreview(for item: ClipItem, generalSettingsViewModel: GeneralSettingsViewModel) -> AnyView {
        return AnyView(CodePreviewView(item: item, generalSettingsViewModel: generalSettingsViewModel))
    }
}

// MARK: - Basic Text Preview Provider

/// Basic text preview provider that serves as fallback for all text content
struct BasicTextPreviewProvider: ClipItemPreviewProvider {
    let supportedContentType: ClipContentType = .plainText
    let priority: Int = 10 // Low priority - serves as fallback
    
    func canPreview(_ item: ClipItem) -> Bool {
        // Can preview any text content as fallback
        // Use preview instead of full content for performance
        return !item.preview.isEmpty
    }
    
    func createPreview(for item: ClipItem, generalSettingsViewModel: GeneralSettingsViewModel) -> AnyView {
        let truncatedContent: String = {
            let content = item.content
            let limit = PreviewConfig.maxPreviewCharacters
            if content.count <= limit { return content }
            return String(content.prefix(limit)) + "…"
        }()

        return AnyView(
            ScrollView {
                Text(truncatedContent)
                    .font(.system(size: generalSettingsViewModel.previewFontSize))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}
