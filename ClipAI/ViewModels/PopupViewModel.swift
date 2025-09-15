import SwiftUI
import Foundation
import AppKit


/// ViewModel for PopupView that handles selection state and keyboard navigation
@MainActor
class PopupViewModel: ObservableObject, ClipboardStoreDelegate {
  
  // MARK: - Keyboard Event Monitoring
  private var keyboardMonitor: Any?

  
  @Published var selectedItemId: String? {
    didSet {
      print("\(selectedItemId ?? "nil")")
      updatePreviewSelection()
    }
  }

  /// Current text in the search bar used for filtering
  @Published var searchText: String = "" {
    didSet {
      print("🔍 Search text changed: '\(searchText)' (oldValue: '\(oldValue)')")
      handleSearchTextChanged()
    }
  }
  
  var itemSelectedHandler: (() -> Void)?
  var closeRequestedHandler: (() -> Void)?
  /// Callback to request pasting into the previously active app
  var pasteRequestedHandler: (() -> Void)?
  
  /// Published property to trigger search field focus
  @Published var shouldFocusSearchField: Bool = false
  
  /// Published property to trigger list focus
  @Published var shouldFocusList: Bool = false
  
  /// Published property to trigger fade out animation
  @Published var shouldTriggerFadeOut: Bool = false
  
  /// Flag to indicate if this is the initial selection (to disable animations)
  @Published var isInitialSelection: Bool = false
  
  // MARK: - Preview Properties
  
  /// The item currently selected for preview (may differ from selection for copy)
  @Published var selectedItemForPreview: ClipItem?
  
  /// Width of the preview pane
  @Published var previewPaneWidth: CGFloat = 400
  
  /// Whether the preview pane is visible
  @Published var isPreviewVisible: Bool = true
  
  /// Registry for preview providers
  @Published var previewProviders: PreviewProviderRegistry = PreviewProviderRegistry()
  
  private let clipboardStore: ClipboardStore
  
  /// General settings view model for shared settings like font size
  let generalSettingsViewModel: GeneralSettingsViewModel
  
  /// All clipboard items - single source of truth
  private var items: [ClipItem] = []
  
  /// Items filtered according to current search text
  @Published var filteredItems: [ClipItem] = []
  
  /// Update filtered items based on current search text
  private func updateFilteredItems() {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if query.isEmpty {
      print("📝 Returning all \(items.count) items (empty query)")
      filteredItems = items
    } else {
      let filtered = items.filter { $0.content.localizedCaseInsensitiveContains(query) }
      print("📝 Filtered \(items.count) items to \(filtered.count) items for query: '\(query)'")
      filteredItems = filtered
    }
  }

  init(clipboardStore: ClipboardStore, generalSettingsViewModel: GeneralSettingsViewModel) {
    self.clipboardStore = clipboardStore
    self.generalSettingsViewModel = generalSettingsViewModel
    
    // Set ourselves as the delegate
    clipboardStore.delegate = self
    
    // Initialize with current items from store
    self.items = clipboardStore.items
    
    // Initialize filtered items
    updateFilteredItems()
    
    // Setup preview providers
    setupDefaultPreviewProviders()
    
    // Start keyboard monitoring
    startKeyboardMonitoring()
  }

  // MARK: - Selection Management

  /// Auto-select first item when popup appears
  func selectFirstItemIfNeeded() {
    if !filteredItems.isEmpty {
      selectedItemId = filteredItems.first?.id
    }
  }

  /// Handle when clipboard items change - ensure selected item still exists
  func handleItemsChanged() {
    // Update filtered items when clipboard changes
    updateFilteredItems()
    
    // If selected item was deleted, select first available item
    if let selectedId = selectedItemId,
       !items.contains(where: { $0.id == selectedId }) {
      selectedItemId = items.first?.id
    }
    
    itemSelectedHandler?()
  }

  /// Update selection to specific item
  func selectItem(with id: String) {
    selectedItemId = id
  }

  /// Clear selection
  func clearSelection() {
    selectedItemId = nil
  }

  // MARK: - Keyboard Navigation

  /// Handle keyboard events from the PopupController
  func handleKeyboardEvent(_ event: NSEvent) -> Bool {
    switch event.keyCode {
    case 53: // Escape - always handle this regardless of items
      closeRequestedHandler?()
      return true
      
    default:
      // For other keys, only handle if we have items
      guard !filteredItems.isEmpty else { return false }
      
      switch event.keyCode {
      case 125: // Down arrow
        selectNextItem()
        return true

      case 126: // Up arrow
        selectPreviousItem()
        return true

      case 36, 76: // Return/Enter
        if let selectedId = selectedItemId,
           let selectedItem = filteredItems.first(where: { $0.id == selectedId }) {
          copyItemToClipboard(selectedItem)
        }
        return true

      default:
        // For printable characters, focus search field to start typing
        if isKeyPrintable(event.keyCode) {
          focusSearchField()
          return false // Let the event pass through to search field
        }
        return false
      }
    }
  }
  
  /// Check if a key code represents a printable character
  private func isKeyPrintable(_ keyCode: UInt16) -> Bool {
    // Letter keys (A-Z)
    if keyCode >= 0 && keyCode <= 11 { return true } // Q-P row
    if keyCode >= 12 && keyCode <= 22 { return true } // A-L row  
    if keyCode >= 23 && keyCode <= 32 { return true } // Z-M row
    
    // Number keys (0-9)
    if keyCode >= 18 && keyCode <= 21 { return true } // 1-4
    if keyCode >= 23 && keyCode <= 26 { return true } // 5-8
    if keyCode == 29 || keyCode == 19 { return true } // 0, 9
    
    // Space bar
    if keyCode == 49 { return true }
    
    // Common punctuation
    if [27, 24, 33, 30, 41, 39, 42, 43, 47, 44].contains(keyCode) { return true }
    
    return false
  }

  /// Select the next item in the list
  private func selectNextItem() {
    guard !filteredItems.isEmpty else { return }

    if let currentId = selectedItemId,
       let currentIndex = filteredItems.firstIndex(where: { $0.id == currentId }) {
      // Only move down if not at the last item
      if currentIndex < filteredItems.count - 1 {
        selectedItemId = filteredItems[currentIndex + 1].id
      }
      // If at last item, do nothing (no wrap-around)
    } else {
      // Select first item if none selected
      selectedItemId = filteredItems.first?.id
    }
  }

  /// Select the previous item in the list
  private func selectPreviousItem() {
    guard !filteredItems.isEmpty else { return }

    if let currentId = selectedItemId,
       let currentIndex = filteredItems.firstIndex(where: { $0.id == currentId }) {
      // Only move up if not at the first item
      if currentIndex > 0 {
        selectedItemId = filteredItems[currentIndex - 1].id
      }
      // If at first item, do nothing (no wrap-around)
    } else {
      // Select first item if none selected
      selectedItemId = filteredItems.first?.id
    }
  }

  // MARK: - Clipboard Operations

  /// Copy item to clipboard with visual feedback
  func copyItemToClipboard(_ item: ClipItem) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(item.content, forType: .string)

    // Brief visual feedback before fade out
    selectedItemId = item.id

    // Trigger fade out animation after brief delay for visual feedback
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      print("🎬 PopupViewModel: Triggering fade out animation")
      self.shouldTriggerFadeOut = true
    }
  }

  /// Handle item selection and copy
  func handleItemTapped(_ item: ClipItem) {
    selectedItemId = item.id
    copyItemToClipboard(item)
  }

  /// Handle item hover for selection
  func handleItemHovered(_ item: ClipItem) {
    selectedItemId = item.id
  }
  
  // MARK: - Clipboard Operations Coordination
  
  /// Remove an item through the store
  func removeItem(_ item: ClipItem) {
    clipboardStore.removeItem(item)
  }
  
  /// Clear all items through the store
  func clearAll() {
    clipboardStore.clearAll()
  }
  
  /// Check if clipboard is empty
  var isEmpty: Bool {
    return items.isEmpty
  }
  
  /// Get count of items
  var count: Int {
    return items.count
  }
  
  // MARK: - Search Management
  
  /// Handle when search text changes - ensure selection stays valid
  private func handleSearchTextChanged() {
    // Update filtered items first
    updateFilteredItems()
    
    // If current selection is not visible in filtered results, select first filtered item
    if let selectedId = selectedItemId,
       !filteredItems.contains(where: { $0.id == selectedId }) {
      selectedItemId = filteredItems.first?.id
    } else if selectedItemId == nil && !filteredItems.isEmpty {
      // If no selection and we have filtered items, select first
      selectedItemId = filteredItems.first?.id
    }
  }
}

// MARK: - ClipboardStoreDelegate
extension PopupViewModel {
  func clipboardStore(_ store: ClipboardStore, didUpdateItems items: [ClipItem]) {
    // Update our local items state
    self.items = items
    
    // Handle selection changes
    handleItemsChanged()
  }
}

extension PopupViewModel {
  

  private func startKeyboardMonitoring() {
    stopKeyboardMonitoring() // Ensure we don't have multiple monitors

    keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
      // Only handle navigation keys when not typing in search field
      // Let other keys (letters, numbers, etc.) pass through to the search field
      let isNavigationKey = [125, 126, 36, 76, 53].contains(event.keyCode) // Down, Up, Return, Enter, Escape
      
      if isNavigationKey, self?.handleKeyboardEvent(event) == true {
        return nil
      }
      return event
    }
  }

  private func stopKeyboardMonitoring() {
    if let monitor = keyboardMonitor {
      NSEvent.removeMonitor(monitor)
      keyboardMonitor = nil
    }
  }
  
  /// Triggers focus on the search field
  func focusSearchField() {
    print("🎯 PopupViewModel: Triggering search field focus")
    shouldFocusSearchField = true
  }
  
  /// Triggers focus on the list
  func focusList() {
    print("🎯 PopupViewModel: Triggering list focus")
    shouldFocusList = true
  }
  
  /// Reset fade out state when popup is shown again
  func resetFadeOutState() {
    print("🔄 PopupViewModel: Resetting fade out state (was: \(shouldTriggerFadeOut))")
    shouldTriggerFadeOut = false
  }
  
  /// Called when the popup is about to be shown - ensures first item is always selected
  func onPopupWillShow() {
    print("🎯 PopupViewModel: Popup will show - selecting first item")
    resetFadeOutState()
    
    // Set flag to disable animations for initial selection
    isInitialSelection = true
    selectFirstItemIfNeeded()
    
    // Reset the flag after a brief delay to allow normal animations for subsequent selections
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.isInitialSelection = false
    }
  }
  
  // MARK: - Preview Management
  
  /// Update the preview selection based on the currently selected item
  private func updatePreviewSelection() {
    if let selectedId = selectedItemId {
      selectedItemForPreview = filteredItems.first { $0.id == selectedId }
    } else {
      selectedItemForPreview = nil
    }
  }
  
  /// Toggle preview pane visibility
  func togglePreviewPane() {
    withAnimation(.easeInOut(duration: 0.3)) {
      isPreviewVisible.toggle()
    }
  }
  
  /// Set preview pane width with validation
  func setPreviewPaneWidth(_ width: CGFloat) {
    let minWidth: CGFloat = 250
    let maxWidth: CGFloat = 600
    previewPaneWidth = max(minWidth, min(maxWidth, width))
  }
  
  /// Register default preview providers
  func setupDefaultPreviewProviders() {
    // Clear existing providers
    previewProviders.clearAll()
    
    // Register color preview provider (high priority)
    previewProviders.register(ColorPreviewProvider())
    
    // Register code preview provider (high priority for syntax highlighting)
    previewProviders.register(CodePreviewProvider())
    
    // Register basic text preview provider (fallback)
    previewProviders.register(BasicTextPreviewProvider())
    
    // Additional providers will be registered in future phases
    // previewProviders.register(JSONPreviewProvider())
  }
  
  /// Get the appropriate preview provider for the given item
  func getPreviewProvider(for item: ClipItem) -> (any ClipItemPreviewProvider)? {
    return previewProviders.findProvider(for: item)
  }
  
  /// Get the best preview provider with confidence scoring
  func getBestPreviewProvider(for item: ClipItem) -> PreviewProviderSelection? {
    return previewProviders.getBestProvider(for: item)
  }
  
  /// Refresh preview provider selection for current item
  func refreshPreviewProvider() {
    // Trigger preview refresh by updating the selected item
    if let current = selectedItemForPreview {
      selectedItemForPreview = current
    }
  }
  
  /// Check if preview is available for the given item
  func hasPreviewAvailable(for item: ClipItem) -> Bool {
    return previewProviders.findProvider(for: item) != nil
  }
  
  /// Get preview statistics for debugging
  func getPreviewStatistics() -> PreviewRegistryStatistics {
    return previewProviders.getStatistics()
  }
}
