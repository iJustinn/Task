import SwiftUI

struct GroupHeaderPill: View {
    let name: String
    let count: Int
    let colorKey: ColorKey
    var onMenuTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(colorKey.dot)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colorKey.foreground)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(colorKey.background)
            )

            Text("\(count)")
                .font(.subheadline.weight(.regular))
                .foregroundStyle(colorKey.foreground.opacity(0.7))

            Spacer(minLength: 0)

            if let onMenuTap {
                Button(action: onMenuTap) {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colorKey.foreground.opacity(0.75))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}
