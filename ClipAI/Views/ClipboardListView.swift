import SwiftUI

/// Scrollable list view that displays clipboard items with modern card-based layout
struct ClipboardListView: View {
  @ObservedObject var viewModel: PopupViewModel
  let isListFocused: FocusState<Bool>.Binding

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(viewModel.filteredItems, id: \.id) { item in
            ClipItemRowView(clipItem: item)
              .id(item.id)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(viewModel.selectedItemId == item.id ?
                    Color.accentColor.opacity(0.08) :
                    Color.clear)
                  .animation(viewModel.isInitialSelection ? .none : .easeInOut(duration: 0.2), value: viewModel.selectedItemId)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .strokeBorder(
                    viewModel.selectedItemId == item.id ?
                      Color.accentColor.opacity(0.4) :
                      Color.clear,
                    lineWidth: 1.5
                  )
                  .animation(viewModel.isInitialSelection ? .none : .easeInOut(duration: 0.2), value: viewModel.selectedItemId)
              )
              .padding(.horizontal, 12)
              .scaleEffect(viewModel.selectedItemId == item.id ? 1.02 : 1.0)
              .animation(viewModel.isInitialSelection ? .none : .spring(response: 0.3, dampingFraction: 0.7), value: viewModel.selectedItemId)
              .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                  viewModel.handleItemTapped(item)
                }
              }
              .onHover { isHovering in
                if isHovering {
                  withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.handleItemHovered(item)
                  }
                }
              }
              .contextMenu {
                ContextMenuButton(
                  title: "Copy to Clipboard",
                  systemImage: "doc.on.doc",
                  action: { viewModel.copyItemToClipboard(item) }
                )

                ContextMenuButton(
                  title: "Delete",
                  systemImage: "trash",
                  role: .destructive,
                  action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                      viewModel.removeItem(item)
                    }
                  }
                )
              }
              .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95).combined(with: .move(edge: .top))),
                removal: .opacity.combined(with: .scale(scale: 0.9))
              ))
          }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
      }
      .scrollIndicators(.visible, axes: .vertical)
      .focused(isListFocused)
      .onChange(of: viewModel.selectedItemId) { _, selectedId in
        // Auto-scroll to selected item with smooth animation (disabled for initial selection)
        if let selectedId = selectedId {
          if viewModel.isInitialSelection {
            // No animation for initial selection
            proxy.scrollTo(selectedId, anchor: .center)
          } else {
            withAnimation(.easeInOut(duration: 0.4)) {
              proxy.scrollTo(selectedId, anchor: .center)
            }
          }
        }
      }
      .animation(.easeInOut(duration: 0.3), value: viewModel.filteredItems.count)
    }
  }
}

// MARK: - Context Menu Helper

/// Improved context menu button with consistent styling
struct ContextMenuButton: View {
  let title: String
  let systemImage: String
  var role: ButtonRole? = nil
  let action: () -> Void

  var body: some View {
    Button(role: role) {
      action()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .font(.system(size: 12, weight: .medium))
        Text(title)
          .font(.system(.body, weight: .medium))
      }
    }
  }
}
