import SwiftUI

/// Main popup view that displays the clipboard history in a scrollable list
struct PopupView: View {
  @ObservedObject var viewModel: PopupViewModel
  @FocusState private var isListFocused: Bool
  @State private var showContent = false
  @State private var shouldFadeOut = false
  // Focus toggle for SearchBarView auto-focus handling
  @State private var searchFieldFocus: Bool = false


  // Callback when fade out animation completes
  var onFadeOutComplete: (() -> Void)?

  init(viewModel: PopupViewModel, onFadeOutComplete: (() -> Void)? = nil) {
    self.viewModel = viewModel
    self.onFadeOutComplete = onFadeOutComplete
  }
  
  // MARK: - Computed Properties
  
  /// Width of the left pane (clipboard list)
  private var leftPaneWidth: CGFloat {
    return 450
  }
  
  /// Total width of the popup window
  private var totalWidth: CGFloat {
    if viewModel.isPreviewVisible {
      return leftPaneWidth + 6 + viewModel.previewPaneWidth // 6 for divider
    } else {
      return leftPaneWidth
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      // Left pane - clipboard list
      VStack(spacing: 0) {
        // Header with enhanced styling
        HeaderView(viewModel: viewModel)

        // Search field
        SearchBarView(
          text: $viewModel.searchText, 
          focus: $searchFieldFocus,
          onArrowKey: {
            viewModel.focusList()
          }
        )
          .padding(.horizontal, 16)
          .padding(.vertical, 8)

        // Content with smooth transitions
        ZStack {
          if viewModel.isEmpty {
            EmptyStateView()
              .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.9)),
                removal: .opacity
              ))
          } else {
            ClipboardListView(
              viewModel: viewModel,
              isListFocused: $isListFocused
            )
              .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity
              ))
          }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isEmpty)
      }
      .frame(width: leftPaneWidth)
      
      // Resizable divider (only show if preview is visible)
      if viewModel.isPreviewVisible {
        ResizableDivider(
          paneWidth: $viewModel.previewPaneWidth,
          isVisible: $viewModel.isPreviewVisible
        )
      }
      
      // Right pane - preview (only show if visible)
      if viewModel.isPreviewVisible {
        PreviewWindowView(
          item: viewModel.selectedItemForPreview,
          providerRegistry: viewModel.previewProviders,
          generalSettingsViewModel: viewModel.generalSettingsViewModel,
          isVisible: $viewModel.isPreviewVisible,
          paneWidth: $viewModel.previewPaneWidth
        )
      }
    }
    .frame(width: totalWidth, height: 600)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(.regularMaterial)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .onAppear {
      AppLog("PopupView onAppear - showContent: \(showContent), shouldFadeOut: \(shouldFadeOut)", level: .debug, category: "Popup")
      
      // Reset states when popup appears
      shouldFadeOut = false
      showContent = false // Reset to ensure clean animation
      
      // Animate in after a brief delay to ensure states are reset
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
          showContent = true
        }
      }

      // Auto-select first item when popup appears
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        viewModel.selectFirstItemIfNeeded()
      }
      
      // Focus the list for keyboard navigation after a brief delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        isListFocused = true
      }
    }
    .onDisappear {
      AppLog("PopupView onDisappear - resetting states", level: .debug, category: "Popup")
      // Reset states when popup disappears
      showContent = false
      shouldFadeOut = false
    }
    .onChange(of: shouldFadeOut) { _, fadeOut in
//      print("🎬 PopupView: shouldFadeOut changed to: \(fadeOut)")
      if fadeOut {
        withAnimation(.easeOut(duration: 0.2)) {
          // Triggers fade out animation
        }
        
        // Call completion handler after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          AppLog("PopupView: Fade out complete, calling hidePopup", level: .debug, category: "Popup")
          onFadeOutComplete?()
        }
      }
    }
    .onReceive(viewModel.$shouldFocusSearchField) { shouldFocus in
      if shouldFocus {
        AppLog("PopupView: Received focus trigger, setting searchFieldFocus = true", level: .debug, category: "Popup")
        searchFieldFocus = true
        isListFocused = false // Remove focus from list
        // Reset the viewModel flag
        viewModel.shouldFocusSearchField = false
      }
    }
    .onReceive(viewModel.$shouldFocusList) { shouldFocus in
      if shouldFocus {
        AppLog("PopupView: Received list focus trigger, setting isListFocused = true", level: .debug, category: "Popup")
        isListFocused = true
        searchFieldFocus = false // Remove focus from search field
        // Reset the viewModel flag
        viewModel.shouldFocusList = false
      }
    }
    .onReceive(viewModel.$shouldTriggerFadeOut) { shouldFade in
      AppLog("PopupView: Received fade out trigger: \(shouldFade)", level: .debug, category: "Popup")
      if shouldFade {
        shouldFadeOut = true
        // Reset the viewModel flag
        viewModel.shouldTriggerFadeOut = false
      }
    }
    // Note: handleItemsChanged is now called automatically via ClipboardStoreDelegate
  }
  
  /// Trigger fade out animation
  func startFadeOut() {
    shouldFadeOut = true
  }



  // MARK: - Keyboard Navigation Methods

  /// Handle keyboard events from the PopupController
  func handleKeyboardEvent(_ event: NSEvent) -> Bool {
    return viewModel.handleKeyboardEvent(event)
  }
}

//
// #if DEBUG
//// MARK: - Preview
// struct PopupView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            // Empty state preview
//            PopupView(clipboardStore: {
//                let store = ClipboardStore(storage: InMemoryClipboardStorage())
//                return store
//            }())
//            .previewDisplayName("Empty State")
//
//            // Populated state preview
//            PopupView(clipboardStore: {
//                let store = ClipboardStore(storage: InMemoryClipboardStorage())
//                store.addSampleData()
//                return store
//            }())
//            .previewDisplayName("With Items")
//        }
//    }
// }
// #endif
