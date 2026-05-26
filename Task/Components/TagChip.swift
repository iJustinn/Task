import SwiftUI

struct TagChip: View {
    let name: String
    let colorKey: ColorKey
    var compact: Bool = false

    var body: some View {
        Text(name)
            .font(compact ? .caption2.weight(.medium) : .subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(colorKey.foreground)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 2 : 3)
            .background(
                RoundedRectangle(cornerRadius: compact ? 5 : 6, style: .continuous)
                    .fill(colorKey.background)
            )
            .fixedSize(horizontal: true, vertical: false)
    }
}

enum SwipeToEditRowMetrics {
    static let actionWidth: CGFloat = 76
    static let triggerDistance: CGFloat = 56

    static func visibleOffset(for translation: CGSize) -> CGFloat {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        guard translation.width < 0, horizontalDistance > verticalDistance * 1.5 else { return 0 }
        return max(-actionWidth, translation.width)
    }

    static func shouldOpenEdit(for translation: CGSize) -> Bool {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        return translation.width < -triggerDistance && horizontalDistance > verticalDistance * 1.5
    }
}

struct SwipeToEditRow<Content: View>: View {
    var isEnabled: Bool = true
    let onEdit: () -> Void
    @ViewBuilder let content: () -> Content

    @GestureState private var dragTranslation: CGSize = .zero

    private var rowOffset: CGFloat {
        guard isEnabled else { return 0 }
        return SwipeToEditRowMetrics.visibleOffset(for: dragTranslation)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            editAction
            content()
                .background(Color(.systemBackground))
                .offset(x: rowOffset)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .updating($dragTranslation) { value, state, _ in
                    guard isEnabled else { return }
                    state = value.translation
                }
                .onEnded { value in
                    guard isEnabled, SwipeToEditRowMetrics.shouldOpenEdit(for: value.translation) else { return }
                    onEdit()
                }
        )
    }

    private var editAction: some View {
        Button(action: onEdit) {
            Label("Edit", systemImage: "pencil")
                .font(.subheadline.weight(.semibold))
                .labelStyle(.iconOnly)
                .foregroundStyle(.white)
                .frame(width: SwipeToEditRowMetrics.actionWidth)
                .frame(maxHeight: .infinity)
                .background(Color.accentColor)
        }
        .buttonStyle(.plain)
        .opacity(rowOffset < 0 ? 1 : 0)
        .accessibilityLabel("Edit")
    }
}
