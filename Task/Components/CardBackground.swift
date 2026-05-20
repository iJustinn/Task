import SwiftUI

private struct TaskCardBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .light ? Color(.systemBackground) : Color(.secondarySystemBackground))
                    .shadow(
                        color: Color.black.opacity(colorScheme == .light ? 0.07 : 0),
                        radius: 14,
                        x: 0,
                        y: 6
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .light ? 0.04 : 0), lineWidth: 1)
            )
    }
}

extension View {
    func taskCardBackground(cornerRadius: CGFloat = 24) -> some View {
        modifier(TaskCardBackgroundModifier(cornerRadius: cornerRadius))
    }
}
