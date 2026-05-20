import SwiftUI

struct TagChip: View {
    let name: String
    let colorKey: ColorKey
    var compact: Bool = false

    var body: some View {
        Text(name)
            .font(compact ? .caption2.weight(.medium) : .body.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(colorKey.foreground)
            .padding(.horizontal, compact ? 6 : 11)
            .padding(.vertical, compact ? 2 : 5)
            .background(
                RoundedRectangle(cornerRadius: compact ? 5 : 8, style: .continuous)
                    .fill(colorKey.background)
            )
            .fixedSize(horizontal: true, vertical: false)
    }
}
