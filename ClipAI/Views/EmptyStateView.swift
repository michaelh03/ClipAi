import SwiftUI

/// Empty state view displayed when no clipboard items are available
struct EmptyStateView: View {
  @State private var pulseIcon = false
  
  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "doc.on.clipboard")
        .font(.system(size: 54, weight: .light))
        .foregroundStyle(.secondary)
        .scaleEffect(pulseIcon ? 1.05 : 1.0)
        .animation(
          .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true),
          value: pulseIcon
        )
        .onAppear {
          pulseIcon = true
        }

      VStack(spacing: 8) {
        Text("No text copied yet")
          .font(.system(.title2, weight: .medium))
          .foregroundColor(.primary)

        Text("Copy some text to see it appear here")
          .font(.system(.body, weight: .regular))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      VStack(spacing: 6) {
        HStack(spacing: 4) {
          Text("Press")
          Text("⌃⌘V")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
          Text("to open clipboard")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.secondary)
      }
      .opacity(0.8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }
}