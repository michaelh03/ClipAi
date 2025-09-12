import SwiftUI

/// Scrollable list view that displays clipboard items with selection and keyboard navigation
struct ClipboardListView: View {
  @ObservedObject var viewModel: PopupViewModel
  let isListFocused: FocusState<Bool>.Binding
  
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 1) {
          ForEach(viewModel.filteredItems, id: \.id) { item in
            ClipItemRowView(clipItem: item)
              .id(item.id)
              .background(
                RoundedRectangle(cornerRadius: 8)
                  .fill(viewModel.selectedItemId == item.id ?
                    Color.accentColor.opacity(0.12) :
                    Color.clear)
                  .animation(viewModel.isInitialSelection ? .none : .easeInOut(duration: 0.15), value: viewModel.selectedItemId)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .strokeBorder(
                    viewModel.selectedItemId == item.id ?
                      Color.accentColor.opacity(0.3) :
                      Color.clear,
                    lineWidth: 1
                  )
                  .animation(viewModel.isInitialSelection ? .none : .easeInOut(duration: 0.15), value: viewModel.selectedItemId)
              )
              .padding(.horizontal, 8)
              .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                  viewModel.handleItemTapped(item)
                }
              }
              .onHover { isHovering in
                if isHovering {
                  withAnimation(.easeInOut(duration: 0.1)) {
                    viewModel.handleItemHovered(item)
                  }
                }
              }
              .contextMenu {
                Button("Copy to Clipboard") {
                  viewModel.copyItemToClipboard(item)
                }

                Button("Delete", role: .destructive) {
                  withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.removeItem(item)
                  }
                }
              }
              .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.9))
              ))

            if item != viewModel.filteredItems.last {
              Divider()
                .padding(.horizontal, 16)
                .opacity(0.6)
            }
          }
        }
        .padding(.vertical, 8)
      }
      .scrollIndicators(.visible, axes: .vertical)
      .focused(isListFocused)
      .onChange(of: viewModel.selectedItemId) { _, selectedId in
        // Auto-scroll to selected item with smooth animation (disabled for initial selection)
        if let selectedId = selectedId {
          if viewModel.isInitialSelection {
            // No animation for initial selection
            proxy.scrollTo(selectedId)
          } else {
            withAnimation(.easeInOut(duration: 0.5)) {
              proxy.scrollTo(selectedId)
            }
          }
        }
      }
      .animation(.easeInOut(duration: 0.3), value: viewModel.filteredItems.count)
    }
  }
}
