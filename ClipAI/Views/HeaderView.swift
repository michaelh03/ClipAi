import SwiftUI

/// Header view for the popup that displays title, instructions, and item count
struct HeaderView: View {
  let viewModel: PopupViewModel
  
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("Clipboard History")
          .font(.system(.title, weight: .semibold))
          .foregroundColor(.primary)

        if !viewModel.isEmpty {
          Text("Press ↑↓ to navigate, Enter to copy")
            .font(.system(.caption, weight: .medium))
            .foregroundColor(.secondary)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }

      Spacer()

      HStack(spacing: 8) {
        if !viewModel.isEmpty {
          Text("\(viewModel.count)")
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.accentColor)
            .transition(.scale.combined(with: .opacity))
        }
       
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .background(
      Rectangle()
        .fill(.ultraThinMaterial)
        .overlay(
          Rectangle()
            .frame(height: 0.5)
            .foregroundColor(.primary.opacity(0.1)),
          alignment: .bottom
        )
    )
    .animation(.easeInOut(duration: 0.25), value: viewModel.isEmpty)
  }
}